#!/bin/bash

cmd=$1
if [ $# = 3 ]
then
  ssid=$2
  pwd=$3
fi

# How to get parameters (from http://itnerd.space/2017/01/22/how-to-control-your-tp-link-hs100-smartplug-from-internet/)

# adb devices
# adb backup -f backup.ab com.tplink.kasa_android
# dd if=backup.ab bs=1 skip=24 | python -c "import zlib,sys;sys.stdout.write(zlib.decompress(sys.stdin.read()))" | tar -xvf -
# cd apps/com.tplink.kasa_android

# apt-get install sqlite3 #if required
# sqlite3 db/iot.1.db "select token from accounts;"
# Token="fd9d51c7-cdd9abd5be5545c4afc068c" # expired April 21, 2017
# Token="fd9d51c7-1731bfe70aa64871bd411e2" # expired May 21, 2017
# Token="fd9d51c7-6ca4e0fa523e4669bffc055" # expired Jun 21, 2017
  Token="fd9d51c7-5c6b6b1c2ea744149ecc40b"

# sqlite3 db/iot.1.db "select deviceAlias,deviceID from devices;"
# deviceID="FMG Smart Plug 1|8006E6EDC0696B7B38D61832B4A8F12E171E66D7"
deviceID="8006E6EDC0696B7B38D61832B4A8F12E171E66D7"

# cat f/INSTALLATION
termid="278960c6-d86d-438d-82a7-fa0b809ef575"

# Commands available and syntax taken from https://www.softscheck.com/en/reverse-engineering-tp-link-hs110/

# tools

check_dependencies() {
  command -v curl >/dev/null 2>&1 || { echo >&2 "The curl programme for sending data over the network isn't in the path, communication with the plug will fail"; exit 2; }
 }

show_usage() {
  echo Usage: $0 COMMAND
  echo where COMMAND is one of on/off/get_sysinfo/get_scaninfo/set_stainfo
  exit 1
}

check_arguments() {
   check_arg() {
    name="$1"
    value="$2"
    if [ -z "$value" ]; then
       echo "missing argument $name"
       show_usage
    fi
   }

   check_arg "command" $cmd
   if [ $cmd = set_stainfo ]
   then
     check_arg ssid $ssid
	 check_arg pwd $pwd
   fi
}

send_to_switch () {
   data="${1}"
   echo ${data}
   
   curl --request POST "https://eu-wap.tplinkcloud.com/?token=${Token} HTTP/1.1" \
   --data "${data}" \
   --header "Content-Type: application/json" && echo || echo couldn''t connect, curl failed with exit code $?
}

##
#  Main programme
##

check_dependencies
check_arguments

case "$cmd" in
  on)
     send_to_switch '{"method":"passthrough", "params": {"deviceId": "'${deviceID}'", "requestData": "{\"system\":{\"set_relay_state\":{\"state\":1}}}" }}'
     ;;
  off)
     send_to_switch '{"method":"passthrough", "params": {"deviceId": "'${deviceID}'", "requestData": "{\"system\":{\"set_relay_state\":{\"state\":0}}}" }}'
     ;;
  get_sysinfo)
     send_to_switch '{"method":"passthrough", "params": {"deviceId": "'${deviceID}'", "requestData": "{\"system\":{\"get_sysinfo\":{}}}" }}'
     ;;
  get_scaninfo)
     send_to_switch '{"method":"passthrough", "params": {"deviceId": "'${deviceID}'", "requestData": "{\"netif\":{\"get_scaninfo\":{\"refresh\":1}}}" }}'
	 ;;
  set_stainfo)
     send_to_switch '{"method":"passthrough", "params": {"deviceId": "'${deviceID}'", "requestData": "{\"netif\":{\"set_stainfo\":{\"ssid\":\"'${ssid}'\",\"password\":\"'${pwd}'\",\"key_type\":3}}}" }}'
	 ;;  
  *)
     show_usage
     ;;
esac
