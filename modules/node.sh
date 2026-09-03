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

# ---- Base64 URL-safe encoding ----
b64url() {
    base64 -w0 2>/dev/null | tr '+/' '-_' | tr -d '='
}
b64std() {
    base64 -w0 2>/dev/null
}

# ---- Install qrencode if missing (cross-package-manager) ----
qrencode_ensure() {
    command -v qrencode >/dev/null 2>&1 && return 0
    info "正在安装 qrencode (用于生成二维码)..."
    case "$PKG_MANAGER" in
        apt) apt-get install -y qrencode >/dev/null 2>&1 ;;
        dnf|yum) command -v dnf >/dev/null 2>&1 && dnf install -y qrencode >/dev/null 2>&1 || yum install -y qrencode >/dev/null 2>&1 ;;
        apk) apk add qrencode >/dev/null 2>&1 ;;
    esac
    command -v qrencode >/dev/null 2>&1
}

# ---- Render a REAL scannable QR code in the terminal (qrencode -t UTF8) ----
show_qr_terminal() {
    local text="$1"
    if command -v qrencode >/dev/null 2>&1; then
        echo ""
        echo -e " ${B_YELLOW}┌────────── 请用手机扫码导入 ──────────┐${NC}"
        echo -n "$text" | qrencode -t UTF8
        echo -e " ${B_YELLOW}└──────────────────────────────────────┘${NC}"
        return 0
    fi
    return 1
}

# ---- Terminal QR (real) + online QR fallback ----
show_qr_text() {
    local text="$1"
    if show_qr_terminal "$text"; then
        return 0
    fi
    # Fallback: online QR URL
    show_online_qr "$text"
}

# ---- Reliable Xray-core install (direct zip download, bypasses install-release.sh GitHub API 403) ----
install_xray_core() {
    local xray="/usr/local/bin/xray"
    [ -f "$xray" ] && return 0

    # Resolve latest Xray tag from API; fallback to a known-good version
    local tag
    tag=$(curl -sL --connect-timeout 8 --max-time 20 "https://api.github.com/repos/XTLS/Xray-core/releases/latest" 2>/dev/null | grep -m1 '"tag_name"' | sed 's/.*: "//;s/",//')
    [ -z "$tag" ] && tag="v26.3.27"

    # Map arch to Xray zip asset suffix (linux-64 / linux-arm64 / linux-arm32-v7a)
    local asfx="linux-64"
    if [ "$CPU_ARCH" = "aarch64" ]; then asfx="linux-arm64"; 
    elif [ "$CPU_ARCH" = "armv7" ]; then asfx="linux-arm32-v7a"; fi

    info "正在下载 Xray ${tag} (${asfx})..."
    local tmpdir
    tmpdir=$(mktemp -d 2>/dev/null || echo /tmp)
    local zipf="${tmpdir}/xray.zip"

    local url="https://github.com/XTLS/Xray-core/releases/download/${tag}/Xray-${asfx}.zip"
    if ! curl -fL --connect-timeout 15 --max-time 180 -o "$zipf" "$url" 2>/dev/null; then
        # ghproxy mirror fallback
        curl -fL --connect-timeout 15 --max-time 180 -o "$zipf" "https://ghproxy.com/${url}" 2>/dev/null || true
    fi
    [ -s "$zipf" ] || { error "Xray 下载失败，请检查网络。"; rm -rf "$tmpdir"; return 1; }

    if command -v unzip >/dev/null 2>&1; then
        unzip -oq "$zipf" xray -d "$tmpdir" 2>/dev/null
    else
        python3 -c "import zipfile;zipfile.ZipFile('$zipf').extract('xray','$tmpdir')" 2>/dev/null || true
    fi
    [ -f "$tmpdir/xray" ] && install -m 0755 "$tmpdir/xray" "$xray"
    rm -rf "$tmpdir"

    if [ -f "$xray" ] && [ -s "$xray" ]; then
        chmod +x "$xray"
        success "Xray 安装成功: $($xray version 2>/dev/null | head -n1)"
        return 0
    fi
    error "Xray 安装失败，未找到 ${xray}。请检查网络后重试。"
    return 1
}

# ---- Reliable Hysteria 2 install (official binary) ----
install_hysteria_core() {
    local hy="/usr/local/bin/hysteria"
    [ -f "$hy" ] && return 0

    local asfx="amd64"
    if [ "$CPU_ARCH" = "aarch64" ]; then asfx="arm64";
    elif [ "$CPU_ARCH" = "armv7" ]; then asfx="arm"; fi

    info "正在下载 Hysteria 2 官方内核 (${asfx})..."
    local url="https://github.com/apernet/hysteria/releases/latest/download/hysteria-linux-${asfx}"
    if ! curl -fL --connect-timeout 15 --max-time 180 -o "$hy" "$url" 2>/dev/null; then
        curl -fL --connect-timeout 15 --max-time 180 -o "$hy" "https://ghproxy.com/${url}" 2>/dev/null || true
    fi
    [ -s "$hy" ] || { error "Hysteria 2 下载失败，请检查网络。"; return 1; }
    chmod +x "$hy"
    success "Hysteria 2 安装成功: $($hy version 2>/dev/null | head -n1)"
    return 0
}

# ---- Generate Vless Reality link ----
make_vless_link() {
    local addr="$1" port="$2" uuid="$3" sni="$4" pubkey="$5" shortid="$6" flow="$7"
    # vless://uuid@addr:port?encryption=none&security=reality&sni=SNI&fp=chrome&pbk=PUBKEY&sid=SHORTID&type=tcp&headerType=none&flow=xtls-rprx-vision#name
    printf 'vless://%s@%s:%s?encryption=none&security=reality&sni=%s&fp=chrome&pbk=%s&sid=%s&type=tcp&headerType=none&flow=%s#%s' \
        "$uuid" "$addr" "$port" "$sni" "$pubkey" "$shortid" "$flow" "HTE-${sni}"
}

# ---- Generate Vless Reality proxy block ----
vless_proxy_block() {
    local ip="$1" name="$2" sni="$3" portin="$4" uuid="$5" pubkey="$6" shortid="$7"
    cat <<EOF
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
EOF
}

# ---- Generate Hysteria2 proxy block ----
hysteria2_proxy_block() {
    local ip="$1" name="$2" port="$3" pass="$4"
    cat <<EOF
  - name: "${name}"
    type: hysteria2
    server: ${ip}
    port: ${port}
    password: "${pass}"
    skip-cert-verify: true
EOF
}

# ---- Generate Clash YAML from vless link (standalone fallback) ----
vless_to_clash() {
    local ip="$1" name="$2" sni="$3" portin="$4" uuid="$5" pubkey="$6" shortid="$7"
    cat <<EOF
port: 7890
socks-port: 7891
allow-lan: true
mode: rule
log-level: info

proxies:
$(vless_proxy_block "$ip" "$name" "$sni" "$portin" "$uuid" "$pubkey" "$shortid")

proxy-groups:
  - name: "节点选择"
    type: select
    proxies:
      - "${name}"
      - DIRECT

rules:
  - MATCH,节点选择
EOF
}

# ---- Generate Hysteria2 Clash YAML (standalone fallback) ----
clash_xray_hysteria() {
    local ip="$1" port="$2" pass="$3"
    local name="HTE-Hysteria2-${ip}"
    cat <<EOF
port: 7890
socks-port: 7891
allow-lan: true
mode: rule
log-level: info

proxies:
$(hysteria2_proxy_block "$ip" "$name" "$port" "$pass")

proxy-groups:
  - name: "节点选择"
    type: select
    proxies:
      - "${name}"
      - DIRECT

rules:
  - MATCH,节点选择
EOF
}

# ---- Print port / sanity ----
valid_port() {
    [[ "$1" =~ ^[0-9]+$ ]] && [ "$1" -ge 1 ] && [ "$1" -le 65535 ]
}

# ---- URL encode helper ----
url_encode() {
    local string="${1}"
    local strlen=${#string}
    local encoded=""
    local pos c o
    for (( pos=0 ; pos<strlen ; pos++ )); do
        c=${string:$pos:1}
        case "$c" in
            [-_.~a-zA-Z0-9] ) o="${c}" ;;
            * )               printf -v o '%%%02X' "'$c"
        esac
        encoded+="${o}"
    done
    echo "${encoded}"
}

# ---- Append or register a node into the Clash subscription pool ----
register_clash_node() {
    local node_name="$1"
    local node_yaml_block="$2"
    local sub_dir="/var/www/hte_sub"
    local pool_file="${sub_dir}/nodes_pool.conf"
    mkdir -p "$sub_dir"

    # Remove existing node with same name if any
    if [ -f "$pool_file" ]; then
        python3 -c "
fname = '${pool_file}'
nname = '${node_name}'
try:
    with open(fname, 'r') as f:
        content = f.read()
    blocks = content.split('###NODE_START###')
    kept = []
    for b in blocks:
        if not b.strip(): continue
        lines = b.strip().split('\n')
        if lines[0].strip() != nname:
            kept.append(b.strip())
    with open(fname, 'w') as f:
        for k in kept:
            f.write('###NODE_START###\n' + k + '\n')
except Exception:
    pass
" 2>/dev/null || true
    fi

    # Append current node
    {
        echo "###NODE_START###"
        echo "${node_name}"
        echo "${node_yaml_block}"
    } >> "$pool_file"

    # Rebuild multi-node clash.yaml
    python3 -c "
import os
pool_file = '${pool_file}'
out_file = '${sub_dir}/clash.yaml'
proxies = []
proxy_names = []

if os.path.exists(pool_file):
    with open(pool_file, 'r') as f:
        content = f.read()
    blocks = content.split('###NODE_START###')
    for b in blocks:
        if not b.strip(): continue
        lines = b.strip().split('\n')
        name = lines[0].strip()
        yaml_lines = lines[1:]
        if name and yaml_lines:
            proxy_names.append(name)
            proxies.append('\n'.join(yaml_lines))

if proxies:
    with open(out_file, 'w') as f:
        f.write('''port: 7890
socks-port: 7891
allow-lan: true
mode: rule
log-level: info

proxies:
''')
        for p in proxies:
            f.write(p + '\n')
        f.write('''
proxy-groups:
  - name: \"节点选择\"
    type: select
    proxies:
''')
        for n in proxy_names:
            f.write(f'      - \"{n}\"\n')
        f.write('''      - DIRECT

rules:
  - MATCH,节点选择
''')
" 2>/dev/null || true

    start_sub_server
}

# ---- Start a persistent background HTTP subscription server for Clash YAML ----
start_sub_server() {
    local sub_port=20808
    local sub_dir="/var/www/hte_sub"
    mkdir -p "$sub_dir"

    # Ensure Python3 is available (for minimal OS images)
    if ! command -v python3 >/dev/null 2>&1 && ! command -v python >/dev/null 2>&1; then
        info "正在安装 python3 (用于订阅托管服务)..."
        case "$PKG_MANAGER" in
            apt) apt-get update -y >/dev/null 2>&1 && apt-get install -y python3 >/dev/null 2>&1 ;;
            dnf|yum) yum install -y python3 >/dev/null 2>&1 || dnf install -y python3 >/dev/null 2>&1 ;;
            apk) apk add python3 >/dev/null 2>&1 ;;
        esac
    fi

    local py_bin=""
    if command -v python3 >/dev/null 2>&1; then
        py_bin=$(command -v python3)
    elif command -v python >/dev/null 2>&1; then
        py_bin=$(command -v python)
    fi

    # Prefer systemd service for permanence (won't die on SSH exit)
    if command -v systemctl >/dev/null 2>&1 && [ -n "$py_bin" ]; then
        cat <<EOF > /etc/systemd/system/hte-sub.service
[Unit]
Description=HTE Clash Subscription HTTP Server
After=network.target

[Service]
Type=simple
WorkingDirectory=${sub_dir}
ExecStart=${py_bin} -m http.server ${sub_port}
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload 2>/dev/null || true
        systemctl enable hte-sub >/dev/null 2>&1 || true
        systemctl restart hte-sub 2>/dev/null || true
    elif [ -n "$py_bin" ]; then
        nohup "$py_bin" -m http.server "$sub_port" --directory "$sub_dir" >/dev/null 2>&1 &
    fi

    open_port "$sub_port" tcp
}

# ---- Deep-dive: One-click VLESS Reality Node Setup ----
setup_vless_reality() {
    print_banner
    echo -e "${B_YELLOW}=== [1] 一键搭建 VLESS-Reality 节点 (小白向) ===${NC}"
    info "VLESS-Reality：无需域名、无需证书、抗封锁强，直接生成可用节点"

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

    local default_port=443
    if ss -tulpn 2>/dev/null | grep -qE ':(443)\b'; then
        warn "检测到 443 端口已被占用（例如已有 Nginx/宝塔/Web服务）！"
        default_port=8443
        if ss -tulpn 2>/dev/null | grep -qE ':(8443)\b'; then
            default_port=2053
        fi
        info "已为您自动推荐空闲备用端口: ${default_port}"
    fi

    local port=443
    read -r -p "请输入节点端口 [默认 ${default_port}]: " port
    port=${port:-$default_port}
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

    # 2. Install Xray-core — direct zip download (avoids install-release.sh GitHub API 403)
    install_xray_core || { pause; return; }
    local xray="/usr/local/bin/xray"

    # 3. Generate Reality keypair (xray generate must run once)
    info "正在生成 Reality 密钥对（x25519）..."
    local keypair
    keypair=$($xray x25519 2>/dev/null)
    local private_key
    private_key=$(echo "$keypair" | awk -F': ' '/PrivateKey:/ {print $2}' | tr -d ' \r')
    local public_key
    public_key=$(echo "$keypair" | awk -F': ' '/Password \(PublicKey\):/ {print $2}' | tr -d ' \r')

    # Validate a real X25519 key: exactly 43-char base64url
    if ! [[ "$private_key" =~ ^[A-Za-z0-9_-]{43}$ ]] || ! [[ "$public_key" =~ ^[A-Za-z0-9_-]{43}$ ]] || [ -z "$public_key" ] || [ -z "$private_key" ]; then
        error "无法生成有效的 Reality 密钥对。停止搭建以避免生成不可用节点。"
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

    # 6. Register node into multi-node subscription pool & generate Clash YAML
    local node_link
    node_link=$(make_vless_link "$ipaddr" "$port" "$uuid" "$sni" "$public_key" "$shortid" "$flow")
    local name="HTE-VLESS-${ipaddr}"
    name="${name//[^A-Za-z0-9-]/_}"

    local pblock
    pblock=$(vless_proxy_block "$ipaddr" "$name" "$sni" "$port" "$uuid" "$public_key" "$shortid")
    register_clash_node "$name" "$pblock"
    local http_sub_url="http://${ipaddr}:20808/clash.yaml"

    echo ""
    separator
    success "VLESS-Reality 节点搭建成功！节点已加入 Clash 聚合订阅池！"
    separator
    echo -e " ${B_GREEN}★ 方法一：复制 VLESS 节点单链（最简单推荐）${NC}"
    echo -e "   ${CYAN}${node_link}${NC}"
    echo -e "   ${WHITE}【导入方式】复制上方单链 -> 打开 Clash Party / Clash Verge / v2rayN -> 点击【代理/节点】-> 点击【从剪贴板导入】即可！${NC}"
    echo ""
    echo -e " ${B_GREEN}★ 方法二：Clash 多节点聚合订阅链接（自动托管配置文件）${NC}"
    echo -e "   ${CYAN}${http_sub_url}${NC}"
    echo -e "   ${WHITE}【导入方式】复制上方 http 链接 -> 打开 Clash Party -> 点击【配置/订阅】-> 粘贴到【订阅 URL】即可！${NC}"
    echo ""
    echo -e " ${B_GREEN}★ 方法三：手机扫码导入（二维码已包含完整节点配置）${NC}"
    qrencode_ensure
    show_qr_text "$node_link"
    echo ""
    echo -e " ${B_YELLOW}⚠️  【云服务器重要提醒】如果您使用的是 腾讯云/阿里云/华为云/甲骨文/AWS 等云服务器：${NC}"
    echo -e " ${B_YELLOW}    请务必前往网页控制台，在【安全组 / 防火墙】中放行 TCP 端口 20808 (订阅) 与 ${port} (节点)！${NC}"
    echo -e " ${B_YELLOW}    否则外网将无法拉取订阅或连接节点。${NC}"
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

    # Install Hysteria 2 official binary
    install_hysteria_core || { pause; return; }
    local hy="/usr/local/bin/hysteria"

    # Generate self-signed TLS cert for Hysteria 2
    local hydir="/etc/hysteria"
    mkdir -p "$hydir"
    if [ ! -f "${hydir}/server.crt" ] || [ ! -f "${hydir}/server.key" ]; then
        info "正在生成自签名 SSL 证书..."
        openssl req -x509 -nodes -newkey ec:<(openssl ecparam -name prime256v1 2>/dev/null) \
            -keyout "${hydir}/server.key" -out "${hydir}/server.crt" \
            -subj "/CN=bing.com" -days 36500 >/dev/null 2>&1 || \
        openssl req -x509 -nodes -newkey rsa:2048 \
            -keyout "${hydir}/server.key" -out "${hydir}/server.crt" \
            -subj "/CN=bing.com" -days 36500 >/dev/null 2>&1
    fi

    # Write Hysteria 2 server config
    cat <<EOF > "${hydir}/config.yaml"
listen: :${port}
tls:
  cert: ${hydir}/server.crt
  key: ${hydir}/server.key
auth:
  type: password
  password: ${password}
masquerade:
  type: file
  file:
    dir: /var/www/html
EOF

    # Write systemd service unit
    cat <<EOF > /etc/systemd/system/hysteria-server.service
[Unit]
Description=Hysteria 2 Server Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/hysteria server --config /etc/hysteria/config.yaml
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload 2>/dev/null || true
    systemctl restart hysteria-server 2>/dev/null || systemctl start hysteria-server 2>/dev/null || {
        error "Hysteria 2 启动失败，请检查 ${hydir}/config.yaml"; pause; return;
    }
    systemctl enable hysteria-server >/dev/null 2>&1 || true
    open_port "$port" udp

    # Hysteria2 URI: hy2://password@ip:port?insecure=1#name
    local hy_link
    hy_link="hy2://${password}@${ipaddr}:${port}?insecure=1#HTE-Hysteria2-${ipaddr}"
    hy_link="${hy_link// /%20}"

    local name="HTE-Hysteria2-${ipaddr}"
    local pblock
    pblock=$(hysteria2_proxy_block "$ipaddr" "$name" "$port" "$password")
    register_clash_node "$name" "$pblock"
    local http_sub_url="http://${ipaddr}:20808/clash.yaml"

    echo ""
    separator
    success "Hysteria 2 节点搭建成功！节点已加入 Clash 聚合订阅池！"
    separator
    echo -e " ${B_GREEN}★ 方法一：Hysteria 2 节点单链（直接复制导入）${NC}"
    echo -e "   ${CYAN}${hy_link}${NC}"
    echo ""
    echo -e " ${B_GREEN}★ 方法二：Clash 多节点聚合订阅链接${NC}"
    echo -e "   ${CYAN}${http_sub_url}${NC}"
    echo ""
    echo -e " ${B_GREEN}密码:${NC} ${B_YELLOW}${password}${NC} | ${B_GREEN}端口:${NC} ${B_YELLOW}${port}${NC}"
    echo ""
    echo -e " ${B_CYAN}★ 手机扫码即可导入 Clash Party / 客户端★${NC}"
    qrencode_ensure
    show_qr_text "$hy_link"
    echo ""
    echo -e " ${B_YELLOW}⚠️  【云服务器重要提醒】如果您使用的是 腾讯云/阿里云/华为云/甲骨文/AWS 等云服务器：${NC}"
    echo -e " ${B_YELLOW}    请务必前往网页控制台，在【安全组 / 防火墙】中放行 TCP 端口 20808 (订阅) 与 UDP 端口 ${port} (Hysteria2 节点)！${NC}"
    echo -e " ${B_YELLOW}    否则外网将无法拉取订阅或连接节点。${NC}"
    separator
    pause
}

# ---- Deep-dive: Online QR (via api.qrserver) ----
show_online_qr() {
    local url="$1"
    local enc
    enc=$(printf '%s' "$url" | sed -e 's|#|%23|g' -e 's|&|%26|g' -e 's|?|%3F|g' -e 's|=|%3D|g' -e 's|@|%40|g' -e 's|:|%3A|g' -e 's|/|%2F|g')
    local qrurl
    qrurl="https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=${enc}"
    echo -e " ${B_CYAN}备用在线二维码网址:${NC} ${CYAN}${qrurl}${NC}"
}

# ---- Node management helper ----
manage_nodes() {
    print_banner
    echo -e "${B_YELLOW}=== 节点运维管理 ===${NC}"
    echo -e " ${B_GREEN}1.${NC} 查看 Xray 运行状态"
    echo -e " ${B_GREEN}2.${NC} 查看 Hysteria 2 运行状态"
    echo -e " ${B_GREEN}3.${NC} 查看当前节点配置与端口监听"
    echo -e " ${B_GREEN}4.${NC} 重启所有节点服务"
    echo -e " ${B_GREEN}5.${NC} 停止并彻底卸载所有节点服务"
    echo -e " ${B_RED}0.${NC} 返回"
    echo ""
    read -r -p "请选择: " mg
    case "$mg" in
        1) systemctl status xray --no-pager 2>/dev/null | head -n 15 ;;
        2) systemctl status hysteria-server --no-pager 2>/dev/null | head -n 15 ;;
        3)
            echo -e "已打开的监听端口: "
            ss -tulpn 2>/dev/null | grep -iE 'xray|hysteria|443|8443|20808' || echo "  (无)"
            echo ""
            [ -f /var/www/hte_sub/clash.yaml ] && cat /var/www/hte_sub/clash.yaml
            ;;
        4)
            systemctl restart xray 2>/dev/null && success "Xray 已重启"
            systemctl restart hysteria-server 2>/dev/null && success "Hysteria 2 已重启"
            systemctl restart hte-sub 2>/dev/null && success "订阅服务已重启"
            ;;
        5)
            systemctl stop xray 2>/dev/null; systemctl disable xray 2>/dev/null
            systemctl stop hysteria-server 2>/dev/null; systemctl disable hysteria-server 2>/dev/null
            systemctl stop hte-sub 2>/dev/null; systemctl disable hte-sub 2>/dev/null
            pkill -f "http.server 20808" 2>/dev/null || true
            rm -f /usr/local/etc/xray/config.json /etc/hysteria/config.yaml /var/www/hte_sub/clash.yaml /var/www/hte_sub/nodes_pool.conf
            success "所有节点及订阅服务已停止并清理配置。";;
        6)
            rm -f /var/www/hte_sub/nodes_pool.conf /var/www/hte_sub/clash.yaml
            success "Clash 订阅节点池已清空并重置。";;
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
        echo -e " ${B_GREEN}3.${NC} 导入已有单链生成二维码"
        echo -e " ${B_GREEN}4.${NC} 节点运维管理 (状态/重启/卸载)"
        separator
        echo -e " ${B_RED}0.${NC} 返回主菜单"
        echo ""
        read -r -p "请输入选项 [0-4]: " node_choice
        case "$node_choice" in
            1) setup_vless_reality ;;
            2) setup_hysteria2 ;;
            3)
                info "请把已生成的节点单链粘贴到下方，即可生成二维码。"
                read -r -p "粘贴节点链接 (vless:// 或 hy2://): " user_link
                if [ -n "$user_link" ]; then
                    echo ""
                    echo -e " ${B_CYAN}────────── 扫码导入 (手机 Clash Party 扫码) ──────────${NC}"
                    qrencode_ensure
                    show_qr_text "$user_link"
                    echo ""
                    echo -e " ${B_CYAN}也可直接复制该单链粘贴到 Clash Party 的【代理/节点】里导入。${NC}"
                else
                    error "未输入链接！"
                fi
                pause
                ;;
            4) manage_nodes ;;
            0) break ;;
            *) error "无效"; sleep 1 ;;
        esac
    done
}
