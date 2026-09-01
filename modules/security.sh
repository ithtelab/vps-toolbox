#!/usr/bin/env bash
# ==============================================================================
# Linux VPS Toolbox - Security & Hardening Module
# ==============================================================================

change_ssh_port() {
    print_banner
    echo -e "${B_YELLOW}=== [1] 修改 SSH 默认远程连接端口 ===${NC}"
    local current_port
    current_port=$(ss -tulpn 2>/dev/null | grep -E '(sshd|sshd:)' | grep LISTEN | awk '{print $5}' | awk -F: '{print $NF}' | sort -u | head -n 1)
    [ -z "$current_port" ] && current_port="22"

    echo -e "当前 SSH 端口: ${B_CYAN}${current_port}${NC}"
    echo ""
    read -r -p "请输入新的 SSH 端口 [1-65535, 推荐 10000-65535]: " new_port

    if [[ ! "$new_port" =~ ^[0-9]+$ ]] || [ "$new_port" -lt 1 ] || [ "$new_port" -gt 65535 ]; then
        error "端口号无效，请输入 1-65535 范围内的数字！"
        pause
        return
    fi

    info "正在修改 SSH 配置文件 /etc/ssh/sshd_config 与 sshd_config.d/ ..."
    sed -i '/^#\?Port /d' /etc/ssh/sshd_config
    echo "Port $new_port" >> /etc/ssh/sshd_config

    # Handle Ubuntu 22.10+ / Debian 12 sshd_config.d drop-in
    if [ -d /etc/ssh/sshd_config.d ]; then
        echo "Port $new_port" > /etc/ssh/sshd_config.d/custom-port.conf
    fi

    info "正在放行新端口 $new_port ..."
    open_port "$new_port" "tcp"

    # Handle Ubuntu 22.10+ / 24.04 ssh.socket systemd override
    if systemctl is-active --quiet ssh.socket 2>/dev/null; then
        info "检测到新版系统 ssh.socket 托管，正在同步配置 socket 端口..."
        mkdir -p /etc/systemd/system/ssh.socket.d
        cat <<EOF > /etc/systemd/system/ssh.socket.d/listen.conf
[Socket]
ListenStream=
ListenStream=${new_port}
EOF
        systemctl daemon-reload 2>/dev/null || true
        systemctl restart ssh.socket 2>/dev/null || true
    fi

    if systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null || service sshd restart 2>/dev/null; then
        success "SSH 端口已成功修改为: ${new_port}"
        warn "重要提示: 请先【不要关闭当前终端窗口】，另开一个终端窗口尝试使用新端口连接验证！"
    else
        error "SSH 服务重启失败，请检查配置文件！"
    fi
    pause
}

setup_ssh_key() {
    print_banner
    echo -e "${B_YELLOW}=== [2] SSH 密钥登录配置与禁用密码登录 ===${NC}"
    echo -e " ${B_GREEN}1.${NC} 导入 SSH 客户端公钥 (id_rsa.pub 内容)"
    echo -e " ${B_GREEN}2.${NC} 禁用 SSH 密码登录 (仅允许密钥登录，防暴力破解)"
    echo -e " ${B_GREEN}3.${NC} 恢复 SSH 密码登录"
    echo -e " ${B_RED}0.${NC} 返回"
    echo ""
    read -r -p "请选择操作 [0-3]: " key_choice

    case "$key_choice" in
        1)
            echo ""
            echo "请粘贴你的公钥内容 (以 ssh-rsa / ssh-ed25519 开头): "
            read -r pub_key
            if [ -n "$pub_key" ]; then
                mkdir -p /root/.ssh
                chmod 700 /root/.ssh
                echo "$pub_key" >> /root/.ssh/authorized_keys
                chmod 600 /root/.ssh/authorized_keys
                success "公钥已成功追加到 /root/.ssh/authorized_keys"
            else
                error "公钥内容为空！"
            fi
            ;;
        2)
            if [ ! -f /root/.ssh/authorized_keys ] || [ ! -s /root/.ssh/authorized_keys ]; then
                error "未检测到已配置的 SSH 公钥，禁止关闭密码登录，否则将导致无法连接！"
            else
                sed -i '/^#\?PasswordAuthentication /d' /etc/ssh/sshd_config
                echo "PasswordAuthentication no" >> /etc/ssh/sshd_config
                [ -d /etc/ssh/sshd_config.d ] && echo "PasswordAuthentication no" > /etc/ssh/sshd_config.d/auth.conf
                systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null
                success "已成功禁用密码登录！现仅支持密钥连接。"
            fi
            ;;
        3)
            sed -i '/^#\?PasswordAuthentication /d' /etc/ssh/sshd_config
            echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config
            [ -d /etc/ssh/sshd_config.d ] && rm -f /etc/ssh/sshd_config.d/auth.conf
            systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null
            success "已恢复 SSH 密码登录。"
            ;;
        *)
            return
            ;;
    esac
    pause
}

install_fail2ban() {
    print_banner
    echo -e "${B_YELLOW}=== [3] 安装 Fail2ban 防暴力破解工具 ===${NC}"
    info "正在安装并配置 Fail2ban ..."
    case "$PKG_MANAGER" in
        apt)
            apt-get update -y >/dev/null 2>&1
            apt-get install -y fail2ban >/dev/null 2>&1
            ;;
        dnf|yum)
            $PKG_MANAGER install -y epel-release >/dev/null 2>&1
            $PKG_MANAGER install -y fail2ban >/dev/null 2>&1
            ;;
    esac

    # Debian 12 / Ubuntu 24.04 compatibility using systemd backend
    cat <<EOF > /etc/fail2ban/jail.local
[DEFAULT]
bantime = 86400
findtime = 600
maxretry = 5
backend = systemd

[sshd]
enabled = true
EOF

    systemctl daemon-reload 2>/dev/null || true
    systemctl enable fail2ban >/dev/null 2>&1
    systemctl restart fail2ban >/dev/null 2>&1
    success "Fail2ban 安装并启动完成 (连续输错密码 5 次将自动封禁 24 小时)！"
    pause
}

view_fail2ban_status() {
    print_banner
    echo -e "${B_YELLOW}=== 查看 Fail2ban 封禁名单与解封 ===${NC}"
    if ! command -v fail2ban-client >/dev/null 2>&1; then
        warn "尚未安装 Fail2ban，请先选择安装 Fail2ban！"
        pause
        return
    fi

    info "Fail2ban SSH 防护状态:"
    fail2ban-client status sshd 2>/dev/null || fail2ban-client status
    echo ""
    echo -e " ${B_GREEN}1.${NC} 手动解封某个被拦截的 IP"
    echo -e " ${B_RED}0.${NC} 返回"
    echo ""
    read -r -p "请选择: " fb_op
    if [ "$fb_op" = "1" ]; then
        read -r -p "请输入要解封的 IP: " unban_ip
        if [ -n "$unban_ip" ]; then
            fail2ban-client set sshd unbanip "$unban_ip" 2>/dev/null || true
            success "已执行解封指令。"
        fi
    fi
    pause
}

enable_syn_protection() {
    print_banner
    echo -e "${B_YELLOW}=== [5] TCP SYN Flood 洪水攻击与网络参数防爆加固 ===${NC}"
    info "正在写入 TCP 协议栈防攻击与抗并发参数..."
    
    # Strip existing keys first to avoid accumulating duplicate lines on re-runs
    for key in \
        "net.ipv4.tcp_syncookies" \
        "net.ipv4.tcp_tw_reuse" \
        "net.ipv4.tcp_fin_timeout" \
        "net.ipv4.tcp_keepalive_time" \
        "net.ipv4.ip_local_port_range" \
        "net.ipv4.tcp_max_syn_backlog" \
        "net.ipv4.tcp_max_tw_buckets" \
        "net.core.somaxconn" \
        "net.core.netdev_max_backlog"
    do
        sed -i "/^${key}/d" /etc/sysctl.conf
    done

    cat <<EOF >> /etc/sysctl.conf
# Anti-DDoS & TCP Tuning
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.ip_local_port_range = 10000 65000
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_max_tw_buckets = 5000
net.core.somaxconn = 32768
net.core.netdev_max_backlog = 32768
EOF

    sysctl -p >/dev/null 2>&1 || true
    success "TCP SYN 防护与协议栈高并发加固参数已生效！"
    pause
}

manage_firewall() {
    print_banner
    echo -e "${B_YELLOW}=== [4] 防火墙与端口放行管理 ===${NC}"
    echo -e " ${B_GREEN}1.${NC} 放行指定 TCP/UDP 端口"
    echo -e " ${B_GREEN}2.${NC} 查看当前已监听端口 (TCP/UDP)"
    echo -e " ${B_RED}0.${NC} 返回"
    echo ""
    read -r -p "请选择操作 [0-2]: " fw_choice

    case "$fw_choice" in
        1)
            read -r -p "请输入要放行的端口: " p_num
            read -r -p "协议类型 [tcp/udp, 默认 tcp]: " p_proto
            p_proto=${p_proto:-tcp}
            open_port "$p_num" "$p_proto"
            success "端口 $p_num ($p_proto) 已在防火墙放行。"
            ;;
        2)
            echo ""
            info "当前系统正在监听的端口:"
            ss -tulpn 2>/dev/null || netstat -tulpn 2>/dev/null
            ;;
        *)
            return
            ;;
    esac
    pause
}

setup_telegram_alerts() {
    print_banner
    echo -e "${B_YELLOW}=== [7] Telegram 机器人安全告警推送 ===${NC}"
    info "配置 Telegram Bot 实时告警 (SSH 登录 / Fail2ban 封禁 / 高磁盘 / 重启)"

    read -r -p "请输入 Telegram Bot Token (从 @BotFather 获取): " tg_token
    read -r -p "请输入接收告警的 Chat ID (私聊 @userinfobot 获取): " tg_chat

    if [ -z "$tg_token" ] || [ -z "$tg_chat" ]; then
        error "Token 与 Chat ID 不能为空！"
        pause
        return
    fi

    # Test the bot connectivity first
    info "正在测试 Bot 连通性..."
    local test_resp
    test_resp=$(curl -s --connect-timeout 8 --max-time 15 "https://api.telegram.org/bot${tg_token}/sendMessage" --data-urlencode "chat_id=${tg_chat}" --data-urlencode "text=✅ 黑天鹅工具箱 Telegram 告警配置成功!" 2>/dev/null)
    if echo "$test_resp" | grep -q '"ok":true'; then
        success "Telegram Bot 连通成功！"
    else
        error "Telegram Bot 连通失败，请检查 Token / Chat ID / 服务器能否访问 api.telegram.org"
        pause
        return
    fi

    # Deploy notification helper + systemd timer to watch key events
    local conf="/etc/hte-alerts.conf"
    cat <<EOF > "$conf"
TG_TOKEN="${tg_token}"
TG_CHAT="${tg_chat}"
EOF
    chmod 600 "$conf"

    local helper="/usr/local/bin/hte-alert"
    cat <<'HEOF' > "$helper"
#!/usr/bin/env bash
# HTE Telegram Alert helper — reads /etc/hte-alerts.conf
[ -f /etc/hte-alerts.conf ] && . /etc/hte-alerts.conf
send_tg() {
    local msg="$1"
    [ -z "$TG_TOKEN" ] || [ -z "$TG_CHAT" ] && return 1
    curl -s --max-time 10 "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
        --data-urlencode "chat_id=${TG_CHAT}" --data-urlencode "text=${msg}" >/dev/null 2>&1
}
case "$1" in
    disk)
        USE=$(df -h / | awk 'NR==2 {gsub("%","",$5); print $5}')
        [ "$USE" -gt 90 ] && send_tg "⚠️ 磁盘使用率过高: ${USE}%"
        ;;
    sshd)
        # Brief guard to avoid spamming on rapid logins
        sleep 3
        send_tg "🔐 SSH 登录事件: $(last -1 2>/dev/null | head -n1 | awk '{print $1, $3, $5}')"
        ;;
esac
HEOF
    chmod +x "$helper"

    # systemd timer to check disk every 10 min
    cat <<EOF > /etc/systemd/system/hte-disk-check.service
[Unit]
Description=HTE Disk Usage Alert
[Service]
Type=oneshot
ExecStart=${helper} disk
EOF
    cat <<EOF > /etc/systemd/system/hte-disk-check.timer
[Unit]
Description=Run HTE disk check every 10 minutes
[Timer]
OnBootSec=2min
OnUnitActiveSec=10min
[Install]
WantedBy=timers.target
EOF
    systemctl daemon-reload
    systemctl enable --now hte-disk-check.timer >/dev/null 2>&1 || true

    # Notify on SSH login via PAM (idempotent)
    local pam_file="/etc/pam.d/sshd"
    if [ -f "$pam_file" ] && ! grep -q "hte-alert" "$pam_file"; then
        echo "session optional ${helper} sshd" >> "$pam_file"
    fi

    success "Telegram 安全告警配置完成！已开启：磁盘>90% 定时巡检 + SSH 登录实时推送。"
    pause
}

menu_security() {
    while true; do
        print_banner
        echo -e "${B_CYAN}【 VPS 安全加固与防护管理 】${NC}"
        separator
        echo -e " ${B_GREEN}1.${NC} 修改 SSH 远程连接端口 (支持 Ubuntu 24.04/Debian 12)"
        echo -e " ${B_GREEN}2.${NC} 配置 SSH 密钥登录 / 禁用 Root 密码登录"
        echo -e " ${B_GREEN}3.${NC} 安装并启用 Fail2ban 防暴力破解"
        echo -e " ${B_GREEN}4.${NC} 查看 Fail2ban 封禁黑名单与一键解封 IP"
        echo -e " ${B_GREEN}5.${NC} 防火墙端口放行与已监听端口查看"
        echo -e " ${B_GREEN}6.${NC} 开启 TCP SYN Flood 抗攻击与高并发加固"
        echo -e " ${B_GREEN}7.${NC} 配置 Telegram 机器人安全告警推送"
        separator
        echo -e " ${B_RED}0.${NC} 返回主菜单"
        echo ""
        read -r -p "请输入选项 [0-7]: " sec_choice
        case "$sec_choice" in
            1) change_ssh_port ;;
            2) setup_ssh_key ;;
            3) install_fail2ban ;;
            4) view_fail2ban_status ;;
            5) manage_firewall ;;
            6) enable_syn_protection ;;
            7) setup_telegram_alerts ;;
            0) break ;;
            *)
                echo -e "${RED}输入错误，请重新选择！${NC}"
                sleep 1
                ;;
        esac
    done
}
