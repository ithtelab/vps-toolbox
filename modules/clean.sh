#!/usr/bin/env bash
# ==============================================================================
# Linux VPS Toolbox - System Clean & Monitoring Module
# ==============================================================================

deep_clean_system() {
    print_banner
    echo -e "${B_YELLOW}=== [1] Linux 系统深度垃圾与日志清理 ===${NC}"
    info "正在清理系统缓存、旧内核与无用依赖..."

    case "$PKG_MANAGER" in
        apt)
            apt-get autoremove --purge -y >/dev/null 2>&1
            apt-get clean -y >/dev/null 2>&1
            apt-get autoclean -y >/dev/null 2>&1
            ;;
        dnf|yum)
            $PKG_MANAGER autoremove -y >/dev/null 2>&1
            $PKG_MANAGER clean all >/dev/null 2>&1
            ;;
        apk)
            apk cache clean >/dev/null 2>&1
            ;;
    esac

    info "清理 Systemd 历史 Journal 日志 (保留最近 3 天)..."
    if command -v journalctl >/dev/null 2>&1; then
        journalctl --vacuum-time=3d >/dev/null 2>&1
    fi

    info "清理 /tmp 与 /var/tmp 临时文件..."
    rm -rf /tmp/* /var/tmp/* 2>/dev/null || true

    success "系统深度清理完成！当前磁盘占用:"
    get_disk_info
    pause
}

show_system_specs() {
    print_banner
    echo -e "${B_YELLOW}=== [2] 服务器详细硬件与系统信息 ===${NC}"
    separator
    echo -e " ${B_GREEN}操作系统 (OS):${NC}       ${OS_NAME} ${OS_VERSION} (${OS_TYPE})"
    echo -e " ${B_GREEN}系统内核 (Kernel):${NC}   $(uname -r)"
    echo -e " ${B_GREEN}CPU 型号及架构:${NC}      $(get_cpu_info)"
    echo -e " ${B_GREEN}物理内存占用:${NC}        $(get_mem_info)"
    echo -e " ${B_GREEN}虚拟内存 (Swap):${NC}     $(get_swap_info)"
    echo -e " ${B_GREEN}系统盘使用率:${NC}        $(get_disk_info)"
    echo -e " ${B_GREEN}虚拟化架构 (Virt):${NC}   $(get_virt_type)"
    echo -e " ${B_GREEN}公网 IPv4 地址:${NC}      $(get_ip_info)"
    echo -e " ${B_GREEN}系统开机时长:${NC}        $(uptime -p 2>/dev/null || uptime | awk -F, '{print $1}')"
    separator
    pause
}

launch_realtime_monitor() {
    print_banner
    echo -e "${B_YELLOW}=== [3] 实时系统与网络流量监控 ===${NC}"
    echo -e " ${B_GREEN}1.${NC} 启动 htop (交互式进程与资源查看)"
    echo -e " ${B_GREEN}2.${NC} 启动 iftop (实时网络带宽与连接追踪)"
    echo -e " ${B_RED}0.${NC} 返回"
    echo ""
    read -r -p "请选择监控工具 [0-2]: " mon_choice

    case "$mon_choice" in
        1)
            if ! command -v htop >/dev/null 2>&1; then
                info "正在安装 htop ..."
                [ "$PKG_MANAGER" = "apt" ] && apt-get install -y htop >/dev/null 2>&1
                [ "$PKG_MANAGER" = "yum" ] || [ "$PKG_MANAGER" = "dnf" ] && $PKG_MANAGER install -y htop >/dev/null 2>&1
            fi
            htop
            ;;
        2)
            if ! command -v iftop >/dev/null 2>&1; then
                info "正在安装 iftop ..."
                [ "$PKG_MANAGER" = "apt" ] && apt-get install -y iftop >/dev/null 2>&1
                [ "$PKG_MANAGER" = "yum" ] || [ "$PKG_MANAGER" = "dnf" ] && $PKG_MANAGER install -y iftop >/dev/null 2>&1
            fi
            iftop
            ;;
        *)
            return
            ;;
    esac
}

menu_clean() {
    while true; do
        print_banner
        echo -e "${B_CYAN}【 系统清理与日常运维监控 】${NC}"
        separator
        echo -e " ${B_GREEN}1.${NC} 系统深度垃圾清理 (旧内核/APT缓存/系统日志)"
        echo -e " ${B_GREEN}2.${NC} 查看服务器详细硬件与网络配置信息"
        echo -e " ${B_GREEN}3.${NC} 实时系统负载与网络流量监控 (htop / iftop)"
        separator
        echo -e " ${B_RED}0.${NC} 返回主菜单"
        echo ""
        read -r -p "请输入选项 [0-3]: " cln_choice
        case "$cln_choice" in
            1) deep_clean_system ;;
            2) show_system_specs ;;
            3) launch_realtime_monitor ;;
            0) break ;;
            *)
                echo -e "${RED}输入错误，请重新选择！${NC}"
                sleep 1
                ;;
        esac
    done
}
