# Linux 多功能服务器综合工具箱 (VPS Toolbox) 架构与实施方案

本方案旨在打造一个类似业界经典（如融合怪/科技Lion/VPS-Toolbox）的高颜值、模块化、轻量且强大的 Linux 服务器多功能运维与测评工具箱。用户只需一行命令即可在任何主流 Linux 发行版（Debian / Ubuntu / CentOS / Rocky / Alma / Alpine / Arch）上一键呼出彩色交互式终端菜单。

---

## 一、 推荐功能规划与分类架构

根据您的需求，在保留 **NodeQuality (NQ)**、**TcpQuality (TQ)**、**Geekbench 5 官方跑分**、**Socks5 (SK5) 搭建**、**Clash Party / 节点搭建** 的基础上，扩展如下常用且刚需的运维与实用功能：

```
┌──────────────────────────────────────────────────────────────┐
│                  Linux VPS 多功能一体化工具箱                 │
├──────────────────────────────────────────────────────────────┤
│  [1] 服务器性能与网络综合测评 (Benchmark & Quality)          │
│  [2] 代理与穿透/转发服务一键搭建 (Proxy & Tunneling)          │
│  [3] 系统底层与网络优化 (System & Network Optimization)      │
│  [4] Docker 与常用运维环境 (Docker & Application Stacks)     │
│  [5] VPS 安全加固与防火墙管理 (Security & Firewall)          │
│  [6] 系统清理与日常运维监控 (Maintenance & Monitoring)        │
│  ──────────────────────────────────────────────────────────  │
│  [u] 更新脚本自身    [0] 退出脚本                            │
└──────────────────────────────────────────────────────────────┘
```

### 分类功能详细清单

#### 1. 服务器性能与网络综合测评 (测评中心)
- **NodeQuality (NQ) 测速测评**：调用/集成权威节点质量测评脚本。
- **TcpQuality (TQ) 质量测试**：三网 TCP 回程质量、丢包率与延迟测评。
- **Geekbench 5 官方 CPU 跑分**：独立拉取 Geekbench 5 官方 Linux 二进制包，执行纯净 CPU 单核/多核跑分并输出官方网页链接。
- **IP 质量与流媒体解锁检测**：一键检测 IP 欺诈度/纯净度（Scamalytics / IPinfo）、Netflix / Disney+ / YouTube Premium / ChatGPT / TikTok 解锁情况。
- **三网回程路由追踪**：集成 NextTrace / BestTrace，一键查看电信 163/CN2、联通 4837/9929、移动 CMI 真实回程路由。
- **全球/国内节点 Speedtest**：一键进行国内三网各大节点与全球主流大厂多线程/单线程测速。
- **融合怪综合测评 (YABS / 融合怪)**：提供一键调用最全跑分脚本快捷入口。

#### 2. 代理与网络服务搭建 (网络服务)
- **Socks5 (SK5) 极简一键搭建**：
  - 支持自定义端口、用户名和密码验证。
  - 基于轻量高性能内核（如 Dante / Microsocks / GOST / Xray 内核），开机自启并配置守护进程。
  - 自动输出直接连接信息与各种客户端配置。
- **Clash Party / Mihomo 节点与服务端搭建**：
  - 一键部署轻量级 Mihomo/Clash 服务端或节点导出工具。
  - 自动生成通用 YAML 配置、订阅链接或 URI 分享链接。
- **主流前沿协议一键搭建（可选扩展）**：
  - VLESS-Reality / Hysteria 2 / Tuic / Shadowsocks 2022（基于官方/稳定成熟自动化脚本或容器）。
- **端口转发与隧道工具**：
  - 一键部署 Realm / GOST / Iptables 端口转发，轻松实现中转加速与内网穿透。

#### 3. 系统底层与网络优化 (系统优化)
- **BBR / BBR Plus / BBR3 原生内核与加速**：自动检测内核并一键开启 Linux 原生 BBR 或安装最新优化内核。
- **虚拟内存 Swap 一键设置**：一键创建/修改/删除虚拟内存（支持输入自定义大小，如 1G/2G/4G），预防低内存 OOM。
- **系统镜像源一键切换**：自动检测系统，一键切换为官方源、阿里云、清华大学、腾讯云等国内/海外极速镜像源。
- **系统时间与时区校准**：一键设置上海时区（CST）或 UTC，并执行 NTP/Chrony 网络时间同步。
- **DNS 一键优化**：切换为 Google (8.8.8.8)、Cloudflare (1.1.1.1)、阿里 DNS 等。

#### 4. Docker 与常用服务一键部署 (应用部署)
- **Docker & Docker Compose 官方最新版一键安装**：包含国内加速镜像配置。
- **哪吒探针 (Nezha Agent & Dashboard)** 一键安装与配置。
- **1Panel / 宝塔 Linux 面板** 官方一键安装入口。
- **Acme.sh 免费 SSL 证书一键申请**（支持 Standalone / DNS API 自动续期）。
- **自建 Speedtest 测速网页 (LibreSpeed)** 一键部署。

#### 5. VPS 安全加固与防火墙 (安全管理)
- **SSH 端口修改**：防止 22 端口被全网批量爆破。
- **SSH 密钥登录一键配置**：一键添加公钥、禁用 Root 密码暴力破解登录。
- **Fail2ban 防爆破自动拦截**：自动封禁恶意尝试 SSH 密码的 IP。
- **简易防火墙端口放行 (UFW / Iptables)**：快速查看开放端口、放行 TCP/UDP 端口或屏蔽恶意 IP。

#### 6. 日常运维与系统清理 (工具箱)
- **系统深度垃圾清理**：自动清理 APT/YUM 缓存、旧内核、日志轮转（Systemd Journal）与临时文件。
- **实时网络流量与资源监控**：一键启动 htop, iftop, vnstat, bmon。
- **服务器硬件与系统信息速览**：CPU 型号、核心数、架构、内存、磁盘占用、开机时长、虚拟化类型（KVM/Xen/OpenVZ/LXC）快速展示。

---

## 二、 代码目录与工程结构设计

为了让脚本易于维护、方便后续随时扩展新功能，建议采用 **模块化解耦设计**，而非把上万行代码堆在一个单文件中：

```
server-toolbox/
├── main.sh                 # 主入口脚本（负责环境检测、主菜单渲染、子模块路由）
├── README.md               # 项目说明与一键运行命令
├── utils/                  # 公共工具库
│   ├── colors.sh           # 彩色输出、Banner 头、格式化打印
│   ├── sys_detect.sh       # 操作系统识别 (Debian/Ubuntu/CentOS/RHEL/Alpine/Arch/ARM/x86_64)
│   └── helper.sh           # 基础依赖自动安装 (curl, wget, jq, sudo, cron)
└── modules/                # 功能模块目录
    ├── bench.sh            # 测评模块 (NQ, TQ, Geekbench 5, 流媒体解锁, 路由, 测速)
    ├── proxy.sh            # 代理模块 (Socks5, Clash Party/Mihomo, Realm 转发)
    ├── system.sh           # 系统优化 (BBR, Swap, 换源, 时区, DNS)
    ├── docker.sh           # 容器与应用部署 (Docker, 探针, 面板, SSL)
    ├── security.sh         # 安全加固 (SSH 改端口, 密钥登录, 防火墙, Fail2ban)
    └── clean.sh            # 系统清理与运维监控
```

> **在线单命令运行支持**：
> 打包或通过 GitHub / Gitee / CDN 提供一键运行命令：
> `bash <(curl -fsSL https://raw.githubusercontent.com/your-name/toolbox/main/main.sh)`

---

## 三、 实施步骤

1. **第一阶段：搭建项目骨架与交互框架**
   - 编写 `utils/colors.sh` 与 `utils/sys_detect.sh`，实现色彩丰富、排版工整的 CLI 界面和系统架构自适应。
   - 编写 `main.sh`，实现清晰的数字键盘交互逻辑、返回上级菜单和退出保护。

2. **第二阶段：实现核心测评模块 (`modules/bench.sh`)**
   - 编写 Geekbench 5 自动下载、解压、后台运行、抓取跑分 URL 的独立纯净脚本。
   - 对接 NodeQuality (NQ) 与 TcpQuality (TQ) 的最新官方执行入口。
   - 集成 IP 质量检测与 NextTrace 路由追踪。

3. **第三阶段：实现代理与转发模块 (`modules/proxy.sh`)**
   - 实现 Socks5 一键安装脚本（自动生成配置、Systemd 守护服务、自动放行端口、输出连接格式）。
   - 实现 Clash Party / 节点配置工具与 Realm 端口转发一键管理。

4. **第四阶段：完善系统优化、安全加固与清理工具 (`modules/system.sh` / `security.sh` / `clean.sh`)**
   - 编写 BBR 开启、Swap 自动调整、SSH 端口修改、系统垃圾清理等实用子功能。

5. **第五阶段：自测与多系统兼容性验证**
   - 在 Debian 11/12, Ubuntu 22.04/24.04, CentOS Stream / AlmaLinux 等环境下测试脚本语法与菜单交互。
   - 输出完整的 README 使用文档与一键调用指令。
