# EasyConnect 启动脚本 (Linux)

EasyConnect是南大供师生访问校内资源的VPN, 疫情之下该软件使用需求极大. 但Linux客户端使用过程中存在一些问题:

- 该程序创建的虚拟网卡路由的IP地址过多(600+子网), 甚至将局域网(比如192.168开头)的IP进行了路由
- 不使用的情况下有以root权限运行的后台进程, 存在安全隐患
- Ubuntu 20.04 依赖关系存在问题

脚本[start-easyconnect.sh](start-easyconnect.sh)解决前两个问题, 目录[libpango](libpango)中有解决第三个问题的方法.

目前没有Windows客户端的脚本, 欢迎大家提PR.

## 安装 EasyConnect

访问 <https://vpn.nju.edu.cn/> 下载相应的客户端并安装.

如果使用Ubuntu 20.04或提示`Harfbuzz version too old`可以尝试[libpango/README.md](libpango/README.md)的解决方法.

## 使用脚本

由于 EasyConnect 开机后会通过 systemd 启动后台服务, 我们可以在需要时启动, 所以可以禁用这个服务 (当然, 不禁用也可以用):

```bash
sudo systemctl stop EasyMonitor.service
sudo systemctl disable EasyMonitor.service
```

直接运行:

```bash
./start-easyconnect.sh
```

操作路由表需要root权限, 会提示你输入密码.

## 脚本说明

Linux脚本主要流程如下, 如有人感兴趣可以研究一下Windows脚本:

- 启动 EasyMonitor.service (如果未启动)
- 启动 EasyConnect
- 等待路由表更新
- 删除 tun0 网卡的所有路由规则, 除了 `vpn.nju.edu.cn` 的 IP 地址所在子网
- 添加路由规则, 上一步除外的子网不会添加
- 如果脚本启动了 EasyMonitor.service, 则等待 EasyConnect 退出并停止 EasyMonitor.service

删除时跳过`vpn.nju.edu.cn`的IP地址所在子网是因为这个网址需要走默认路由, 路由规则里会跳过这个IP, 比如该网址的IP是`218.94.142.100`, 路由规则允许`218.94.142.99`和`218.94.142.101`走 tun0, 而不允许`218.94.142.100`, 所以不作更改, 且添加时也会跳过这个子网.

添加的路由规则主要来自于 EasyConnect 软件界面的默认资源组的资源地址, 整理如下(脚本[第86行](https://github.com/tangruize/NJU-EasyConnect-Script/blob/master/start-easyconnect.sh#L86)):

```
10.254.253.0/24 36.152.24.0/24 58.192.32.0/20 58.192.48.0/21 58.193.224.0/19 58.240.127.0/27 112.25.191.64/26 114.212.0.0/16 172.0.0.0/8 180.209.0.0/20 202.119.32.0/19 202.127.247.0/24 202.38.126.160/28 202.38.2.0/23 210.28.128.0/20 210.29.240.0/20 211.162.26.0/27 211.162.81.0/25 218.94.142.0/24 219.219.112.0/20 221.6.40.128/25
```

但用起来有的网站似乎有一点问题, 我合并了一些开头相同的子网(脚本[第85行](https://github.com/tangruize/NJU-EasyConnect-Script/blob/master/start-easyconnect.sh#L85)):

```
10.254.253.0/24 36.152.24.0/24 58.192.0.0/10 112.25.191.64/26 114.212.0.0/16 172.0.0.0/8 180.209.0.0/20 202.0.0.0/8 210.28.0.0/14 211.162.0.0/16 218.94.142.0/24 219.219.112.0/20 221.6.40.128/25
```
