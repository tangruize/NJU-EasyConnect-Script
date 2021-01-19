#!/bin/bash

check_network() {
    export VPN_IP=`host vpn.nju.edu.cn | head -1 | rev | cut -d' ' -f1 | rev`
    export VPN_IP_START=`echo $VPN_IP | cut -d'.' -f-2`
    if [[ ! $VPN_IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo 1>&2 Error: Cannot lookup domain of vpn.nju.edu.cn
        exit 1
    fi
}

check_easy_connect() {
    if [ ! -d "/Applications/EasyConnect.app" ]; then
        echo 1>&2 Error: \"EasyConnect\" not found
        exit 1
    fi
}

NOECHO() {
    return 0
}

wait_60s() {
    ECHO=${3:-echo}
    $ECHO -n "Wait $1 ... 60s"
    for i in `seq -w 59 -1 -1`; do
        $2 && break
        sleep 1
        $ECHO -en '\b\b\b'${i}s
    done
    if [ $i -eq -1 ]; then
        $ECHO -e '\b\b\btimeout'
        return 1
    else
        $ECHO -e '\b\b\bdone'
        return 0
    fi
}

start_easy_connect() {
    echo -n 'Starting EasyConnect ... '
    if ! open -a EasyConnect; then
        echo 1>&2 Error: Open EasyConnect failed
        exit 1
    fi
    echo done
}

get_route_to_delete() {
    export ROUTE_TO_DEL=`netstat -rn | grep -w tun0 | tr -s ' ' | grep -v $VPN_IP_START`
    if [ -n "$ROUTE_TO_DEL" ]; then
        return 0
    fi
    return 1
}

delete_route_rules() {
    echo 'Delete route rules ... '
    sleep 3
    get_route_to_delete
    NET_IP=(`echo "$ROUTE_TO_DEL" | cut -d' ' -f1`)
    NET_FLAG=(`echo "$ROUTE_TO_DEL" | cut -d' ' -f3`)
    export GATEWAY=`echo "$ROUTE_TO_DEL" | cut -d' ' -f2 | uniq | head -1`
    for ((i=0;i<${#NET_IP[@]};i++)); do
        if grep -vq / <<< ${NET_IP[i]} && [ "${NET_FLAG[i]}" = "UGSc" ]; then
            sudo route delete "${NET_IP[i]}/0"
        else
            sudo route delete "${NET_IP[i]}"
        fi
    done
}

add_route_rules() {
    echo 'Add route rules ... '
    if [ -z "$GATEWAY" ]; then
        GATEWAY=`ifconfig tun0 | tr ' ' '\n' | grep '[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1`
        if [ -z "$GATEWAY" ]; then
            echo 1>&2 Warning: Gateway is null
        fi
    fi
    SUBNET="10.254.253.0/24 36.152.24.0/24 58.192.0.0/10 112.25.191.64/26 114.212.0.0/16 172.0.0.0/8 180.209.0.0/20 202.0.0.0/8 210.28.0.0/14 211.162.0.0/16 218.94.142.0/24 219.219.112.0/20 221.6.40.128/25"
    for i in $SUBNET; do
        if [[ $i != ${VPN_IP_START}* ]]; then
            sudo route -n add -net $i $GATEWAY
        fi
    done
}

check_network
check_easy_connect
start_easy_connect
wait_60s EasyConnect get_route_to_delete
if [ -z "$ROUTE_TO_DEL" ]; then
    echo -e Error: no rules to delete
    exit 1
fi
delete_route_rules
add_route_rules
