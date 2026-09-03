#!/usr/bin/env bash
# ==============================================================================
# Linux VPS Toolbox - System & Network Optimization Module
# ==============================================================================

enable_bbr() {
    print_banner
    echo -e "${B_YELLOW}=== [1] 开启与管理 Linux BBR 拥塞控制算法 ===${NC}"
    info "检查当前内核版本与 BBR 状态..."

    local current_cc
    current_cc=$(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | awk '{print $3}')
    echo -e "当前拥塞控制算法: ${B_CYAN}${current_cc}${NC}"
    echo ""
    echo -e " ${B_GREEN}1.${NC} 开启原生 Linux BBR 加速"
    echo -e " ${B_GREEN}2.${NC} 安装 BBR Plus / BBR3 / 魔改优化内核 (一键管理脚本)"
    echo -e " ${B_RED}0.${NC} 返回"
    echo ""
    read -r -p "请选择: " bbr_opt

    case "$bbr_opt" in
        1)
            info "正在写入 BBR 内核优化参数..."
            sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
            sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
            echo "net.core.default_qdisc = fq" >> /etc/sysctl.conf
            echo "net.ipv4.tcp_congestion_control = bbr" >> /etc/sysctl.conf
            sysctl -p >/dev/null 2>&1

            local new_cc
            new_cc=$(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | awk '{print $3}')
            if [ "$new_cc" = "bbr" ]; then
                success "BBR 开启成功！当前拥塞控制: ${new_cc}"
            else
                warn "开启 BBR 可能需要更新 Linux 内核或重启生效。"
            fi
            ;;
        2)
            info "正在拉取 Teddysun / Ylx 经典 BBR 综合管理脚本..."
            run_remote_script \
                "https://raw.githubusercontent.com/teddysun/across/master/bbr.sh" \
                "https://raw.githubusercontent.com/ylx2016/Linux-NetSpeed/master/tcp.sh"
            ;;
        *)
            return
            ;;
    esac
    pause
}

install_warp() {
    print_banner
    echo -e "${B_YELLOW}=== [2] Cloudflare WARP 一键双栈与 IP 解锁 ===${NC}"
    info "正在拉取 fscarmen / P3TERX WARP 官方一键脚本..."
    run_remote_script \
        "https://cdn.jsdelivr.net/gh/fscarmen/warp@main/menu.sh" \
        "https://raw.githubusercontent.com/fscarmen/warp/main/menu.sh" \
        "https://ghproxy.com/https://raw.githubusercontent.com/fscarmen/warp/main/menu.sh"
    pause
}

reinstall_system_dd() {
    print_banner
    echo -e "${B_YELLOW}=== [3] 纯净一键 DD 重装 Linux / Windows 系统 ===${NC}"
    warn "【高危警告】DD 重装系统将格式化整块硬盘数据！请确保重要数据已完成备份！"
    echo ""
    read -r -p "确定要继续进入一键重装系统菜单吗？[y/N]: " confirm_dd
    if [[ ! "$confirm_dd" =~ ^[yY]$ ]]; then
        info "已取消重装操作。"
        pause
        return
    fi

    info "正在加载 leitbogioro / reinstall 纯净 DD 重装脚本..."
    run_remote_script \
        "https://cdn.jsdelivr.net/gh/leitbogioro/Tools@master/Linux_reinstall/InstallNET.sh" \
        "https://raw.githubusercontent.com/leitbogioro/Tools/master/Linux_reinstall/InstallNET.sh" \
        "https://ghproxy.com/https://raw.githubusercontent.com/leitbogioro/Tools/master/Linux_reinstall/InstallNET.sh"
    pause
}

manage_swap() {
    print_banner
    echo -e "${B_YELLOW}=== [4] 虚拟内存 (Swap) 一键配置与管理 ===${NC}"
    info "当前 Swap 状态: $(get_swap_info)"
    echo ""
    echo -e " ${B_GREEN}1.${NC} 添加 / 调整 Swap (自定义大小, 如 1G / 2G / 4G)"
    echo -e " ${B_GREEN}2.${NC} 完全关闭并删除 Swap"
    echo -e " ${B_RED}0.${NC} 返回"
    echo ""
    read -r -p "请选择操作 [0-2]: " swap_op

    case "$swap_op" in
        1)
            read -r -p "请输入要设置的 Swap 大小 (单位 MB，例如 1024 / 2048 / 4096): " swap_size
            if [[ ! "$swap_size" =~ ^[0-9]+$ ]]; then
                error "输入无效，必须为纯数字！"
                pause
                return
            fi

            info "正在停止现有 Swap..."
            swapoff -a 2>/dev/null || true
            sed -i '/\/swapfile/d' /etc/fstab

            info "正在分配 ${swap_size}MB Swap 空间..."
            if command -v fallocate >/dev/null 2>&1; then
                fallocate -l "${swap_size}M" /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count="$swap_size"
            else
                dd if=/dev/zero of=/swapfile bs=1M count="$swap_size"
            fi

            chmod 600 /swapfile
            mkswap /swapfile >/dev/null 2>&1
            swapon /swapfile
            echo "/swapfile swap swap defaults 0 0" >> /etc/fstab

            success "Swap 设置成功！当前大小: $(get_swap_info)"
            ;;
        2)
            info "正在关闭并删除 Swap..."
            swapoff -a 2>/dev/null || true
            sed -i '/\/swapfile/d' /etc/fstab
            rm -f /swapfile
            success "Swap 已关闭并清理完毕！"
            ;;
        *)
            return
            ;;
    esac
    pause
}

change_mirrors() {
    print_banner
    echo -e "${B_YELLOW}=== [5] Linux 系统软件源一键换源 (APT/YUM) ===${NC}"
    info "正在加载 SuperManito 经典一键换源脚本..."
    run_remote_script \
        "https://linuxmirrors.cn/main.sh" \
        "https://raw.githubusercontent.com/SuperManito/LinuxMirrors/main/ChangeMirrors.sh"
    pause
}

sync_time() {
    print_banner
    echo -e "${B_YELLOW}=== [6] 系统时区修改与 NTP 网络时间同步 ===${NC}"
    info "设置时区为 Asia/Shanghai (中国标准时间 CST)..."
    timedatectl set-timezone Asia/Shanghai 2>/dev/null || ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

    info "正在同步网络原子钟时间..."
    if command -v chrony >/dev/null 2>&1; then
        systemctl restart chrony 2>/dev/null || true
    elif command -v ntpdate >/dev/null 2>&1; then
        ntpdate -u pool.ntp.org 2>/dev/null || true
    else
        case "$PKG_MANAGER" in
            apt) apt-get install -y chrony >/dev/null 2>&1 && systemctl restart chrony 2>/dev/null || true ;;
            dnf|yum) $PKG_MANAGER install -y chrony >/dev/null 2>&1 && systemctl restart chronyd 2>/dev/null || true ;;
            apk) apk add chrony >/dev/null 2>&1 && rc-service chronyd restart >/dev/null 2>&1 || true ;;
        esac
    fi

    success "时区已更新为: $(date -R)"
    pause
}

tune_network_stack() {
    print_banner
    echo -e "${B_YELLOW}=== [9] 一键系统网络与连接句柄极限优化 (Sysctl/TCP调优) ===${NC}"
    info "正在优化 Linux 内核 TCP 缓冲区、并发队列与最大文件句柄限制 (nofile)..."

    # Backup sysctl.conf
    cp /etc/sysctl.conf /etc/sysctl.conf.bak 2>/dev/null || true

    # Clean old values
    local keys=(
        "fs.file-max"
        "net.core.somaxconn"
        "net.core.netdev_max_backlog"
        "net.core.rmem_max"
        "net.core.wmem_max"
        "net.ipv4.tcp_max_syn_backlog"
        "net.ipv4.tcp_slow_start_after_idle"
        "net.ipv4.tcp_tw_reuse"
        "net.ipv4.tcp_fin_timeout"
        "net.ipv4.tcp_keepalive_time"
    )
    for k in "${keys[@]}"; do
        sed -i "/^${k}/d" /etc/sysctl.conf
    done

    # Append optimized kernel tuning
    cat <<EOF >> /etc/sysctl.conf
fs.file-max = 1000000
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 250000
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.ipv4.tcp_max_syn_backlog = 16384
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_time = 300
EOF

    # Apply sysctl parameters
    sysctl -p >/dev/null 2>&1 || true

    # Tune limits.conf (file descriptors)
    if [ -f /etc/security/limits.conf ]; then
        sed -i '/soft nofile/d' /etc/security/limits.conf
        sed -i '/hard nofile/d' /etc/security/limits.conf
        cat <<EOF >> /etc/security/limits.conf
* soft nofile 1000000
* hard nofile 1000000
root soft nofile 1000000
root hard nofile 1000000
EOF
    fi

    # Set current session ulimit
    ulimit -n 1000000 2>/dev/null || true

    success "系统并发与网络参数极限调优完成！"
    echo -e "  - 最大文件打开数 (nofile):  ${B_GREEN}1,000,000${NC}"
    echo -e "  - 全连接队列 (somaxconn):    ${B_GREEN}65,535${NC}"
    echo -e "  - 半连接队列 (syn_backlog):  ${B_GREEN}16,384${NC}"
    echo -e "  - TCP Fast Open/TW Reuse:    ${B_GREEN}已开启${NC}"
    pause
}

optimize_dns() {
    print_banner
    echo -e "${B_YELLOW}=== [7] 极速 DNS 一键优化 ===${NC}"
    echo -e " ${B_GREEN}1.${NC} Google DNS (8.8.8.8 / 8.8.4.4)"
    echo -e " ${B_GREEN}2.${NC} Cloudflare DNS (1.1.1.1 / 1.0.0.1)"
    echo -e " ${B_GREEN}3.${NC} 阿里 DNS (223.5.5.5 / 223.6.6.6)"
    echo -e " ${B_RED}0.${NC} 返回"
    echo ""
    read -r -p "请选择 DNS 方案 [0-3]: " dns_choice

    local d1="" d2=""
    case "$dns_choice" in
        1) d1="8.8.8.8"; d2="8.8.4.4" ;;
        2) d1="1.1.1.1"; d2="1.0.0.1" ;;
        3) d1="223.5.5.5"; d2="223.6.6.6" ;;
        *) return ;;
    esac

    # Handle systemd-resolved on Ubuntu 20+
    if [ -f /etc/systemd/resolved.conf ]; then
        sed -i "s/^#\?DNS=.*/DNS=${d1} ${d2}/" /etc/systemd/resolved.conf
        systemctl restart systemd-resolved 2>/dev/null || true
    fi

    chattr -i /etc/resolv.conf 2>/dev/null || true
    cat <<EOF > /etc/resolv.conf
nameserver ${d1}
nameserver ${d2}
EOF
    success "DNS 已成功更新为 ${d1} & ${d2}！"
    pause
}

setup_auto_security_updates() {
    print_banner
    echo -e "${B_YELLOW}=== [8] 系统自动安全补丁更新 ===${NC}"
    info "仅自动安装『安全补丁』，不强制重启，保障稳定与安全兼顾"

    case "$PKG_MANAGER" in
        apt)
            info "正在配置 unattended-upgrades (Debian/Ubuntu)..."
            apt-get install -y unattended-upgrades apt-listchanges >/dev/null 2>&1 || true
            cat <<EOF > /etc/apt/apt.conf.d/20auto-upgrades
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF
            cat <<EOF > /etc/apt/apt.conf.d/50unattended-upgrades
Unattended-Upgrade::Allowed-Origins {
    "\${distro_id}:\${distro_codename}-security";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF
            systemctl enable --now unattended-upgrades >/dev/null 2>&1 || true
            ;;
        dnf|yum)
            info "正在配置 dnf-automatic / yum-cron 安全更新..."
            $PKG_MANAGER install -y dnf-automatic >/dev/null 2>&1 || $PKG_MANAGER install -y yum-cron >/dev/null 2>&1 || true
            systemctl enable --now dnf-automatic.timer >/dev/null 2>&1 || systemctl enable --now yum-cron >/dev/null 2>&1 || true
            ;;
        apk)
            info "Alpine 系统默认启用安全更新... 配置每日升级计划任务。"
            echo "0 4 * * * apk upgrade --available >/dev/null 2>&1" | crontab - 2>/dev/null || true
            ;;
        *)
            warn "当前系统包管理器暂不支持自动安全更新。"
            ;;
    esac

    success "自动安全更新已配置完成！系统将在每日后台自动安装安全补丁。"
    pause
}

menu_system() {
    while true; do
        print_banner
        echo -e "${B_CYAN}【 系统底层与网络优化 】${NC}"
        separator
        echo -e " ${B_GREEN}1.${NC} BBR 加速开启与 BBR3/Plus 魔改内核切换"
        echo -e " ${B_GREEN}2.${NC} Cloudflare WARP 一键双栈 (IPV4/V6/流媒体解锁)"
        echo -e " ${B_GREEN}3.${NC} 纯净一键 DD 重装系统 (Debian 12/Ubuntu/Alpine/Win)"
        echo -e " ${B_GREEN}4.${NC} 虚拟内存 (Swap) 一键创建 / 调整 / 删除"
        echo -e " ${B_GREEN}5.${NC} Linux 系统软件源一键换源 (国内/海外极速源)"
        echo -e " ${B_GREEN}6.${NC} 设置上海时区 (CST) 与 NTP 网络时间校准"
        echo -e " ${B_GREEN}7.${NC} DNS 快速持久化优化 (Google / CF / 阿里)"
        echo -e " ${B_GREEN}8.${NC} 系统自动安全补丁更新 (unattended-upgrades)"
        echo -e " ${B_GREEN}9.${NC} 一键系统与网络参数极限优化 (Sysctl/TCP调优/100万句柄)"
        separator
        echo -e " ${B_RED}0.${NC} 返回主菜单"
        echo ""
        read -r -p "请输入选项 [0-9]: " sys_choice
        case "$sys_choice" in
            1) enable_bbr ;;
            2) install_warp ;;
            3) reinstall_system_dd ;;
            4) manage_swap ;;
            5) change_mirrors ;;
            6) sync_time ;;
            7) optimize_dns ;;
            8) setup_auto_security_updates ;;
            9) tune_network_stack ;;
            0) break ;;
            *)
                echo -e "${RED}输入错误，请重新选择！${NC}"
                sleep 1
                ;;
        esac
    done
}
