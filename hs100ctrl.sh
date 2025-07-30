#!/bin/bash

cmd=$1
if [ $# = 3 ]
then
  ssid=$2
  pwd=$3
fi

script=$(basename $0)
folder=$(dirname $0)
cd ${folder}

##
# General instructions:
##

# First, on the same folder as the .sh script, create a .auth file with same name before .,
# defining variables cloudUserName and cloudPassword with user and password credentials used in Kasa app / tplink account

# Second, create a .data file also with same name before .,
# defining variables terminalUUID deviceId
# for terminalUUID use an arbitrary UUID generated on https://www.uuidgenerator.net/version4
# leave deviceId variable empty or to dummy value on this first execution

# Third, execute script with getDeviceList command to get linked device list
# note deviceId value for the device you want to control, and update it in the .data file for the deviceId variable

# Now you can execute any other command from the supported list (execute script without argument to see it).

# A script.token file will be automatically created on same dir to use in subsequent executions
# tokens expire but script automatically recreates them when needed.

# Commands available and syntax taken from https://www.softscheck.com/en/reverse-engineering-tp-link-hs110/
# and http://itnerd.space/2017/05/21/how-to-get-the-tp-link-hs100-cloud-end-point-url/ (for getDeviceList)
# How to get the tokens: http://itnerd.space/2017/06/19/how-to-authenticate-to-tp-link-cloud-api/

##
# Read parameters from external files (.auth, .data, .token)
##

# Read Kasa app credentials from external file, used only to generate tokens
authfile=${script%.sh}.auth
if [ -s ${authfile} ]
then
  # must define variables cloudUserName and cloudPassword in bash syntax
  # with valid username and password for Kasa app
  . ./${authfile}
fi
# check required variables have been sourced
if [ -z "${cloudUserName}" -o -z "{cloudPassword}" ]
then
  # authfile or variable definition missing, exit with error
  echo "${authfile} must exist defining cloudUserName and "
  echo "cloudPassword with valid Kasa username and password credentials"
  exit 1
fi

# Read app and device parameters from external file
datafile=${script%.sh}.data
if [ -s ${datafile} ]
then
  # must define variables terminalUUID and deviceId in bash syntax
  . ./${datafile}
fi
# check required variables have been sourced
if [ -z "${terminalUUID}" -o -z "${deviceId}" ]
then
  # datafile or variable definition missing, exit with error
  echo "${datafile} must exist defining terminalUUID deviceId"
  exit 1
fi

# for normal command execution, token must be already generated and stored in tokenfile
tokenfile=${script%.sh}.token
if [ -f ${tokenfile} ]
then
  # tokens expire in one month
  # let's play safe, and if token is older than one week (604800 seconds) regenerate it
  if [ $(($(date +%s)-$(date -r ${tokenfile} +%s))) -gt 604800 -o ! -s ${tokenfile} ]
  then
    rm ${tokenfile}
    sh ./${script} get_token
  fi
  Token=$(cat ${tokenfile})
else
  # token file is missing, so create it
  if [ "${cmd}" != get_token ]
  then
    # check required to avoid infinite recursive loop
	# create token and use it
	sh ./${script} get_token
    Token=$(cat ${tokenfile})
  fi
fi
# check required variable is not empty, like for example with empty tokenfile
# the only case where it can be empty is when invoked to generate the token
if [ -z "${Token}" -a "${cmd}" != get_token ]
then
  # datafile or variable definition missing, exit with error
  echo "${tokenfile} must exist with cloud auth token"
  exit 1
fi

##
# Functions
##

check_dependencies() {
  command -v curl >/dev/null 2>&1 || { echo >&2 "The curl programme for sending data over the network isn't in the path, communication with the plug will fail"; exit 2; }
 }

show_usage() {
  echo "Usage: $0 COMMAND "
  echo "where COMMAND is one of on/off/get_sysinfo/get_token/get_scaninfo/set_stainfo/getDeviceList"
  exit 1
}

check_arguments() {
  check_arg() {
    name="$1"
    value="$2"
    if [ -z "${value}" ]
    then
      echo "missing argument ${name}"
      show_usage
    fi
  }

  check_arg "command" ${cmd}
  if [ ${cmd} = set_stainfo ]
  then
    check_arg ssid ${ssid}
	check_arg pwd ${pwd}
  fi
}

send_to_switch_no_token () {
  data="$1"
# echo ${data}
   
  curl -sS \
  --request POST "${appServerUrl}" \
  --http1.1 \
  --data "${data}" \
  --header "Content-Type: application/json" && echo || echo couldn''t connect, curl failed with exit code $?
}

send_to_switch () {
  data="$1"
  echo ${appServerUrl}
  echo ${data}
   
  curl -sS \
  --request POST "${appServerUrl}?token=${Token}" \
  --http1.1 \
  --data "${data}" \
  --header "Content-Type: application/json" && echo || echo couldn''t connect, curl failed with exit code $?
}

##
#  Main programme
##

check_dependencies
check_arguments

#
# First of all (except updating/getting token if required) get appServerUrl for deviceId from getDeviceList current listing
#
# Use main DNS alias in tplinkcloud to get device list and parameters for each, including appServerUrl
appServerUrl="https://wap.tplinkcloud.com/"
# for the get_token or getDeviceList commands use always main DNS alias; do not forget trailing /
if [ "${cmd}" != get_token -a "${cmd}" != getDeviceList ]
then
  eval $(sh ./${script} getDeviceList | tr '{},' '\n' | grep -E 'appServerUrl|deviceId' | cut -d'"' -f2,4 | tr '"' = | while read line1; do read line2; echo $line1";"$line2; done | grep $deviceId | tr ';' '\n' | grep appServerUrl)
  # after eval execution appServerUrl is changed to the url that getDeviceList assigns currently to deviceId
fi

case "${cmd}" in
  on)
    send_to_switch '{"method":"passthrough", "params": {"deviceId": "'${deviceId}'", "requestData": "{\"system\":{\"set_relay_state\":{\"state\":1}}}" }}'
    ;;
  off)
    send_to_switch '{"method":"passthrough", "params": {"deviceId": "'${deviceId}'", "requestData": "{\"system\":{\"set_relay_state\":{\"state\":0}}}" }}'
    ;;
  get_sysinfo)
    send_to_switch '{"method":"passthrough", "params": {"deviceId": "'${deviceId}'", "requestData": "{\"system\":{\"get_sysinfo\":{}}}" }}'
    ;;
  get_token)
    # Token is generated by user/password login and stored in tokenfile in same folder as script
	# format of request reply:
	# {"error_code":0,"result":{"accountId":"699052","regTime":"2016-12-25 21:32:10","email":"jordi.monfar@gmail.com","token":"fd9d51c7-ff91bdb4cffc4e2092fad10"}}
    # order of results is NOT guaranteed, observed that sometimes email comes before or after token
    # it is safer to parse result by tag name than by position
    echo "Generating token and storing it in ${tokenfile}"
	send_to_switch_no_token '{"method":"login", "params": {"appType":"Kasa", "cloudUserName":"'${cloudUserName}'", "cloudPassword":"'${cloudPassword}'", "terminalUUID":"'${terminalUUID}'"}}' | tr '{},' '\n' | grep token.: | cut -d '"' -f4 | tee ${tokenfile}
    ;;
  get_scaninfo)
    send_to_switch '{"method":"passthrough", "params": {"deviceId": "'${deviceId}'", "requestData": "{\"netif\":{\"get_scaninfo\":{\"refresh\":1}}}" }}'
	;;
  set_stainfo)
    send_to_switch '{"method":"passthrough", "params": {"deviceId": "'${deviceId}'", "requestData": "{\"netif\":{\"set_stainfo\":{\"ssid\":\"'${ssid}'\",\"password\":\"'${pwd}'\",\"key_type\":3}}}" }}'
	;;  
  getDeviceList)
    send_to_switch '{"method":"getDeviceList"}'
    ;;
  *)
    show_usage
    ;;
esac
