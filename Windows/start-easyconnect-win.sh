#!/bin/bash

EASYCONNECT_DIR=C:/Program\ Files\ \(x86\)/Sangfor/SSL/EasyConnect
EASYCONNECT_NAME=EasyConnect.exe

check_network() {
    if [ -z "$VPN_IP" ]; then
        export VPN_IP=`nslookup.exe vpn.nju.edu.cn 2> nul | grep vpn.nju.edu.cn -A1 | grep Address | head -1 | rev | cut -d' ' -f1 | rev`
    fi
    export VPN_IP_START=`echo $VPN_IP | cut -d'.' -f-2`
    [ -z "$VPN_IP" ] && echo 1>&2 Error: Cannot lookup domain of vpn.nju.edu.cn && exit 1
    export IFACE_ID=`route.exe print if | grep Sangfor | tr -d ' ' | cut -d. -f1`
    [ -z "$IFACE_ID" ] && echo 1>&2 Cannot find \"Sangfor SSL VPN\" interface && exit 1
}

check_easy_connect() {
    [ ! -f "$EASYCONNECT_DIR/$EASYCONNECT_NAME" ] && echo 1>&2 Error: \"${EASYCONNECT_NAME}\" not found && exit 1
}

get_iface_gw() {
    IFACE_INFO=`route.exe print \?22.0.0.0 | grep '^[ ]*[0-9]\+.[0-9]\+.[0-9]\+.[0-9]\+' | awk '{ print $3,$4 }' | sort | uniq -c | sort -nr | head -1`
    export IFACE_GW=`echo $IFACE_INFO | awk '{ print $2 }'`
    export IFACE_IP=`echo $IFACE_INFO | awk '{ print $3 }'`
    ([ -n "$IFACE_IP" ] || ! pidof $EASYCONNECT_NAME &> nul) && return 0
    return 1
}

get_route_to_delete() {
    export ROUTE_TO_DEL=`route.exe print | grep $IFACE_IP | grep -v $VPN_IP_START`
    ([ -n "$ROUTE_TO_DEL" ] || ! pidof $EASYCONNECT_NAME &> nul) && return 0
    return 1
}

wait_60s() {
    echo -n "Wait $1 ... 60s"
    for _i in `seq -w 59 -1 -1`; do
        $2 && break
        sleep 1
        echo -en '\b\b\b'${_i}s
    done
    if [ ${_i} -eq -1 ]; then
        echo -e '\b\b\btimeout'
        return 1
    else
        echo -e '\b\b\bdone'
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

delete_route_rules() {
    echo -n 'Delete route rules ... '
    get_route_to_delete
    ROUTE_RULES=$(echo "$ROUTE_TO_DEL" | awk '{ print $1,"MASK",$2 }')
    COUNT=1
    TOTAL=`echo "$ROUTE_RULES" | wc -l`
    echo "$ROUTE_RULES" | tac | while read RULE; do
        # echo "route.exe DELETE $RULE IF ${IFACE_ID} > nul"
        eval "route.exe DELETE $RULE IF ${IFACE_ID} > nul"
        show_progress $COUNT $TOTAL
        COUNT=$((COUNT+1))
    done
    echo done
}

add_route_rules() {
    echo -n 'Add route rules ... '
    #SUBNET="10.254.253.0/24 36.152.24.0/24 58.192.0.0/10 112.25.191.64/26 114.212.0.0/16 172.0.0.0/8 180.209.0.0/20 202.0.0.0/8 210.28.0.0/14 211.162.0.0/16 218.94.142.0/24 219.219.112.0/20 221.6.40.128/25"
    SUBNET="36.152.24.0/24 58.192.32.0/20 58.192.48.0/21 58.193.224.0/19 58.240.127.0/27 112.25.191.64/26 114.212.0.0/16 172.0.0.0/8 180.209.0.0/20 202.38.2.0/23 202.38.126.160/28 202.119.32.0/19 202.127.247.0/24 210.28.0.0/14 211.162.26.0/27 211.162.81.0/25 218.94.142.0/24 219.219.112.0/20 221.6.40.128/25 222.94.3.0/24 222.94.208.0/24"
    COUNT=1
    TOTAL=`echo "$SUBNET" | tr ' ' '\n' | wc -l`
    for i in $SUBNET; do
        if [[ $i != ${VPN_IP_START}* ]]; then
            IP=`ipcalc -n $i | awk -F= '{ print $2 }'`
            MASK=`ipcalc -m $i | awk -F= '{ print $2 }'`
            # echo route.exe ADD "$IP" MASK "$MASK" "${IFACE_GW}" METRIC 257 IF "${IFACE_ID}"
            route.exe ADD "$IP" MASK "$MASK" "${IFACE_GW}" METRIC 257 IF "${IFACE_ID}" > nul
            show_progress $COUNT $TOTAL
            COUNT=$((COUNT+1))
        fi
    done
    echo done
}

if [ "$#" -eq 0 ]; then
    check_easy_connect
    check_network
    cd "$EASYCONNECT_DIR"
    cmd.exe /c start /B ".\\$EASYCONNECT_NAME"
    cd - > nul
    wait_60s EasyConnect get_iface_gw
    [ -z "$IFACE_IP" ] && echo 1>&2 Error: Cannot get interface IP && exit 1
    su -c "sh $0 admin $VPN_IP; exit"
elif [ "$#" -eq 2 -a "$1" = "admin" ]; then
    export VPN_IP=$2
    check_network
    wait_60s "EasyConnect interface" get_iface_gw
    wait_60s "EasyConnect route" get_route_to_delete
    [ -z "$ROUTE_TO_DEL" ] && echo 1>&2 Error: No route rules to delete && exit 1
    delete_route_rules
    add_route_rules
else
    echo 1>&2 Usage: sh.exe $0
fi