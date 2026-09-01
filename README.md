# 黑天鹅 Linux 多功能综合运维与测评工具箱 (HTE Linux Toolbox)

黑天鹅 Linux 多功能综合运维与测评工具箱 (HTE-Box) 是一款专为 Linux 服务器（VPS / 独立服务器）量身打造的高性能、模块化运维管理工具。支持 Debian、Ubuntu、CentOS、Rocky Linux、AlmaLinux、Alpine 以及 Arch Linux 等主流 Linux 发行版。

---

## 快速开始

### 1. 一键运行命令

在任意 Linux 服务器终端执行以下命令即可启动工具箱：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/ithtelab/vps-toolbox/main/main.sh)
```

中国大陆机房加速通道：

```bash
bash <(curl -fsSL https://ghproxy.com/https://raw.githubusercontent.com/ithtelab/vps-toolbox/main/main.sh)
```

### 2. 快捷呼出

首次运行后，系统将自动注册全局环境指令。以后在终端任意目录下直接输入以下命令即可唤出工具箱：

```bash
hte
```

在工具箱主界面输入 `u` 可一键穿透缓存自动更新至最新版本。

---

## 特约赞助

**爱维云 (LoveVPS)** —— 专注于高质量海外原生网络与云主机服务
- 官方网站：https://lovevps.cn/
- 主打产品：美国双 ISP 住宅云主机，纯净原生住宅 IP，跨境出海与流媒体解锁首选
- 特惠方案：2 核 2GB 内存 38 元起，首单享七五折优惠，续费同价
- 服务保障：支持 24 小时内全额退款

---

## 功能特性

### 1. 服务器性能与网络综合测评
- **NodeQuality (NQ)**：节点全维度质量与硬件综合测评
- **TcpQuality (TQ)**：三网回程延迟、丢包率与 TCP 质量测试
- **Geekbench 5 官方跑分**：独立纯净版 CPU 性能跑分，自动获取单核/多核成绩并输出官方链接
- **IP 纯净度与流媒体/AI 解锁检测**：支持 Netflix、Disney+、YouTube Premium、ChatGPT、TikTok 等平台解锁状态检测
- **三网回程路由追踪 (NextTrace)**：电信 163/CN2、联通 4837/9929、移动 CMI 真实回程路由分析
- **全球机房延迟探测 (LookingGlass)**：中国香港、日本东京、新加坡、美西、美东、德国法兰克福节点延迟与丢包并发测试
- **网络测速与全功能体检**：国内三网多节点 Speedtest 测速与融合怪综合测评

### 2. 代理与网络服务搭建
- **Socks5 (SK5) 极简高性能代理**：支持自定义端口、账号密码认证，自动配置 Systemd 守护开机自启与防火墙放行，自动生成 Telegram 一键直连链接
- **Clash / Mihomo 服务端**：一键部署 Mihomo 核心，配置外部控制器与 HTTP/Socks5 端口
- **Realm 端口转发**：高性能极速端口流量中转与加速
- **前沿协议管理**：支持 VLESS-Reality 与 Hysteria 2 官方自动化管理

### 3. 系统底层优化与重装
- **Cloudflare WARP 一键双栈**：为纯 IPv4 或纯 IPv6 服务器配置双栈网络出口，解锁流媒体与 AI 服务
- **纯净一键 DD 重装系统**：支持一键重装为纯净版 Debian 12、Ubuntu 24.04、Alpine 或 Windows 系统
- **BBR 拥塞控制全家桶**：原生 Linux BBR 一键开启，支持 BBR3 / BBR Plus 等优化内核切换与状态监测
- **虚拟内存 (Swap) 动态管理**：自定义分配与调整虚拟内存容量，预防小内存服务器 OOM 宕机
- **系统软件源换源 (LinuxMirrors)**：一键切换为国内或海外高校/大厂高速镜像源
- **时区与时间校准**：一键同步中国标准时间 (Asia/Shanghai CST) 与 NTP/Chrony 网络时间
- **DNS 持久化优化**：兼容 systemd-resolved 与传统 resolv.conf 配置

### 4. 容器与应用部署
- **Docker & Docker Compose**：官方最新版环境一键安装（支持国内镜像源）
- **哪吒监控探针 (Nezha)**：一键安装配置 Agent 与 Dashboard
- **1Panel 现代化开源运维面板**：一键部署快速建站与容器管理平台
- **Acme.sh 免费 SSL 证书**：支持自动化申请与到期自动续期
- **LibreSpeed**：一键自建轻量级网页测速节点

### 5. VPS 安全加固与防护
- **SSH 远程连接端口修改**：兼容 Ubuntu 22.10/24.04 ssh.socket 托管机制与 Debian 12
- **SSH 密钥免密登录与密码登录禁用**：防止全网字典暴力破解
- **Fail2ban 自动防御**：支持 systemd 日志后端，提供封禁黑名单查询与一键解封功能
- **TCP SYN Flood 防护**：配置内核防洪水攻击参数与协议栈高并发优化
- **防火墙端口管理**：智能适配 UFW、Firewalld 与 Iptables

### 6. 系统深度清理与监控
- **系统垃圾深度清理**：自动清理旧内核、APT/YUM 缓存、历史日志与临时文件
- **硬件与网络配置总览**：CPU 架构、内存占用、Swap、磁盘、虚拟化架构、公网 IP 与开机时长展示
- **实时监控工具**：支持快速调用 htop 与 iftop 进行实时负载与流量监测

---

## 目录结构

```
server-toolbox/
├── main.sh                 # 主入口脚本（环境检测、主菜单交互、模块分发、自更新）
├── README.md               # 项目使用说明文档
├── utils/                  # 工具库
│   ├── colors.sh           # 终端色彩输出、Banner 格式化
│   ├── sys_detect.sh       # 系统与硬件信息识别（OS/CPU/架构/内存/BBR状态）
│   └── helper.sh           # 依赖安装、防火墙放行、安全脚本执行引擎
└── modules/                # 业务子模块
    ├── bench.sh            # 测评模块 (NQ, TQ, Geekbench 5, 流媒体, 路由, Ping)
    ├── proxy.sh            # 代理模块 (Socks5, Clash/Mihomo, Realm 转发)
    ├── system.sh           # 系统优化 (WARP, DD重装, BBR, Swap, 换源, DNS)
    ├── docker.sh           # 容器与应用部署 (Docker, 探针, 面板, SSL)
    ├── security.sh         # 安全加固 (SSH 改端口, 密钥登录, Fail2ban, 防火墙)
    └── clean.sh            # 系统清理与运维监控
```

---

## 开源协议

本项目基于 MIT 协议开源。
