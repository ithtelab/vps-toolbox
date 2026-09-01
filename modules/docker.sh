#!/usr/bin/env bash
# ==============================================================================
# Linux VPS Toolbox - Docker & Application Deployment Module
# ==============================================================================

install_docker() {
    print_banner
    echo -e "${B_YELLOW}=== [1] Docker & Docker Compose 官方最新版一键安装 ===${NC}"
    info "正在检测并安装 Docker 官方环境..."
    
    # Use official get.docker.com with mirror support
    curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun 2>/dev/null || curl -fsSL https://get.docker.com | bash

    systemctl enable docker >/dev/null 2>&1
    systemctl start docker >/dev/null 2>&1

    if command -v docker >/dev/null 2>&1; then
        success "Docker 安装成功！版本: $(docker --version)"
    else
        error "Docker 安装失败，请检查系统网络与源配置。"
    fi
    pause
}

install_nezha() {
    print_banner
    echo -e "${B_YELLOW}=== [2] 哪吒探针 (Nezha) 一键安装管理 ===${NC}"
    info "正在拉取哪吒探针官方安装脚本..."
    run_remote_script \
        "https://cdn.jsdelivr.net/gh/nezhahq/scripts@main/install.sh" \
        "https://raw.githubusercontent.com/nezhahq/scripts/main/install.sh" \
        "https://ghproxy.com/https://raw.githubusercontent.com/nezhahq/scripts/main/install.sh"
    pause
}

install_1panel() {
    print_banner
    echo -e "${B_YELLOW}=== [3] 1Panel 新一代现代化运维面板 ===${NC}"
    info "正在拉取 1Panel 官方安装脚本..."
    run_remote_script \
        "https://resource.fit2cloud.com/1panel/package/quick_start.sh"
    pause
}

install_baota() {
    print_banner
    echo -e "${B_YELLOW}=== [4] 宝塔 Linux 运维面板一键安装 ===${NC}"
    echo -e " ${B_GREEN}1.${NC} 宝塔 Linux 面板官方正式版 (推荐国内/常规服务器)"
    echo -e " ${B_GREEN}2.${NC} 宝塔海外国际版 (aaPanel - 纯净国际版，无需绑定手机号)"
    echo -e " ${B_RED}0.${NC} 返回"
    echo ""
    read -r -p "请选择宝塔版本 [0-2]: " bt_choice

    case "$bt_choice" in
        1)
            info "正在拉取宝塔 Linux 官方正式版安装脚本..."
            if [ -f /usr/bin/curl ]; then
                curl -sSO https://download.bt.cn/install/install_panel.sh && bash install_panel.sh ed8484bec
            else
                wget -O install_panel.sh https://download.bt.cn/install/install_panel.sh && bash install_panel.sh ed8484bec
            fi
            ;;
        2)
            info "正在拉取 aaPanel 国际版官方安装脚本..."
            run_remote_script "http://www.aapanel.com/script/install_6.0_en.sh"
            ;;
        *)
            return
            ;;
    esac
    pause
}

install_acme_ssl() {
    print_banner
    echo -e "${B_YELLOW}=== [5] Acme.sh 免费 SSL 证书一键申请 ===${NC}"
    info "正在加载 Acme.sh 证书一键申请工具..."
    read -r -p "请输入要申请证书的域名 (例如: node.example.com): " domain
    read -r -p "请输入你的邮箱用于注册: " email

    if [ -z "$domain" ] || [ -z "$email" ]; then
        error "域名和邮箱不能为空！"
        pause
        return
    fi

    info "安装 Acme.sh 核心..."
    curl https://get.acme.sh | sh -s email="$email"
    ~/.acme.sh/acme.sh --upgrade --auto-upgrade

    info "开放 80 端口以完成 HTTP-01 验证..."
    open_port 80 tcp
    ~/.acme.sh/acme.sh --issue -d "$domain" --standalone

    local cert_dir="/etc/ssl/certs/${domain}"
    mkdir -p "$cert_dir"
    ~/.acme.sh/acme.sh --install-cert -d "$domain" \
        --key-file       "${cert_dir}/privkey.pem" \
        --fullchain-file "${cert_dir}/fullchain.pem"

    success "SSL 证书申请并部署完成！"
    echo -e "证书公钥: ${B_YELLOW}${cert_dir}/fullchain.pem${NC}"
    echo -e "证书私钥: ${B_YELLOW}${cert_dir}/privkey.pem${NC}"
    pause
}

install_librespeed() {
    print_banner
    echo -e "${B_YELLOW}=== [6] 自建 Speedtest 网页测速节点 (LibreSpeed) ===${NC}"
    if ! command -v docker >/dev/null 2>&1; then
        error "未安装 Docker，正在先为您自动安装 Docker..."
        install_docker
    fi

    local speed_port
    read -r -p "请输入 Speedtest 网页访问端口 [默认 8989]: " speed_port
    speed_port=${speed_port:-8989}

    info "正在拉取并启动 LibreSpeed 容器..."
    docker run -d --name librespeed -p "${speed_port}:80" --restart always adolfintel/speedtest:latest

    open_port "$speed_port" tcp
    local ip
    ip=$(get_ip_info)

    success "LibreSpeed 测速网页部署成功！"
    echo -e "浏览器访问地址: ${B_GREEN}http://${ip}:${speed_port}${NC}"
    pause
}

menu_docker() {
    while true; do
        print_banner
        echo -e "${B_CYAN}【 容器与应用运维服务部署 】${NC}"
        separator
        echo -e " ${B_GREEN}1.${NC} 安装 Docker & Docker Compose (官方最新版)"
        echo -e " ${B_GREEN}2.${NC} 安装 哪吒探针 (Nezha Agent/Dashboard)"
        echo -e " ${B_GREEN}3.${NC} 安装 1Panel 现代化开源运维面板"
        echo -e " ${B_GREEN}4.${NC} 安装 宝塔 Linux 面板 (官方正式版 / 国际版 aaPanel)"
        echo -e " ${B_GREEN}5.${NC} Acme.sh 免费泛域名 / 单域名 SSL 证书申请"
        echo -e " ${B_GREEN}6.${NC} 一键部署自建 Speedtest 测速网页 (LibreSpeed)"
        separator
        echo -e " ${B_RED}0.${NC} 返回主菜单"
        echo ""
        read -r -p "请输入选项 [0-6]: " doc_choice
        case "$doc_choice" in
            1) install_docker ;;
            2) install_nezha ;;
            3) install_1panel ;;
            4) install_baota ;;
            5) install_acme_ssl ;;
            6) install_librespeed ;;
            0) break ;;
            *)
                echo -e "${RED}输入错误，请重新选择！${NC}"
                sleep 1
                ;;
        esac
    done
}
