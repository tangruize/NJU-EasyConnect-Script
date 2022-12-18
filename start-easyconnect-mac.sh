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

show_progress() {
    LEN=${#2}
    if [ "$1" -ne 1 ]; then
        for _i in `seq $((LEN*2+1))`; do
            if [ "$1" -ne "$2" ]; then
                echo -en '\b'
            else
                echo -en '\b \b'
            fi
        done
    fi
    if [ "$1" -ne "$2" ]; then
        printf "%0${LEN}d/$2" $1
    fi
}

start_easy_connect() {
    if ! open -a EasyConnect; then
        echo 1>&2 Error: Open EasyConnect failed
        exit 1
    fi
}

get_route_to_delete() {
    export ROUTE_TO_DEL=`netstat -rn | grep -w tun0 | tr -s ' ' | grep -v $VPN_IP_START`
    if [ -n "$ROUTE_TO_DEL" ]; then
        return 0
    fi
    return 1
}

delete_route_rules() {
    echo -n 'Delete route rules ... '
    sleep 3
    get_route_to_delete
    NET_IP=(`echo "$ROUTE_TO_DEL" | cut -d' ' -f1`)
    NET_FLAG=(`echo "$ROUTE_TO_DEL" | cut -d' ' -f3`)
    export GATEWAY=`echo "$ROUTE_TO_DEL" | cut -d' ' -f2 | uniq | head -1`
    for ((i=0;i<${#NET_IP[@]};i++)); do
        if grep -vq / <<< ${NET_IP[i]} && [ "${NET_FLAG[i]}" = "UGSc" ]; then
            sudo route delete "${NET_IP[i]}/0" > /dev/null
        else
            sudo route delete "${NET_IP[i]}" > /dev/null
        fi
        show_progress $((i+1)) ${#NET_IP[@]}
    done
    echo done
}

add_route_rules() {
    echo -n 'Add route rules ... '
    if [ -z "$GATEWAY" ]; then
        GATEWAY=`ifconfig tun0 | tr ' ' '\n' | grep '[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1`
        if [ -z "$GATEWAY" ]; then
            echo 1>&2 Warning: Gateway is null
        fi
    fi
    SUBNET=(36.152.24.0/24 58.192.32.0/20 58.192.48.0/21 58.193.224.0/19 58.240.127.0/27 112.25.191.64/26 114.212.0.0/16 172.0.0.0/8 180.209.0.0/20 202.38.2.0/23 202.38.126.160/28 202.119.32.0/19 202.127.247.0/24 210.28.0.0/14 211.162.26.0/27 211.162.81.0/25 218.94.142.0/24 219.219.112.0/20 221.6.40.128/25 222.94.3.0/24 222.94.208.0/24)
    for ((i=0;i<${#SUBNET[@]};i++)); do
        if [[ ${SUBNET[i]} != ${VPN_IP_START}* ]]; then
            sudo route -n add -net ${SUBNET[i]} $GATEWAY > /dev/null
            show_progress $((i+1)) ${#SUBNET[@]}
        fi
    done
    echo done
}

check_network
check_easy_connect
sudo true
start_easy_connect
wait_60s EasyConnect get_route_to_delete
if [ -z "$ROUTE_TO_DEL" ]; then
    echo -e Error: no rules to delete
    exit 1
fi
delete_route_rules
add_route_rules
