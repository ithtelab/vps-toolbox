#!/usr/bin/env bash
# ==============================================================================
# Linux VPS Toolbox - Proxy & Port Forwarding Module
# ==============================================================================

install_socks5() {
    print_banner
    echo -e "${B_YELLOW}=== [1] Socks5 (SK5) 极简高性能代理搭建 ===${NC}"
    info "正在检测依赖并准备部署轻量级 Socks5 服务..."

    local sk5_port
    local sk5_user
    local sk5_pass

    read -r -p "请输入 Socks5 端口 [默认 10808]: " sk5_port
    sk5_port=${sk5_port:-10808}

    read -r -p "请输入用户名 [默认 admin]: " sk5_user
    sk5_user=${sk5_user:-admin}

    read -r -p "请输入密码 [默认随机生成]: " sk5_pass
    if [ -z "$sk5_pass" ]; then
        sk5_pass=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 12)
    fi

    info "选定配置 -> 端口: ${sk5_port}, 账号: ${sk5_user}, 密码: ${sk5_pass}"
    
    # Install Gost as ultra-lightweight SOCKS5 daemon
    local gost_bin="/usr/local/bin/gost"
    if [ ! -f "$gost_bin" ]; then
        info "正在下载 Gost 轻量代理内核..."
        local gost_arch="amd64"
        [ "$CPU_ARCH" = "aarch64" ] && gost_arch="armv8"
        [ "$CPU_ARCH" = "armv7" ] && gost_arch="armv7"
        
        local gost_urls=(
            "https://github.com/go-gost/gost/releases/download/v3.0.0-rc10/gost_3.0.0-rc10_linux_${gost_arch}.tar.gz"
            "https://ghproxy.com/https://github.com/go-gost/gost/releases/download/v3.0.0-rc10/gost_3.0.0-rc10_linux_${gost_arch}.tar.gz"
            "https://github.com/ginuerzh/gost/releases/download/v2.11.5/gost-linux-${gost_arch}-2.11.5.gz"
        )

        for u in "${gost_urls[@]}"; do
            if wget -q --no-check-certificate -O /tmp/gost.tar.gz "$u"; then
                tar -zxf /tmp/gost.tar.gz -C /usr/local/bin/ gost 2>/dev/null || gzip -d -c /tmp/gost.tar.gz > /usr/local/bin/gost 2>/dev/null || true
                [ -f "$gost_bin" ] && break
            fi
        done

        chmod +x "$gost_bin" 2>/dev/null || true
        rm -f /tmp/gost.tar.gz
    fi

    # Create systemd service
    cat <<EOF > /etc/systemd/system/socks5-server.service
[Unit]
Description=Gost High-Performance Socks5 Proxy Service
After=network.target

[Service]
Type=simple
ExecStart=${gost_bin} -L socks5://${sk5_user}:${sk5_pass}@:${sk5_port}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable socks5-server >/dev/null 2>&1
    systemctl restart socks5-server

    # Open firewall port
    open_port "$sk5_port" "tcp"
    open_port "$sk5_port" "udp"

    local server_ip
    server_ip=$(get_ip_info)

    echo ""
    success "Socks5 (SK5) 代理服务搭建成功！"
    separator
    echo -e "${B_GREEN}服务器地址 (IP):${NC} ${B_YELLOW}${server_ip}${NC}"
    echo -e "${B_GREEN}代理端口 (Port):${NC} ${B_YELLOW}${sk5_port}${NC}"
    echo -e "${B_GREEN}认证用户名:${NC}      ${B_YELLOW}${sk5_user}${NC}"
    echo -e "${B_GREEN}认证密码:${NC}        ${B_YELLOW}${sk5_pass}${NC}"
    echo -e "${B_GREEN}TG 一键直连代理链接:${NC}"
    echo -e "${CYAN}https://t.me/socks?server=${server_ip}&port=${sk5_port}&user=${sk5_user}&pass=${sk5_pass}${NC}"
    separator
    pause
}

uninstall_socks5() {
    info "正在停止并卸载 Socks5 服务..."
    systemctl stop socks5-server 2>/dev/null || true
    systemctl disable socks5-server 2>/dev/null || true
    rm -f /etc/systemd/system/socks5-server.service
    systemctl daemon-reload
    success "Socks5 服务已彻底卸载。"
    pause
}

install_clash_party() {
    print_banner
    echo -e "${B_YELLOW}=== [2] Clash / Mihomo 节点与服务端极速搭建 ===${NC}"
    info "正在部署 Mihomo (Clash-Meta) 高性能核心..."

    local port
    local secret
    read -r -p "请输入外部监听端口 [默认 7890]: " port
    port=${port:-7890}

    read -r -p "请输入 API 访问密钥 [默认留空]: " secret

    local config_dir="/etc/mihomo"
    mkdir -p "$config_dir"

    # Download Mihomo core
    local mihomo_bin="/usr/local/bin/mihomo"
    local m_arch="amd64"
    [ "$CPU_ARCH" = "aarch64" ] && m_arch="arm64"

    info "正在拉取 Mihomo 最新核心..."
    local mihomo_urls=(
        "https://github.com/MetaCubeX/mihomo/releases/download/v1.18.7/mihomo-linux-${m_arch}-v1.18.7.gz"
        "https://ghproxy.com/https://github.com/MetaCubeX/mihomo/releases/download/v1.18.7/mihomo-linux-${m_arch}-v1.18.7.gz"
    )

    for mu in "${mihomo_urls[@]}"; do
        if wget -q --no-check-certificate -O /tmp/mihomo.gz "$mu"; then
            gzip -d /tmp/mihomo.gz -c > "$mihomo_bin" 2>/dev/null || true
            chmod +x "$mihomo_bin"
            rm -f /tmp/mihomo.gz
            [ -f "$mihomo_bin" ] && break
        fi
    done

    # Write Mihomo config
    cat <<EOF > ${config_dir}/config.yaml
port: ${port}
socks-port: $((port + 1))
allow-lan: true
mode: rule
log-level: info
secret: "${secret}"
external-controller: 0.0.0.0:$((port + 10))
EOF

    # Systemd Service
    cat <<EOF > /etc/systemd/system/mihomo.service
[Unit]
Description=Mihomo / Clash Core Service
After=network.target

[Service]
Type=simple
ExecStart=${mihomo_bin} -d ${config_dir}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable mihomo >/dev/null 2>&1
    systemctl restart mihomo

    open_port "$port" "tcp"
    open_port "$((port + 1))" "tcp"

    local server_ip
    server_ip=$(get_ip_info)

    echo ""
    success "Clash / Mihomo 服务端部署完成！"
    separator
    echo -e "${B_GREEN}HTTP 代理端口:${NC}   ${B_YELLOW}${port}${NC}"
    echo -e "${B_GREEN}Socks5 代理端口:${NC} ${B_YELLOW}$((port + 1))${NC}"
    echo -e "${B_GREEN}控制面板 API 端口:${NC} ${B_YELLOW}$((port + 10))${NC}"
    echo -e "${B_GREEN}控制面板密钥:${NC}     ${B_YELLOW}${secret:-无}${NC}"
    separator
    pause
}

install_realm_forward() {
    print_banner
    echo -e "${B_YELLOW}=== [3] Realm 高性能极速端口转发 ===${NC}"
    info "正在安装 Realm 端口转发工具..."
    bash <(curl -sL https://raw.githubusercontent.com/spiritLHLS/realm-one-click/main/realm.sh) || \
    bash <(curl -sL https://ghproxy.com/https://raw.githubusercontent.com/spiritLHLS/realm-one-click/main/realm.sh)
    pause
}

install_singbox_vless() {
    print_banner
    echo -e "${B_YELLOW}=== [4] VLESS-Reality / Hysteria 2 官方自动化脚本 ===${NC}"
    info "正在调取前沿主流协议脚本菜单..."
    bash <(curl -fsSL https://raw.githubusercontent.com/fscarmen/sing-box/main/sing-box.sh) || \
    bash <(curl -fsSL https://raw.githubusercontent.com/mack-a/v2ray-agent/master/install.sh)
    pause
}

menu_proxy() {
    while true; do
        print_banner
        echo -e "${B_CYAN}【 代理搭建与端口转发服务 】${NC}"
        separator
        echo -e " ${B_GREEN}1.${NC} 一键搭建 Socks5 (SK5) 极简认证代理"
        echo -e " ${B_GREEN}2.${NC} 卸载 Socks5 (SK5) 代理服务"
        echo -e " ${B_GREEN}3.${NC} 一键搭建 Clash / Mihomo 服务端"
        echo -e " ${B_GREEN}4.${NC} 一键部署 Realm 极速端口转发 (中转加速)"
        echo -e " ${B_GREEN}5.${NC} VLESS-Reality / Hysteria 2 综合管理"
        separator
        echo -e " ${B_RED}0.${NC} 返回主菜单"
        echo ""
        read -r -p "请输入选项 [0-5]: " proxy_choice
        case "$proxy_choice" in
            1) install_socks5 ;;
            2) uninstall_socks5 ;;
            3) install_clash_party ;;
            4) install_realm_forward ;;
            5) install_singbox_vless ;;
            0) break ;;
            *)
                echo -e "${RED}输入错误，请重新选择！${NC}"
                sleep 1
                ;;
        esac
    done
}
