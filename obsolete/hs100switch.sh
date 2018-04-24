#!/bin/bash

cmd=$1

# How to get parameters (from http://itnerd.space/2017/01/22/how-to-control-your-tp-link-hs100-smartplug-from-internet/)

# adb backup -f backup.ab com.tplink.kasa_android
# dd if=backup.ab bs=1 skip=24 | python -c "import zlib,sys;sys.stdout.write(zlib.decompress(sys.stdin.read()))" | tar -xvf -
# cd apps/com.tplink.kasa_android

# sqlite3 db/iot.1.db "select token from accounts;"
Token="fd9d51c7-cdd9abd5be5545c4afc068c"

# sqlite3 db/iot.1.db "select deviceAlias,deviceID from devices;"
#deviceID="FMG Smart Plug 1|8006E6EDC0696B7B38D61832B4A8F12E171E66D7"
deviceID="8006E6EDC0696B7B38D61832B4A8F12E171E66D7"

# cat f/INSTALLATION
termid="278960c6-d86d-438d-82a7-fa0b809ef575"

# tools

check_dependencies() {
  command -v curl >/dev/null 2>&1 || { echo >&2 "The curl programme for sending data over the network isn't in the path, communication with the plug will fail"; exit 2; }
 }

show_usage() {
  echo Usage: $0 COMMAND
  echo where COMMAND is one of on/off
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
}

send_to_switch () {
   state="$1"
   
   curl --silent --request POST "https://eu-wap.tplinkcloud.com/?token=${Token} HTTP/1.1" \
  --data '{"method":"passthrough", "params": {"deviceId": "'${deviceID}'", "requestData": "{\"system\":{\"set_relay_state\":{\"state\":'${state}'}}}" }}' \
  --header "Content-Type: application/json" >/dev/null || echo couldn''t connect, curl failed with exit code $?
}

##
#  Main programme
##

check_dependencies
check_arguments

case "$cmd" in
  on)
     send_to_switch 1
     ;;
  off)
     send_to_switch 0
     ;;
  *)
     show_usage
     ;;
esac
