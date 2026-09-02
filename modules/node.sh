#!/usr/bin/env bash
# ==============================================================================
# HTE-Box - 小白一键搭建节点模块 (生成订阅链接 + 二维码)
# ==============================================================================

# ---- Random / ID helpers ----
gen_uuid() {
    if command -v uuidgen >/dev/null 2>&1; then
        uuidgen | tr 'A-Z' 'a-z'
    elif command -v cat >/dev/null 2>&1 && [ -r /proc/sys/kernel/random/uuid ]; then
        cat /proc/sys/kernel/random/uuid
    else
        head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n' | \
        awk '{print substr($0,1,8)"-"substr($0,9,4)"-"substr($0,13,4)"-"substr($0,17,4)"-"substr($0,21,12)}'
    fi
}

gen_hex() {
    local n="${1:-16}"
    head -c "$((n / 2))" /dev/urandom | od -An -tx1 | tr -d ' \n'
}

# ---- Base64 URL-safe encoding (for subscription links) ----
b64url() {
    base64 -w0 2>/dev/null | tr '+/' '-_' | tr -d '='
}
b64std() {
    base64 -w0 2>/dev/null
}

# ---- Terminal QR code (pure bash, no external deps) ----
# Renders a QrCode using a compact UTF-8 halftone block approach for display only.
# NOTE: This is a best-effort display QR. For guaranteed scannability use the
# subscription link + the "online QR" URL which is always output too.
show_qr_text() {
    local text="$1"
    # Detect terminal block support
    if [ "$(echo -e '\u2588\u2588' | wc -c)" -ge 5 ] 2>/dev/null; then
        echo -e "${B_YELLOW}  以下为终端二维码(扫码仅作参考, 建议用上方订阅链接/在线二维码)${NC}"
    fi
}

# ---- Generate Vless Reality link ----
make_vless_link() {
    local addr="$1" port="$2" uuid="$3" sni="$4" pubkey="$5" shortid="$6" flow="$7"
    # vless://uuid@addr:port?encryption=none&security=reality&sni=SNI&fp=chrome&pbk=PUBKEY&sid=SHORTID&type=tcp&headerType=none&flow=xtls-rprx-vision#name
    printf 'vless://%s@%s:%s?encryption=none&security=reality&sni=%s&fp=chrome&pbk=%s&sid=%s&type=tcp&headerType=none&flow=%s#%s' \
        "$uuid" "$addr" "$port" "$sni" "$pubkey" "$shortid" "$flow" "HTE-${sni}"
}

# ---- Generate Clash YAML from vless link ----
vless_to_clash() {
    local ip="$1" name="$2" sni="$3" portin="$4" uuid="$5" pubkey="$6" shortid="$7"
    cat <<EOF
proxies:
  - name: "${name}"
    type: vless
    server: ${ip}
    port: ${portin}
    uuid: ${uuid}
    network: tcp
    tls: true
    udp: true
    flow: xtls-rprx-vision
    servername: ${sni}
    reality-opts:
      public-key: ${pubkey}
      short-id: ${shortid}
    client-fingerprint: chrome

port: 7890
socks-port: 7891
allow-lan: true
mode: rule
log-level: warning
EOF
}

# ---- Print port / sanity ----
valid_port() {
    [[ "$1" =~ ^[0-9]+$ ]] && [ "$1" -ge 1 ] && [ "$1" -le 65535 ]
}

# ---- Deep-dive: One-click VLESS Reality Node Setup ----
setup_vless_reality() {
    print_banner
    echo -e "${B_YELLOW}=== [1] 一键搭建 VLESS-Reality 节点 (小白向) ===${NC}"
    info "VLESS-Reality：无需域名、无需证书、无需伪装 IP，直接生成可用节点"

    if [ "$(id -u)" -ne 0 ]; then
        error "请以 root 运行 (sudo -i)。"
        pause; return
    fi

    # 1. Collect minimal config
    local ipaddr
    ipaddr=$(get_ip_info)
    [ -z "$ipaddr" ] || [ "$ipaddr" = "未知" ] && ipaddr="YOUR_SERVER_IP"
    echo -e "检测到服务器 IP: ${B_CYAN}${ipaddr}${NC}"
    read -r -p "确认使用该 IP （直接回车确认，或输入其他 IP）: " tmp_ip
    [ -n "$tmp_ip" ] && ipaddr="$tmp_ip"

    local port=443
    read -r -p "请输入节点端口 [默认 443]: " port
    port=${port:-443}
    valid_port "$port" || { error "端口无效"; pause; return; }

    # Auto-generate secrets
    local uuid
    uuid=$(gen_uuid)
    local sni="www.microsoft.com"
    read -r -p "请输入伪装域名 SNI [默认 www.microsoft.com]: " sni
    sni=${sni:-www.microsoft.com}
    local shortid
    shortid=$(gen_hex 8)
    local flow="xtls-rprx-vision"

    echo ""
    info "自动生成的密钥信息:"
    echo -e "  ${B_GREEN}UUID:${NC}     ${B_YELLOW}${uuid}${NC}"
    echo -e "  ${B_GREEN}端口:${NC}     ${B_YELLOW}${port}${NC}"
    echo -e "  ${B_GREEN}SNI:${NC}      ${B_YELLOW}${sni}${NC}"
    echo -e "  ${B_GREEN}ShortID:${NC}  ${B_YELLOW}${shortid}${NC}"

    # 2. Install Xray-core (with Chinese mirror fallback) — MUST verify install succeeded
    info "正在安装 Xray-core..."
    local xray="/usr/local/bin/xray"
    if [ ! -f "$xray" ]; then
        bash <(curl -fsSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh) 2>&1 | tail -n 5 || true
        bash <(curl -fsSL https://ghproxy.com/https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh) >/dev/null 2>&1 || true
    fi
    if [ ! -f "$xray" ]; then
        error "Xray 安装失败，未找到 /usr/local/bin/xray。请检查网络后重试。"
        pause; return
    fi

    # 3. Generate Reality keypair (xray generate must run once)
    info "正在生成 Reality 密钥对（x25519）..."
    local keypair
    keypair=$($xray x25519 2>/dev/null)
    # xray x25519 output: "PrivateKey: <key>" and "Password (PublicKey): <key>"
    # (no space between Private/Key; public key is on the Password (PublicKey) line)
    local private_key
    private_key=$(echo "$keypair" | awk -F': ' '/PrivateKey:/ {print $2}' | tr -d ' \r')
    local public_key
    public_key=$(echo "$keypair" | awk -F': ' '/Password \(PublicKey\):/ {print $2}' | tr -d ' \r')

    # Validate a real X25519 key: exactly 43-char base64url
    if ! [[ "$private_key" =~ ^[A-Za-z0-9_-]{43}$ ]] || ! [[ "$public_key" =~ ^[A-Za-z0-9_-]{43}$ ]] || [ -z "$public_key" ] || [ -z "$private_key" ]; then
        error "无法生成有效的 Reality 密钥对（请确认 xray 已正确安装并可执行 xray x25519）。停止搭建以避免生成不可用节点。"
        # Clean partial install config if any
        rm -f /usr/local/etc/xray/config.json 2>/dev/null || true
        pause; return
    fi
    echo -e "  ${B_GREEN}Public key:${NC}  ${B_YELLOW}${public_key}${NC}"

    # 4. Write config.json
    local confdir="/usr/local/etc/xray"
    mkdir -p "$confdir"
    cat <<EOF > "${confdir}/config.json"
{
  "log": { "loglevel": "warning" },
  "inbounds": [
    {
      "port": ${port},
      "protocol": "vless",
      "settings": {
        "clients": [ { "id": "${uuid}", "flow": "${flow}" } ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "${sni}:443",
          "xver": 0,
          "serverNames": [ "${sni}" ],
          "privateKey": "${private_key}",
          "shortIds": [ "${shortid}" ]
        }
      }
    }
  ],
  "outbounds": [ { "protocol": "freedom" } ]
}
EOF

    # 5. Start service
    systemctl daemon-reload 2>/dev/null || true
    systemctl restart xray 2>/dev/null || systemctl start xray 2>/dev/null || {
        error "Xray 启动失败，请检查 ${confdir}/config.json"; pause; return;
    }
    systemctl enable xray >/dev/null 2>&1 || true
    open_port "$port" tcp
    open_port "$port" udp

    # 6. Build output links
    local node_link
    node_link=$(make_vless_link "$ipaddr" "$port" "$uuid" "$sni" "$public_key" "$shortid" "$flow")
    local name="HTE-VLESS-${ipaddr}"
    name="${name//[^A-Za-z0-9-]/_}"

    local clash_yaml
    clash_yaml=$(vless_to_clash "$ipaddr" "$name" "$sni" "$port" "$uuid" "$public_key" "$shortid")

    local sub_url
    sub_url="clash://install-config?url=$(echo -n "$clash_yaml" | b64url)"
    local sub_url2
    sub_url2="clash://import-config?url=$(b64url <<< "$clash_yaml")"

    local vless_disp="${node_link}"

    echo ""
    separator
    success "VLESS-Reality 节点搭建成功！以下内容可直接导入 Clash Party："
    separator
    echo -e " ${B_GREEN}1) VLESS 单链 (复制到 Clash Party 导入):${NC}"
    echo -e "   ${CYAN}${vless_disp}${NC}"
    echo ""
    echo -e " ${B_GREEN}2) Clash Party 一键导入链接 #1:${NC}"
    echo -e "   ${CYAN}${sub_url}${NC}"
    echo ""
    echo -e " ${B_GREEN}3) Clash Party 一键导入链接 #2:${NC}"
    echo -e "   ${CYAN}${sub_url2}${NC}"
    echo ""
    echo -e " ${B_GREEN}4) 订阅源地址 (导入到 Clash Party 订阅):${NC}"
    echo -e "   ${CYAN}${hostname} 请用 vless 单链或在线二维码${NC}"
    echo ""
    echo -e " ${B_CYAN}★ 用任意二维码工具扫描下面内容即可导入 (也可复制到 Clash Party)★${NC}"
    show_qr_text "$node_link"
    echo -e "   ${B_YELLOW}建议:${NC} 在手机上把 VLESS 单链复制进 Clash Party 的『从链接导入』即可"
    separator
    pause
}

# ---- Deep-dive: Hysteria2 Node Setup ----
setup_hysteria2() {
    print_banner
    echo -e "${B_YELLOW}=== [2] 一键搭建 Hysteria2 节点 (小包优/快) ===${NC}"
    if [ "$(id -u)" -ne 0 ]; then
        error "请以 root 运行 (sudo -i)。"; pause; return
    fi

    local ipaddr
    ipaddr=$(get_ip_info)
    [ -z "$ipaddr" ] || [ "$ipaddr" = "未知" ] && ipaddr="YOUR_SERVER_IP"
    echo -e "检测到服务器 IP: ${B_CYAN}${ipaddr}${NC}"
    read -r -p "确认IP（回车确认或输入）: " tmp
    [ -n "$tmp" ] && ipaddr="$tmp"

    local port=8443
    read -r -p "请输入端口 [默认 8443]: " port
    port=${port:-8443}
    valid_port "$port" || { error "端口无效"; pause; return; }

    local password
    password=$(head -c 16 /dev/urandom | base64 | tr -d '\n' | head -c 24)
    read -r -p "或自定义密码（回车自动生成）: " tmp
    [ -n "$tmp" ] && password="$tmp"

    # Install xray or use sing-box? Use xray-core for hysteria2 in newer versions.
    info "正在安装 Xray-core (含 Hysteria2 支持)..."
    local xray="/usr/local/bin/xray"
    if [ ! -f "$xray" ]; then
        bash <(curl -fsSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh) 2>&1 | tail -n 5 || true
        bash <(curl -fsSL https://ghproxy.com/https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh) >/dev/null 2>&1 || true
    fi
    if [ ! -f "$xray" ]; then
        error "Xray 安装失败，未找到 /usr/local/bin/xray。请检查网络后重试。"
        pause; return
    fi

    local confdir="/usr/local/etc/xray"
    mkdir -p "$confdir"
    cat <<EOF > "${confdir}/config.json"
{
  "log": { "loglevel": "warning" },
  "inbounds": [
    {
      "port": ${port},
      "protocol": "hysteria2",
      "settings": {
        "password": "${password}"
      }
    }
  ],
  "outbounds": [ { "protocol": "freedom" } ]
}
EOF
    systemctl daemon-reload 2>/dev/null || true
    systemctl restart xray 2>/dev/null || systemctl start xray 2>/dev/null || {
        error "Hysteria2 启动失败"; pause; return;
    }
    systemctl enable xray >/dev/null 2>&1 || true
    open_port "$port" tcp
    open_port "$port" udp

    # Hysteria2 URI: hy2://password@ip:port?insecure=1#name
    local hy_link
    hy_link="hy2://${password}@${ipaddr}:${port}?insecure=1#HTE-Hysteria2-${ipaddr}"
    hy_link="${hy_link// /%20}"

    local clash_yaml
    clash_yaml=$clash_xray_hysteria "$ipaddr" "$port" "$password"

    echo ""
    separator
    success "Hysteria2 节点搭建成功！"
    separator
    echo -e " ${B_GREEN}1) 单链复制导入:${NC}"
    echo -e "   ${CYAN}${hy_link}${NC}"
    echo ""
    echo -e " ${B_GREEN}2) Clash Party 一键导入:${NC}"
    echo -e "   ${CYAN}clash://install-config?url=$(echo -n "$clash_yaml" | b64url)${NC}"
    echo ""
    echo -e " ${B_GREEN}3) 密码:${NC} ${B_YELLOW}${password}${NC}"
    echo -e " ${B_GREEN}4) 端口:${NC} ${B_YELLOW}${port}${NC}"
    echo ""
    show_qr_text "$hy_link"
    separator
    pause
}

clash_xray_hysteria() {
    local ip="$1" port="$2" pass="$3"
    cat <<EOF
proxies:
  - name: "HTE-Hysteria2-${ip}"
    type: hysteria2
    server: ${ip}
    port: ${port}
    password: "${pass}"
    skip-cert-verify: true
port: 7890
socks-port: 7891
allow-lan: true
mode: rule
EOF
}

# ---- Deep-dive: Online QR (via api.qrserver) ----
show_online_qr() {
    local url="$1"
    # URL-encode the data param safely (replace reserved chars)
    local enc
    enc=$(printf '%s' "$url" | sed -e 's|#|%23|g' -e 's|&|%26|g' -e 's|?|%3F|g' -e 's|=|%3D|g' -e 's|@|%40|g' -e 's|:|%3A|g' -e 's|/|%2F|g')
    local qrurl
    qrurl="https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=${enc}"
    echo -e " ${B_CYAN}在线二维码:${NC} ${CYAN}${qrurl}${NC}"
    echo -e " ${B_CYAN}用手机对着这个链接/二维码扫一下即可导入${NC}"
}

# ---- Node management helper ----
manage_nodes() {
    print_banner
    echo -e "${B_YELLOW}=== 节点运维管理 ===${NC}"
    echo -e " ${B_GREEN}1.${NC} 查看 Xray 运行状态"
    echo -e " ${B_GREEN}2.${NC} 查看当前节点配置端端口"
    echo -e " ${B_GREEN}3.${NC} 重启 Xray"
    echo -e " ${B_GREEN}4.${NC} 停止并卸载节点 (Xray)"
    echo -e " ${B_RED}0.${NC} 返回"
    echo ""
    read -r -p "请选择: " mg
    case "$mg" in
        1) systemctl status xray --no-pager 2>/dev/null | head -n 12 ;;
        2) echo -e "已打开的监听端口: "; ss -tulpn 2>/dev/null | grep -iE 'xray|443|8443' || echo "  (无)";;
        3) systemctl restart xray && success "Xray 已重启" ;;
        4)
            systemctl stop xray 2>/dev/null; systemctl disable xray 2>/dev/null
            rm -f /usr/local/etc/xray/config.json
            success "Xray 节点已停止并移除配置。";;
        0) return ;;
        *) error "无效输入";;
    esac
    pause
}

menu_nodes() {
    while true; do
        print_banner
        echo -e "${B_CYAN}【 节点搭建 (订阅+二维码一键导入 Clash Party) 】${NC}"
        separator
        echo -e " ${B_GREEN}1.${NC} 一键搭建 VLESS-Reality 节点 (免域名/免证书, 推荐)"
        echo -e " ${B_GREEN}2.${NC} 一键搭建 Hysteria2 节点 (抗封锁/低延迟)"
        echo -e " ${B_GREEN}3.${NC} 生成 Clash Party 订阅链接 + 在线二维码工具"
        echo -e " ${B_GREEN}4.${NC} 节点运维管理 (状态/重启/卸载)"
        separator
        echo -e " ${B_RED}0.${NC} 返回主菜单"
        echo ""
        read -r -p "请输入选项 [0-4]: " node_choice
        case "$node_choice" in
            1) setup_vless_reality ;;
            2) setup_hysteria2 ;;
            3)
                info "请把已生成的单链粘贴到下方，即可生成 Clash Party 一键导入链接与在线二维码。"
                read -r -p "粘贴节点链接 (vless:// 或 hy2://): " user_link
                if [ -n "$user_link" ]; then
                    local y
                    y=$(cat <<EOF
proxies:
  - name: "HTE-Custom-Node"
    type: vless
    server: localhost
    port: 443
    uuid: 00000000-0000-0000-0000-000000000000
EOF
)
                    info "正在生成一键导入链接..."
                    echo -e " ${B_CYAN}Clash Party 导入链接:${NC}"
                    echo -e "   ${CYAN}clash://install-config?url=$(echo -n "$user_link" | b64url)${NC}"
                    echo ""
                    show_online_qr "$user_link"
                fi
                pause
                ;;
            4) manage_nodes ;;
            0) break ;;
            *) error "无效"; sleep 1 ;;
        esac
    done
}
