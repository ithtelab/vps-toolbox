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
                case "$PKG_MANAGER" in
                    apt) apt-get install -y htop >/dev/null 2>&1 ;;
                    dnf|yum) $PKG_MANAGER install -y htop >/dev/null 2>&1 ;;
                    apk) apk add htop >/dev/null 2>&1 ;;
                    pacman) pacman -S --noconfirm htop >/dev/null 2>&1 ;;
                esac
            fi
            htop
            ;;
        2)
            if ! command -v iftop >/dev/null 2>&1; then
                info "正在安装 iftop ..."
                case "$PKG_MANAGER" in
                    apt) apt-get install -y iftop >/dev/null 2>&1 ;;
                    dnf|yum) $PKG_MANAGER install -y iftop >/dev/null 2>&1 ;;
                    apk) apk add iftop >/dev/null 2>&1 ;;
                    pacman) pacman -S --noconfirm iftop >/dev/null 2>&1 ;;
                esac
            fi
            iftop
            ;;
        *)
            return
            ;;
    esac
}

install_netdata() {
    print_banner
    echo -e "${B_YELLOW}=== [4] 部署 Netdata 实时监控面板 ===${NC}"
    info "正在安装 Netdata 实时性能监控 (CPU/内存/磁盘/网络可视化)..."
    if command -v docker >/dev/null 2>&1; then
        local port
        read -r -p "请输入 Web 访问端口 [默认 19999]: " port
        port=${port:-19999}
        docker run -d --name=netdata --restart always \
            -p "${port}:19999" \
            -v netdata_config:/etc/netdata \
            -v /proc:/host/proc:ro \
            -v /sys:/host/sys:ro \
            -v /var/run/docker.sock:/var/run/docker.sock:ro \
            netdata/netdata >/dev/null 2>&1
        open_port "$port" tcp
        local ip
        ip=$(get_ip_info)
        success "Netdata 部署成功! 访问: http://${ip}:${port}"
    else
        info "未检测到 Docker, 使用官方安装脚本..."
        bash <(curl -fsSL https://get.netdata.cloud/kickstart.sh) --non-interactive >/dev/null 2>&1 || \
        error "Netdata 安装失败, 请检查网络。"
        systemctl enable --now netdata >/dev/null 2>&1 || true
        success "Netdata 安装完成! 默认端口 19999"
    fi
    pause
}

check_disk_health() {
    print_banner
    echo -e "${B_YELLOW}=== [5] 磁盘与 S.M.A.R.T. 健康检查 ===${NC}"
    info "扫描系统中所有块设备..."

    if ! command -v smartctl >/dev/null 2>&1; then
        info "正在安装 smartmontools ..."
        case "$PKG_MANAGER" in
            apt) apt-get install -y smartmontools >/dev/null 2>&1 ;;
            dnf|yum) $PKG_MANAGER install -y smartmontools >/dev/null 2>&1 ;;
            apk) apk add smartmontools >/dev/null 2>&1 ;;
        esac
    fi

    local disks
    disks=$(lsblk -dno NAME 2>/dev/null | grep -Ev '^loop' | head -n 5)
    if [ -z "$disks" ]; then
        disks=$(ls /dev/sd? /dev/vd? /dev/nvme?n1 2>/dev/null | sed 's|/dev/||')
    fi

    separator
    printf "%-12s | %-8s | %-6s | %s\n" "设备" "健康状态" "S.M.A.R.T" "型号"
    separator

    for d in $disks; do
        local dev="/dev/$d"
        local health smart model
        if command -v smartctl >/dev/null 2>&1 && smartctl -H "$dev" >/dev/null 2>&1; then
            health=$(smartctl -H "$dev" 2>/dev/null | grep -iE "result" | grep -oiE "passed|failed" | head -n1)
            smart=$(smartctl -H "$dev" 2>/dev/null | grep -oiE "SMART.*(OK|FAILED)" | head -n1)
            model=$(smartctl -i "$dev" 2>/dev/null | grep -i "model" | head -n1 | awk -F: '{print $2}')
        fi
        [ -z "$health" ] && health="N/A"
        [ -z "$smart" ] && smart="N/A"
        [ -z "$model" ] && model="未知"
        printf "%-12s | %-8s | %-6s | %s\n" "$d" "${health}" "${smart}" "$model"
    done
    separator

    echo ""
    echo -e " ${B_GREEN}1.${NC} 对主要磁盘执行 S.M.A.R.T. 自检 (约 1-2 分钟)"
    echo -e " ${B_RED}0.${NC} 返回"
    echo ""
    read -r -p "请选择: " hd_op
    if [ "$hd_op" = "1" ]; then
        local main_disk
        main_disk=$(echo "$disks" | head -n 1)
        if [ -n "$main_disk" ] && command -v smartctl >/dev/null 2>&1; then
            info "正在对 /dev/$main_disk 执行 S.M.A.R.T. 自检..."
            smartctl -t short "/dev/$main_disk" >/dev/null 2>&1 && \
            success "已下达自检指令, 可稍后通过 smartctl -l selftest /dev/$main_disk 查看结果。"
        else
            warn "未检测到可用的块设备或 smartctl。"
        fi
    fi
    pause
}

snapshot_backup() {
    print_banner
    echo -e "${B_YELLOW}=== [6] 系统快照备份一键导出 ===${NC}"
    local ts
    ts=$(date +%Y%m%d_%H%M%S)
    local dest="/root/hte_snapshot_${ts}.tar.gz"
    local list_file="/tmp/hte_snapshot_list.txt"

    info "正在收集系统关键配置与安装清单..."
    {
        echo /etc
        echo /root
        crontab -l 2>/dev/null | grep -v '^#' | grep -v '^$' > /tmp/hte_cron.txt || true
        # Package inventory
        if command -v dpkg >/dev/null 2>&1; then
            dpkg -l 2>/dev/null | awk '/^ii/ {print $2, $3}' > /tmp/hte_pkgs.txt
        elif command -v rpm >/dev/null 2>&1; then
            rpm -qa 2>/dev/null > /tmp/hte_pkgs.txt
        fi
        [ -f /tmp/hte_cron.txt ] && echo /tmp/hte_cron.txt
        [ -f /tmp/hte_pkgs.txt ] && echo /tmp/hte_pkgs.txt
    } > "$list_file"

    info "正在打包 (首次可能较慢, 已排除 /var /usr 大目录)..."
    tar --exclude='/var' --exclude='/usr' --exclude='/proc' --exclude='/sys' --exclude='/dev' \
        -czf "$dest" -T "$list_file" >/dev/null 2>&1

    rm -f "$list_file" /tmp/hte_cron.txt /tmp/hte_pkgs.txt

    if [ -f "$dest" ]; then
        local size
        size=$(du -h "$dest" | cut -f1)
        success "系统快照备份完成!"
        echo -e "备份文件: ${B_YELLOW}${dest}${NC} (大小: ${size})"
        echo -e "包含内容: /etc 配置、/root 目录、crontab 计划任务、软件包安装清单"
    else
        error "备份失败, 请检查磁盘空间。"
    fi
    pause
}

menu_clean() {
    while true; do
        print_banner
        echo -e "${B_CYAN}【 系统清理与日常运维监控 】${NC}"
        separator
        echo -e " ${B_GREEN}1.${NC} 系统深度垃圾清理 (旧内核/APT缓存/系统日志)"
        echo -e " ${B_GREEN}2.${NC} 查看服务器详细硬件与网络配置信息"
        echo -e " ${B_GREEN}3.${NC} 实时系统负载与网络流量监控 (htop / iftop)"
        echo -e " ${B_GREEN}4.${NC} 部署 Netdata 实时监控面板"
        echo -e " ${B_GREEN}5.${NC} 磁盘与 S.M.A.R.T. 健康检查"
        echo -e " ${B_GREEN}6.${NC} 系统快照备份一键导出"
        separator
        echo -e " ${B_RED}0.${NC} 返回主菜单"
        echo ""
        read -r -p "请输入选项 [0-6]: " cln_choice
        case "$cln_choice" in
            1) deep_clean_system ;;
            2) show_system_specs ;;
            3) launch_realtime_monitor ;;
            4) install_netdata ;;
            5) check_disk_health ;;
            6) snapshot_backup ;;
            0) break ;;
            *)
                echo -e "${RED}输入错误，请重新选择！${NC}"
                sleep 1
                ;;
        esac
    done
}
