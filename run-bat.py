#! python3

iface = ""
gateway = ""

import sys
import os
import re

if len(sys.argv) < 2:
    print("Usage: python3", sys.argv[0], "route-script-x_x_x_x.bat [gateway] [iface]")
    sys.exit(1)
if len(sys.argv) >= 3:
    gateway = sys.argv[2]
if len(sys.argv) >= 4:
    iface = sys.argv[3]

if not iface:
    route_print_result = os.popen('route.exe print if').read().replace('\n', '')
    pat = re.compile(r'.* ([0-9]+)\.\.\..*Sangfor')
    m = pat.match(route_print_result)
    if not m:
        print("Error: Cannot get interface ID")
        sys.exit(1)
    else:
        iface = m.group(1)
        print("Info: iface =", iface)

if not gateway:
    pat = re.compile(r' ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)'*4)
    gw_list = []
    for line in re.sub(' +', ' ', os.popen('route.exe print').read()).splitlines():
        m = pat.match(line)
        if m:
            gw_list.append(m.group(3))
    gateway = max(set(gw_list), key=gw_list.count)  # most frequent
    print("Info: gateway =", gateway)

script_template = open(sys.argv[1], 'r').read()
script = script_template.format_map(vars())
with open('route-script.bat', 'w') as script_file:
    print(script, file=script_file)

os.system('powershell.exe Start-Process -Verb runas -FilePath ./route-script.bat')
