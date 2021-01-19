# EasyConnect 启动脚本

EasyConnect 是一个可用于访问校内资源的 VPN 软件, 但该软件添加的路由表规则几乎包含了所有的地址.
这个启动脚本用于删除不需要的路由规则, 添加需要的路由规则.

目前实现了:

- Windows WSL 脚本 [start-easyconnect-wsl.sh](./start-easyconnect-wsl.sh)
- MacOS 脚本 [start-easyconnect-mac.sh](./start-easyconnect-mac.sh)
- Linux 脚本 [start-easyconnect-linux.sh](./start-easyconnect-linux.sh)

## 安装 EasyConnect

访问 <https://vpn.nju.edu.cn/> 下载相应的客户端并安装 (校园网可能无法访问).

如果使用 Ubuntu 20.04 提示 `Harfbuzz version too old`
可以尝试 [libpango/README.md](libpango/README.md) 的解决方法.

## Windows WSL

由于本人对 Windows 的 CMD 不熟悉, 暂时写了一个 WSL 脚本.
推荐使用 Ubuntu 18.04.

安装依赖关系:

```bash
sudo apt install net-tools  # 使用了route命令
```

直接运行 (先不要手动运行 EasyConnect):

```bash
./start-easyconnect-wsl.sh
```

会提示使用管理员权限运行.

如果先运行了 EasyConnect 再运行脚本会导致 `vpn.nju.edu.cn` DNS解析为一个不正确的值, 导致连接失败,
可能需要重启电脑修复不能连接的问题.

## MacOS

不要先打开 EasyConnect, 直接运行命令, 在删除路由表的时候可能会提示输入密码:

```bash
./start-easyconnect-mac.sh
```

## Ubuntu

EasyConnect 开机后会通过 systemd 启动后台服务, 但我们可以只在需要时启动, 因此可以禁用这个服务
(当然, 不禁用也可以用):

```bash
sudo systemctl stop EasyMonitor.service
sudo systemctl disable EasyMonitor.service
```

有几个程序有 setuid 权限, 但不是必要的, 可以去掉:

```bash
sudo chmod -s /usr/share/sangfor/EasyConnect/resources/bin/CSClient /usr/share/sangfor/EasyConnect/resources/bin/ECAgent
```

安装依赖关系:

```bash
sudo apt install net-tools  # 使用了route命令
```

直接运行 (操作路由表需要root权限, 会提示你输入密码):

```bash
./start-easyconnect-linux.sh
```

通过点击图标运行:
修改 `/usr/share/applications/EasyConnect.desktop` 第5行 `Exec=` 为你的 `start-easyconnect.sh` 的绝对路径:

```bash
sudo sed "s@Exec=.*@Exec=\"`realpath ./start-easyconnect-linux.sh`\"@" /usr/share/applications/EasyConnect.desktop #-i
# 上一行命令的注释去掉(加 -i)才能写入
```

如果不希望使用 EasyConnect 提供的 DNS 服务器, 可以对程序进行 patch:

```bash
cd /usr/share/sangfor/EasyConnect/resources/bin
sudo cp svpnservice svpnservice.bak
echo -e '\x39\xc0\x39\xc0' | sudo dd of=svpnservice count=4 seek=284760 oflag=seek_bytes iflag=count_bytes conv=notrunc  # 39 c0: cmp eax, eax
```

`svpnservice` 程序判断 `/etc/resolv.conf` 的修改时间有没有发生变化, 如果改变了就将内容复写掉.
上面的命令修改了程序, 让程序认为文件始终没有被修改.

## 脚本工作原理

- 启动 EasyConnect 前, 查询 `vpn.nju.edu.cn` 的 IP 地址
- 启动 EasyConnect
- 等待路由表更新
- 删除 tun0 接口的所有路由规则, 除了 `vpn.nju.edu.cn` 的 IP 地址所在子网
- 添加路由规则, 上一步除外的子网不会添加 (添加了 `vpn.nju.edu.cn` 所在子网会导致无法连接)

添加的路由规则主要来自于 EasyConnect 软件界面的默认资源组的资源地址, 整理如下:

```txt
10.254.253.0/24 36.152.24.0/24 58.192.32.0/20 58.192.48.0/21 58.193.224.0/19 58.240.127.0/27 112.25.191.64/26 114.212.0.0/16 172.0.0.0/8 180.209.0.0/20 202.119.32.0/19 202.127.247.0/24 202.38.126.160/28 202.38.2.0/23 210.28.128.0/20 210.29.240.0/20 211.162.26.0/27 211.162.81.0/25 218.94.142.0/24 219.219.112.0/20 221.6.40.128/25
```

但用起来有的网站似乎有一点问题, 我合并了一些开头相同的子网:

```txt
10.254.253.0/24 36.152.24.0/24 58.192.0.0/10 112.25.191.64/26 114.212.0.0/16 172.0.0.0/8 180.209.0.0/20 202.0.0.0/8 210.28.0.0/14 211.162.0.0/16 218.94.142.0/24 219.219.112.0/20 221.6.40.128/25
```
