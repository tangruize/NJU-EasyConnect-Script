# EasyConnect 启动脚本

EasyConnect是南大供师生访问校内资源的VPN, 疫情之下该软件使用需求极大. 但该客户端使用过程中存在一些问题:

- 该程序创建的虚拟网卡路由的IP地址过多(600+子网), 甚至将局域网(比如192.168开头)的IP进行了路由
- 不使用的情况下有以root权限运行的后台进程, 存在安全隐患
- Ubuntu 20.04 依赖关系存在问题

Windows WSL脚本[start-easyconnect-wsl.sh](start-easyconnect-wsl.sh)解决第一个问题, Linux脚本[start-easyconnect.sh](start-easyconnect.sh)解决前两个问题, 目录[libpango](libpango)中有解决第三个问题的方法.

目前Windows脚本需要使用WSL(建议Ubuntu 18.04), 不想安装WSL的话有一个半自动的python脚本[run-bat.py](run-bat.py), 欢迎大家提PR完善一个自动BAT批处理文件.

## 安装 EasyConnect

访问 <https://vpn.nju.edu.cn/> 下载相应的客户端并安装.

如果使用Ubuntu 20.04或提示`Harfbuzz version too old`可以尝试[libpango/README.md](libpango/README.md)的解决方法.

## Ubuntu

由于 EasyConnect 开机后会通过 systemd 启动后台服务, 我们可以在需要时启动, 所以可以禁用这个服务 (当然, 不禁用也可以用):

```bash
sudo systemctl stop EasyMonitor.service
sudo systemctl disable EasyMonitor.service
```

有几个程序有 setuid 权限, 但是不是必要的, 可以去掉:

```bash
sudo chmod -s /usr/share/sangfor/EasyConnect/resources/bin/CSClient /usr/share/sangfor/EasyConnect/resources/bin/ECAgent
```

安装依赖关系:

```bash
sudo apt install net-tools  # 使用了route命令
```

直接运行 (操作路由表需要root权限, 会提示你输入密码):

```bash
./start-easyconnect.sh
```

通过点击图标运行: 修改`/usr/share/applications/EasyConnect.desktop`第5行`Exec=`为你的`start-easyconnect.sh`的绝对路径:

```bash
sudo sed "s@Exec=.*@Exec=\"`realpath ./start-easyconnect.sh`\"@" /usr/share/applications/EasyConnect.desktop #-i
# 上一行命令的注释去掉(加 -i)才能写入
```

如果不希望使用 EasyConnect 提供的 DNS 服务器, 可以对程序进行 patch:

```bash
cd /usr/share/sangfor/EasyConnect/resources/bin
sudo cp svpnservice svpnservice.bak
echo -e '\x39\xc0\x39\xc0' | sudo dd of=svpnservice count=4 seek=284760 oflag=seek_bytes iflag=count_bytes conv=notrunc  # 39 c0: cmp eax, eax
```

`svpnservice` 程序判断 `/etc/resolv.conf` 的修改时间有没有发生变化, 如果改变了就将内容复写掉. 上面的命令修改了程序, 让程序认为文件始终没有被修改.

## Windows WSL

推荐使用Ubuntu 18.04.

安装依赖关系:

```bash
sudo apt install net-tools  # 使用了route命令
```

直接运行(不要先手动运行 EasyConnect):

```bash
./start-easyconnect-wsl.sh
```

会提示使用管理员权限运行.

如果先运行了 EasyConnect 再运行脚本会导致 `vpn.nju.edu.cn` DNS解析为一个不正确的值, 导致连接失败, 可能需要重启电脑修复不能连接的问题.

## Windows 手动运行 BAT

如果没有WSL, 可以手动运行 BAT 批处理脚本, 但不保证能成功.

文件 [route-script-218_94_142_100.bat](route-script-218_94_142_100.bat) 和 [route-script-221_6_40_201.bat](route-script-221_6_40_201.bat) 是个模板, 不能直接运行. 文件名中的 `218_94_142_100` 表示 `vpn.nju.edu.cn` 的 IP 地址. 这个域名的 IP 地址可能与运营商和地区有关, 经过我的测试, 移动和电信的 IP 是 `218.94.142.100`, 联通的是 `221.6.40.201`.

你需要运行 EasyConnect 前在 cmd 中运行 `nslookup vpn.nju.edu.cn` 或 `ping vpn.nju.edu.cn` 来获取 `vpn.nju.edu.cn` 的IP地址, 如果 IP 地址与文件名中匹配(只需要匹配前两位, `218.94.*.*` 或 `221.6.*.*`), 则可以使用这种方法.

你需要运行 EasyConnect 后获取 EasyConnect 创建的虚拟网卡的 ID (iface) 和 路由表中的网关(gateway).

对于 iface, 在 cmd 中运行 `route print if`, 如果有一行包含 Sangfor 如下, 则 iface 为开头的 16.

```
 16...00 ff 8d 99 d4 43 ......Sangfor SSL VPN CS Support System VNIC
 ```

 对于 gateway, 在 cmd 中运行 `route print`, 第三列网关出现最多的就是(应该以172开头), 如这里是 `172.29.36.204`:

 ```
 IPv4 路由表
===========================================================================
活动路由:
网络目标        网络掩码          网关       接口   跃点数
0.0.0.0          0.0.0.0      192.168.1.1      192.168.1.6     50
1.0.0.0        255.0.0.0    172.29.36.204    172.29.36.201    257
2.0.0.0        255.0.0.0    172.29.36.204    172.29.36.201    257
3.0.0.0        255.0.0.0    172.29.36.204    172.29.36.201    257
```

将 bat 模板中的 `{iface}` 全部替换为 `16`, 将 `{gateway}` 全部替换为 `172.29.36.204` 即可运行.

使用方法:

- 根据 `vpn.nju.edu.cn` 的 IP 地址选择合适的 bat 文件
- 启动 EasyConnect
- 找到 iface 和 gateway, 并将 bat 文件中的 `{iface}` 和 `{gateway}` 全部替换
- 管理员权限运行 bat 文件

可以看出这种方法非常麻烦, 如果确定了相应的 bat 文件且有 python3 环境, 在启动 EasyConnect 后, 可以直接运行:

```bash
python3 run-bat.py route-script-x_x_x_x.bat
```

这个脚本会自动查找 iface 和 gateway 并替换运行.

## 脚本说明

Linux脚本主要流程如下, 如有人感兴趣可以研究一下 Windows 全自动的 bat 脚本:

- 查询 `vpn.nju.edu.cn` 的 IP 地址
- 启动 EasyMonitor.service (如果未启动)
- 启动 EasyConnect
- 等待路由表更新
- 删除 tun0 网卡的所有路由规则, 除了 `vpn.nju.edu.cn` 的 IP 地址所在子网
- 添加路由规则, 上一步除外的子网不会添加
- 如果对 svpnservice 进行了 hack, 删除相关 iptables 规则并还原 resolv.conf
- 如果脚本启动了 EasyMonitor.service, 则等待 EasyConnect 退出并停止 EasyMonitor.service

删除时跳过`vpn.nju.edu.cn`的IP地址所在子网是因为这个网址需要走默认路由, 路由规则里会跳过这个IP, 比如该网址的IP是`218.94.142.100`, 路由规则允许`218.94.142.99`和`218.94.142.101`走 tun0, 而不允许`218.94.142.100`, 所以不作更改, 且添加时也会跳过这个子网.

添加的路由规则主要来自于 EasyConnect 软件界面的默认资源组的资源地址, 整理如下:

```
10.254.253.0/24 36.152.24.0/24 58.192.32.0/20 58.192.48.0/21 58.193.224.0/19 58.240.127.0/27 112.25.191.64/26 114.212.0.0/16 172.0.0.0/8 180.209.0.0/20 202.119.32.0/19 202.127.247.0/24 202.38.126.160/28 202.38.2.0/23 210.28.128.0/20 210.29.240.0/20 211.162.26.0/27 211.162.81.0/25 218.94.142.0/24 219.219.112.0/20 221.6.40.128/25
```

但用起来有的网站似乎有一点问题, 我合并了一些开头相同的子网:

```
10.254.253.0/24 36.152.24.0/24 58.192.0.0/10 112.25.191.64/26 114.212.0.0/16 172.0.0.0/8 180.209.0.0/20 202.0.0.0/8 210.28.0.0/14 211.162.0.0/16 218.94.142.0/24 219.219.112.0/20 221.6.40.128/25
```
