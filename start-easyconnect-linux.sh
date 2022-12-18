#!/bin/bash

EASYCONNECT=/usr/share/sangfor/EasyConnect/EasyConnect

check_dependency() {
    if ! which route &> /dev/null; then
        echo 1>&2 Error: \"route\" not found, run \"sudo apt install net-tools\"
        exit 1
    fi
}

check_network() {
    export VPN_IP=`host vpn.nju.edu.cn | head -1 | rev | cut -d' ' -f1 | rev`
    export VPN_IP_START=`echo $VPN_IP | cut -d'.' -f-2`
    [[ ! $VPN_IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]] && echo 1>&2 Error: Cannot lookup domain of vpn.nju.edu.cn && exit 1
}

check_easy_connect() {
    [ ! -x "$EASYCONNECT" ] && echo 1>&2 Error: \"${EASYCONNECT}\" not found && exit 1
    export EASY_CONNECT_PID=1
}

get_easy_monitor_status() {
    grep -q running <(systemctl status EasyMonitor.service)
    return $?
}

start_easy_monitor() {
    if ! get_easy_monitor_status; then
        sudo systemctl start EasyMonitor.service
        return 0
    fi
    return 1
}

stop_easy_monitor() {
    if get_easy_monitor_status; then
        echo -n 'Stop EasyMonitor ...'
        sudo systemctl stop EasyMonitor.service
        echo done
    fi
}

NOECHO() {
    return 0
}

wait_60s() {  # wait_60s NAME FUNC [NOECHO]
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
    wait_60s Easymonitor get_easy_monitor_status NOECHO || exit 1
    if ! grep -q tun0 <(ip link show); then
        $EASYCONNECT --enable-transparent-visuals --disable-gpu &> /dev/null
        #LD_LIBRARY_PATH=/snap/gnome-3-28-1804/current/usr/lib/x86_64-linux-gnu/ $EASYCONNECT --enable-transparent-visuals --disable-gpu &> /dev/null
    fi
}

get_route_to_delete() {
    export ROUTE_TO_DEL=`route -n | grep -w tun0 | tr -s ' ' | grep -v $VPN_IP_START`
    ([ -n "$ROUTE_TO_DEL" ] || ! ps -p $EASY_CONNECT_PID &> /dev/null) && return 0
    return 1
}

delete_route_rules() {
    echo -n 'Delete route rules ... '
    sleep 2 && get_route_to_delete
    NET_IP=(`echo "$ROUTE_TO_DEL" | cut -d' ' -f1`)
    NET_MASK=(`echo "$ROUTE_TO_DEL" | cut -d' ' -f3`)
    for ((i=0;i<${#NET_IP[@]};i++)); do
        sudo route del -net "${NET_IP[i]}" netmask "${NET_MASK[i]}" dev tun0
    done
    echo done
}

add_route_rules() {
    echo -n 'Add route rules ... '
    SUBNET="36.152.24.0/24 58.192.32.0/20 58.192.48.0/21 58.193.224.0/19 58.240.127.0/27 112.25.191.64/26 114.212.0.0/16 172.0.0.0/8 180.209.0.0/20 202.38.2.0/23 202.38.126.160/28 202.119.32.0/19 202.127.247.0/24 210.28.0.0/14 211.162.26.0/27 211.162.81.0/25 218.94.142.0/24 219.219.112.0/20 221.6.40.128/25 222.94.3.0/24 222.94.208.0/24"
    #SUBNET="10.254.253.0/24 36.152.24.0/24 58.192.0.0/10 112.25.191.64/26 114.212.0.0/16 172.0.0.0/8 180.209.0.0/20 202.0.0.0/8 210.28.0.0/14 211.162.0.0/16 218.94.142.0/24 219.219.112.0/20 221.6.40.128/25"
    for i in $SUBNET; do
        [[ $i != ${VPN_IP_START}* ]] && sudo ip route add $i dev tun0
    done
    echo done
}

change_dns() {
    if [ -f /etc/resolv.conf.sangforbak ]; then
        if [ "`dd if=/usr/share/sangfor/EasyConnect/resources/bin/svpnservice count=2 skip=284760 iflag=skip_bytes,count_bytes 2>/dev/null`" = "`echo -en '\x39\xc0'`" ]; then
            echo -n 'Restore DNS server ... '
            grep 'were added' /usr/share/sangfor/EasyConnect/resources/logs/DNS.log | tail -1 | cut -d: -f4- | sed 's/-A/-D/' | cat - <(echo cp /etc/resolv.conf.sangforbak /etc/resolv.conf) | sudo sh -e &>/dev/null
            [ $? -eq 0 ] && echo 'done' || echo 'failed'
        fi
    fi
}

check_dependency
check_network
if [ -z "$1" ]; then
    check_easy_connect
    start_easy_connect &
    EASY_CONNECT_PID=$!
    pkexec --user root "`realpath $0`" $EASY_CONNECT_PID
    exit $?
else
    export EASY_CONNECT_PID=$1
    start_easy_monitor
    START_BY_SCRIPT=$?
    wait_60s EasyConnect get_route_to_delete
    if [ -z "$ROUTE_TO_DEL" ]; then
        echo -e Error: no rules to delete
        exit 1
    fi
    delete_route_rules
    add_route_rules
    change_dns
    if [ $START_BY_SCRIPT -eq 0 ]; then
        echo -n 'Wait EasyConnect exit ... '
        tail --pid=$EASY_CONNECT_PID -f /dev/null
        echo done
        stop_easy_monitor
    else
        echo 'Wait EasyConnect exit ... skip'
        echo 'Stop EasyMonitor ... skip'
    fi
fi
