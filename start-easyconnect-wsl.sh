#!/bin/bash

EASYCONNECT=/mnt/c/Program\ Files\ \(x86\)/Sangfor/SSL/EasyConnect/EasyConnect.exe
BAT_FILE=route-script.bat

check_dependency() {
    if ! which route &> /dev/null; then
        echo 1>&2 Error: \"route\" not found, run \"sudo apt install net-tools\"
        exit 1
    fi
}

check_wsl() {
    if ! cat /proc/version | grep -q Microsoft; then
        echo 1>&2 Error: Not in WSL
        exit 1
    fi
}

check_network() {
    export VPN_IP=`host vpn.nju.edu.cn | head -1 | rev | cut -d' ' -f1 | rev`  # must run before EasyConnect start
    export VPN_IP_START=`echo $VPN_IP | cut -d'.' -f-2`
    [[ ! $VPN_IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]] && echo 1>&2 Error: Cannot lookup domain of vpn.nju.edu.cn && exit 1
    # export BAT_FILE=${BAT_FILE%.bat}-`echo ${VPN_IP} | tr '.' '_'`.bat
    export IFACE_ID=`route.exe print if | grep Sangfor | tr -d ' ' | cut -d. -f1`
    [ -z "$IFACE_ID" ] && echo 1>&2 Cannot find \"Sangfor SSL VPN\" interface && exit 1
    export IFACE=`ip -o -4 addr show | grep ^${IFACE_ID} | cut -d' ' -f2`
    # echo '@echo off' > $BAT_FILE
    rm -f $BAT_FILE
}

check_easy_connect() {
    [ ! -x "$EASYCONNECT" ] && echo 1>&2 Error: \"${EASYCONNECT}\" not found && exit 1
}

get_iface_gw() {
    echo -n 'Wait 10 seconds for EasyConnect to complete ... 10s'
    for i in `seq -w 9 -1 -1`; do
        sleep 1
        echo -en '\b\b\b'${i}s
    done
    export IFACE_GW=`ip -o -4 route show dev ${IFACE} | grep via | cut -d' ' -f4 | sort | uniq -c | sort -nr | head -1 | tr -s ' ' | cut -d' ' -f3`
    echo -e '\b\b\bdone'
}

get_route_to_delete() {
    export ROUTE_TO_DEL=`route -n | grep ${IFACE}\$ | tr -s ' ' | grep -v $VPN_IP_START | grep -v ' 0.0.0.0'`
    ([ -n "$ROUTE_TO_DEL" ] || ! ps -p $EASY_CONNECT_PID &> /dev/null) && return 0
    return 1
}

wait_60s() {  # wait_60s NAME FUNC
    echo -n "Wait $1 ... 60s"
    for i in `seq -w 59 -1 -1`; do
        $2 && break
        sleep 1
        echo -en '\b\b\b'${i}s
    done
    if [ $i -eq -1 ]; then
        echo -e '\b\b\btimeout'
        return 1
    else
        echo -e '\b\b\bdone'
        return 0
    fi
}

int2ip() {
    local ui32=$1; shift
    local ip n
    for n in 1 2 3 4; do
        ip=$((ui32 & 0xff))${ip:+.}$ip
        ui32=$((ui32 >> 8))
    done
    echo $ip
}

netmask() {  # Example: netmask 24 => 255.255.255.0
    local mask=$((0xffffffff << (32 - $1))); shift
    int2ip $mask
}

delete_route_rules() {
    echo -n 'Generate route delete cmd ... '
    get_route_to_delete
    NET_IP=(`echo "$ROUTE_TO_DEL" | cut -d' ' -f1`)
    NET_MASK=(`echo "$ROUTE_TO_DEL" | cut -d' ' -f3`)
    for ((i=0;i<${#NET_IP[@]};i++)); do
        echo route DELETE "${NET_IP[i]}" MASK "${NET_MASK[i]}" "${IFACE_GW}" IF "${IFACE_ID}" '> nul' >> ${BAT_FILE}
    done
    echo done
}

add_route_rules() {
    echo -n 'Generate route add cmd ... '
    SUBNET="10.254.253.0/24 36.152.24.0/24 58.192.0.0/10 112.25.191.64/26 114.212.0.0/16 172.0.0.0/8 180.209.0.0/20 202.0.0.0/8 210.28.0.0/14 211.162.0.0/16 218.94.142.0/24 219.219.112.0/20 221.6.40.128/25"
    #SUBNET="10.254.253.0/24 36.152.24.0/24 58.192.32.0/20 58.192.48.0/21 58.193.224.0/19 58.240.127.0/27 112.25.191.64/26 114.212.0.0/16 172.0.0.0/8 180.209.0.0/20 202.119.32.0/19 202.127.247.0/24 202.38.126.160/28 202.38.2.0/23 210.28.128.0/20 210.29.240.0/20 211.162.26.0/27 211.162.81.0/25 218.94.142.0/24 219.219.112.0/20 221.6.40.128/25"
    for i in $SUBNET; do
        if [[ $i != ${VPN_IP_START}* ]]; then
            IFS='/' read -ra a <<< "$i"
            echo route ADD "${a[0]}" MASK "`netmask ${a[1]}`" "${IFACE_GW}" METRIC 257 IF "${IFACE_ID}" '> nul' >> ${BAT_FILE}
        fi
    done
    # echo pause >> ${BAT_FILE}
    echo done
}

check_wsl
check_dependency
check_easy_connect
check_network
"$EASYCONNECT" &> /dev/null &
EASY_CONNECT_PID=$!
wait_60s EasyConnect get_route_to_delete
[ -z "$ROUTE_TO_DEL" ] && echo -e Error: no rules to delete && exit 1
get_iface_gw
delete_route_rules
add_route_rules
echo "Run $BAT_FILE"
powershell.exe Start-Process -Verb runas -FilePath ./${BAT_FILE}
