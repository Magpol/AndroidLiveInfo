#!/bin/bash

TMP_PROP=$(mktemp)
TMP_INFO=$(mktemp)
adb shell getprop > ${TMP_PROP}

NOW=$(date +"%Y-%m-%d_%H-%M-%S")
PRODUCT=$(grep product.model ${TMP_PROP}| cut -d' ' -f 2 | sed 's/["\n\r]//g' | sed 's/^.\(.*\).$/\1/')
SPATH=$NOW$PRODUCT

ENCRYPTION=$(grep crypto.state ${TMP_PROP}| cut -d' ' -f 2 | sed 's/["\n\r]//g' | sed 's/^.\(.*\).$/\1/' )
ENCRYPTION_TYPE="none"
if [[ ! ${ENCRYPTION} =~ "unecrypted" ]]; then
	ENCRYPTION_TYPE=$(grep crypto.type ${TMP_PROP}| cut -d' ' -f 2 | sed 's/["\n\r]//g' | sed 's/^.\(.*\).$/\1/' )
fi
ANDROID_ID=$(adb shell settings get secure android_id)
ANDROID_VERSION=$(grep version.release ${TMP_PROP}| cut -d' ' -f 2 | sed 's/["\n\r]//g' | sed 's/^.\(.*\).$/\1/' )
IMEI=$(adb shell dumpsys iphonesubinfo | grep 'Device ID' | grep -o '[0-9]+')
if [[ -z ${IMEI} ]]; then
	IMEI=$(adb shell service call iphonesubinfo 1 | awk -F "'" '{print $2}' | sed '1 d' | tr -d '.' | awk '{print}' ORS=)
fi
FINGERPRINT=$(grep fingerprint ${TMP_PROP}| cut -d' ' -f 2 | sed 's/["\n\r]//g' | sed 's/^.\(.*\).$/\1/')

BLUETOOTH_MAC=$(adb shell settings get secure bluetooth_address)
BLUETOOTH_NAME=$(adb shell settings get secure bluetooth_name)

if [[ $(adb shell id) =~ "root" ]] || [[ $(adb shell su -c id) =~ "root" ]];then 
	ROOT="Device is ROOTED!"
else
	ROOT="Cant find ROOT - Device still can be rooted - Verify it!"
fi

echo "[*]" | tee ${TMP_INFO}
echo "[*] Dumping info for device ${PRODUCT} with android_id: ${ANDROID_ID}" | tee -a ${TMP_INFO}
echo "[*] Running Android version: ${ANDROID_VERSION}" | tee -a ${TMP_INFO}
echo "[*] IMEI: ${IMEI}" | tee -a ${TMP_INFO}
echo "[*] Android fingerprint: ${FINGERPRINT}" | tee -a ${TMP_INFO}
echo "[*] Bluetooth_address: ${BLUETOOTH_MAC}" | tee -a ${TMP_INFO}
echo "[*] Bluetooth_name: ${BLUETOOTH_NAME}" | tee -a ${TMP_INFO}
echo "[*] ${ROOT}" | tee -a ${TMP_INFO}
echo "[*]" | tee -a ${TMP_INFO}
read -p "[*] Do you want to dump extended info to ${SPATH}? (Y/n) : " -n 1 -r
echo
if [[ $REPLY =~ ^[Nn]$ ]]; then
	rm "${TMP_PROP}"
	rm "${TMP_INFO}"
    exit 0
fi

mkdir -p ${SPATH}
cat ${TMP_INFO} > ${SPATH}/_info.txt
cat ${TMP_PROP} > ${SPATH}/_props_all.txt
rm "${TMP_PROP}"
rm "${TMP_INFO}"

echo "[*] Executing stage one - Settings/Dumpsys/NIX"

# Settings and packages
adb shell pm list packages -f -u > ${SPATH}/installed_packages.txt
adb shell settings list system > ${SPATH}/settings_system.txt
adb shell settings list secure > ${SPATH}/settings_secure.txt
adb shell settings list global > ${SPATH}/settings_global.txt

# NIX commands
adb shell id >> ${SPATH}/_info.txt
adb shell cat /proc/version >> ${SPATH}/_info.txt
adb shell date >> ${SPATH}/_info.txt
adb shell uptime >> ${SPATH}/_info.txt
adb shell printenv >> ${SPATH}/_info.txt

adb shell cat /proc/partitions >${SPATH}/mounts.txt
adb shell df >>${SPATH}/mounts.txt
adb shell df -ah >>${SPATH}/mounts.txt
adb shell mount >>${SPATH}/mounts.txt

adb shell ip address show wlan0 > ${SPATH}/netcfg.txt
adb shell dumpsys netstats >> ${SPATH}/netcfg.txt
adb shell ifconfig -a >> ${SPATH}/netcfg.txt
adb shell netstat -an >> ${SPATH}/netcfg.txt
#adb shell netcfg >> ${SPATH}/netcfg.txt

# Will be mostly empty on newer android versions...
adb shell lsof > ${SPATH}/lsof.txt
adb shell ps -ef > ${SPATH}/processes.txt
adb shell top -n 1 >> ${SPATH}/processes.txt
adb shell cat /proc/sched_debug >> ${SPATH}/processes.txt

# DUMPSYS
adb shell dumpsys activity > ${SPATH}/dumpsys_activity.txt
adb shell dumpsys appops > ${SPATH}/dumpsys_apops.txt
adb shell dumpsys wifi > ${SPATH}/dumpsys_wifi.txt
adb shell dumpsys account > ${SPATH}/dumpsys_account.txt
adb shell dumpsys dbinfo > ${SPATH}/dumpsys_dbinfo.txt
adb shell dumpsys telecom > ${SPATH}/dumpsys_telecom.txt
adb shell dumpsys battery > ${SPATH}/dumpsys_battery.txt
adb shell dumpsys batterystats >> ${SPATH}/dumpsys_battery.txt
adb shell dumpsys usagestats > ${SPATH}/dumpsys_usagestats.txt
adb shell dumpsys meminfo -a > ${SPATH}/dumpsys_meminfo.txt
adb shell dumpsys procstats --full-details > ${SPATH}/dumpsys_procstats.txt

echo "[*] Done with stage one - now executing stage two - logcat"
adb shell logcat -S -b all > ${SPATH}/logcat_top.txt
adb shell logcat -d -b all V:* > ${SPATH}/logcat.txt
echo "[*] Done with stage two - now executing stage three - DUMPSYS ALL"
adb shell dumpsys > ${SPATH}/dumpsys_all.txt
echo "[*]"
echo "[*] EOF"

