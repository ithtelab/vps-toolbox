#!/usr/bin/env bash
# ==============================================================================
# Linux VPS Toolbox - System & Network Optimization Module
# ==============================================================================

enable_bbr() {
    print_banner
    echo -e "${B_YELLOW}=== [1] 开启 Linux 原生 BBR 拥塞控制算法 ===${NC}"
    info "检查当前内核版本与 BBR 状态..."

    local current_cc
    current_cc=$(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | awk '{print $3}')
    echo -e "当前拥塞控制算法: ${B_CYAN}${current_cc}${NC}"

    if [ "$current_cc" = "bbr" ]; then
        success "BBR 已经在运行中，无需重复开启！"
    else
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
    fi
    pause
}

manage_swap() {
    print_banner
    echo -e "${B_YELLOW}=== [2] 虚拟内存 (Swap) 一键配置与管理 ===${NC}"
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
    echo -e "${B_YELLOW}=== [3] Linux 系统软件源一键换源 (APT/YUM) ===${NC}"
    info "正在加载 SuperManito 经典一键换源脚本..."
    bash <(curl -sSL https://linuxmirrors.cn/main.sh)
    pause
}

sync_time() {
    print_banner
    echo -e "${B_YELLOW}=== [4] 系统时区修改与 NTP 网络时间同步 ===${NC}"
    info "设置时区为 Asia/Shanghai (中国标准时间 CST)..."
    timedatectl set-timezone Asia/Shanghai 2>/dev/null || ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

    if command -v chrony >/dev/null 2>&1; then
        systemctl restart chrony 2>/dev/null || true
    elif command -v ntpdate >/dev/null 2>&1; then
        ntpdate -u pool.ntp.org 2>/dev/null || true
    fi

    success "时区已更新为: $(date -R)"
    pause
}

optimize_dns() {
    print_banner
    echo -e "${B_YELLOW}=== [5] 极速 DNS 一键优化 ===${NC}"
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

    chattr -i /etc/resolv.conf 2>/dev/null || true
    cat <<EOF > /etc/resolv.conf
nameserver ${d1}
nameserver ${d2}
EOF
    success "DNS 已成功更新为 ${d1} & ${d2}！"
    pause
}

menu_system() {
    while true; do
        print_banner
        echo -e "${B_CYAN}【 系统底层与网络优化 】${NC}"
        separator
        echo -e " ${B_GREEN}1.${NC} 开启 Linux 原生 BBR 拥塞控制加速"
        echo -e " ${B_GREEN}2.${NC} 虚拟内存 (Swap) 一键创建 / 调整 / 删除"
        echo -e " ${B_GREEN}3.${NC} Linux 系统软件源一键换源 (国内/海外极速源)"
        echo -e " ${B_GREEN}4.${NC} 设置上海时区 (CST) 与 NTP 网络时间校准"
        echo -e " ${B_GREEN}5.${NC} DNS 快速优化 (Google / CF / 阿里)"
        separator
        echo -e " ${B_RED}0.${NC} 返回主菜单"
        echo ""
        read -r -p "请输入选项 [0-5]: " sys_choice
        case "$sys_choice" in
            1) enable_bbr ;;
            2) manage_swap ;;
            3) change_mirrors ;;
            4) sync_time ;;
            5) optimize_dns ;;
            0) break ;;
            *)
                echo -e "${RED}输入错误，请重新选择！${NC}"
                sleep 1
                ;;
        esac
    done
}
