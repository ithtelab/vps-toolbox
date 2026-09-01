# Linux VPS 多功能综合运维与测评工具箱 (VPS All-in-One Toolbox)

这是一个专为 Linux 服务器（VPS / 独立服务器）量身打造的**现代化、模块化、彩色交互式多功能工具箱**。支持 Debian、Ubuntu、CentOS、Rocky Linux、AlmaLinux、Alpine 与 Arch Linux。

---

## 🌟 核心功能一览

### 1. 服务器性能与网络综合测评 (Benchmark & Quality)
- **NodeQuality (NQ)** 权威全维度节点质量测试
- **TcpQuality (TQ)** 三网回程延迟、丢包率与 TCP 质量测试
- **Geekbench 5 官方跑分**：独立纯净版跑分，自动输出官方单核/多核成绩页面链接
- **IP 纯净度与流媒体/AI 解锁检测**：支持 Netflix、Disney+、YouTube Premium、ChatGPT、TikTok 等检测
- **三网回程路由追踪 (NextTrace / BestTrace)**：电信 163/CN2、联通 4837/9929、移动 CMI 实时回程路由
- **国内三网多节点测速 (Speedtest)** & **YABS 综合性能跑分** & **融合怪综合测评**

### 2. 代理与穿透/转发服务一键搭建 (Proxy & Tunneling)
- **Socks5 (SK5) 极简高性能代理搭建**：
  - 支持自定义端口、用户名/密码认证
  - 自动配置 Systemd 守护与开机自启，自动开放防火墙端口
  - 自动生成 Telegram 一键直连格式链接
- **Clash Party / Mihomo 节点服务端搭建**：一键部署 Mihomo 内核并生成配置文件
- **Realm 高性能极速端口转发**：中转加速、内网穿透
- **VLESS-Reality / Hysteria 2 前沿协议管理**

### 3. 系统底层与网络参数优化 (System & Network Optimization)
- **BBR 加速**：一键开启原生 Linux BBR 拥塞控制算法
- **虚拟内存 (Swap) 动态管理**：自定义大小（如 1G/2G/4G），预防小内存 OOM 爆满宕机
- **Linux 软件源一键换源 (LinuxMirrors)**：支持国内外各大高校与大厂极速镜像源
- **时区与时间校准**：一键切上海时区 (CST) 并执行 NTP/Chrony 网络时间同步
- **DNS 优化**：一键切换 Google / Cloudflare / 阿里 DNS

### 4. Docker 与常用运维环境部署 (Docker & Applications)
- **Docker & Docker Compose 官方最新版一键安装**（含国内镜像加速）
- **哪吒探针 (Nezha Agent / Dashboard)**
- **1Panel 现代化开源运维面板**
- **Acme.sh 免费 SSL 证书一键申请**（HTTP-01 自动化申请）
- **LibreSpeed 自建网页测速节点**

### 5. VPS 安全加固与防火墙管理 (Security & Hardening)
- **修改 SSH 默认远程连接端口**（防全网 22 端口批量扫描爆破）
- **SSH 密钥免密登录配置** & **一键禁用 Root 密码暴力破解**
- **Fail2ban 自动防御**（多次输错密码自动封禁 IP 24 小时）
- **防火墙端口管理**（支持 UFW / Firewalld / iptables 智能适配）

### 6. 系统深度清理与日常监控 (Maintenance & Monitoring)
- **系统深度垃圾清理**（自动清理旧内核、APT/YUM 缓存、历史日志与临时文件）
- **服务器硬件与系统信息速览**（CPU 架构、内存占用、Swap、磁盘、虚拟化架构、公网 IP、开机时长）
- **实时系统与网络流量监控**（htop / iftop）

---

## 🚀 使用方法

### 本地直接运行
在当前服务器脚本目录下执行：
```bash
chmod +x main.sh
./main.sh
```

### 远程一键调用（部署到 GitHub / Gitee 后）
只需要把仓库推送到远程平台，即可支持一条命令直接唤出工具箱：
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/你的用户名/你的仓库名/main/main.sh)
```
或使用国内/加速节点：
```bash
bash <(curl -fsSL https://ghproxy.com/https://raw.githubusercontent.com/你的用户名/你的仓库名/main/main.sh)
```

---

## 📁 项目目录结构

```
├── main.sh                 # 主入口脚本（负责环境检测、主菜单交互、子模块路由）
├── README.md               # 项目使用说明文档
├── utils/                  # 工具库
│   ├── colors.sh           # 终端彩色输出、Banner 格式化
│   ├── sys_detect.sh       # 系统与硬件信息识别（OS/CPU/架构/内存/虚拟化）
│   └── helper.sh           # 基础运维依赖检测、防火墙端口放行函数
└── modules/                # 业务子模块
    ├── bench.sh            # 测评模块 (NQ, TQ, Geekbench 5, 流媒体, 路由, 测速)
    ├── proxy.sh            # 代理模块 (Socks5, Clash/Mihomo, Realm 转发)
    ├── system.sh           # 系统优化 (BBR, Swap, 换源, 时区, DNS)
    ├── docker.sh           # 容器与应用部署 (Docker, 探针, 面板, SSL)
    ├── security.sh         # 安全加固 (SSH 改端口, 密钥登录, 防火墙, Fail2ban)
    └── clean.sh            # 系统清理与运维监控
```
