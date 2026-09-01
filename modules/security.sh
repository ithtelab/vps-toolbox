#!/usr/bin/env bash
# ==============================================================================
# Linux VPS Toolbox - Security & Hardening Module
# ==============================================================================

change_ssh_port() {
    print_banner
    echo -e "${B_YELLOW}=== [1] 修改 SSH 默认远程连接端口 ===${NC}"
    local current_port
    current_port=$(ss -tulpn | grep sshd | awk '{print $5}' | awk -F: '{print $NF}' | head -n 1)
    [ -z "$current_port" ] && current_port="22"

    echo -e "当前 SSH 端口: ${B_CYAN}${current_port}${NC}"
    echo ""
    read -r -p "请输入新的 SSH 端口 [1-65535, 推荐 10000-65535]: " new_port

    if [[ ! "$new_port" =~ ^[0-9]+$ ]] || [ "$new_port" -lt 1 ] || [ "$new_port" -gt 65535 ]; then
        error "端口号无效，请输入 1-65535 范围内的数字！"
        pause
        return
    fi

    info "正在修改 SSH 配置文件 /etc/ssh/sshd_config ..."
    sed -i '/^#\?Port /d' /etc/ssh/sshd_config
    echo "Port $new_port" >> /etc/ssh/sshd_config

    info "正在放行新端口 $new_port ..."
    open_port "$new_port" "tcp"

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
                systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null
                success "已成功禁用密码登录！现仅支持密钥连接。"
            fi
            ;;
        3)
            sed -i '/^#\?PasswordAuthentication /d' /etc/ssh/sshd_config
            echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config
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

    cat <<EOF > /etc/fail2ban/jail.local
[DEFAULT]
bantime = 86400
findtime = 600
maxretry = 5

[sshd]
enabled = true
EOF

    systemctl daemon-reload 2>/dev/null || true
    systemctl enable fail2ban >/dev/null 2>&1
    systemctl restart fail2ban >/dev/null 2>&1
    success "Fail2ban 安装并启动完成 (连续输错密码 5 次将自动封禁 24 小时)！"
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

menu_security() {
    while true; do
        print_banner
        echo -e "${B_CYAN}【 VPS 安全加固与防护管理 】${NC}"
        separator
        echo -e " ${B_GREEN}1.${NC} 修改 SSH 远程连接端口"
        echo -e " ${B_GREEN}2.${NC} 配置 SSH 密钥登录 / 禁用 Root 密码登录"
        echo -e " ${B_GREEN}3.${NC} 安装并启用 Fail2ban 防暴力破解"
        echo -e " ${B_GREEN}4.${NC} 防火墙端口放行与已监听端口查看"
        separator
        echo -e " ${B_RED}0.${NC} 返回主菜单"
        echo ""
        read -r -p "请输入选项 [0-4]: " sec_choice
        case "$sec_choice" in
            1) change_ssh_port ;;
            2) setup_ssh_key ;;
            3) install_fail2ban ;;
            4) manage_firewall ;;
            0) break ;;
            *)
                echo -e "${RED}输入错误，请重新选择！${NC}"
                sleep 1
                ;;
        esac
    done
}
