#!/usr/bin/env bash
# ==============================================================================
# 黑天鹅 Linux 多功能综合运维与测评工具箱 (HTE Linux All-in-One Toolbox)
# ==============================================================================

set -e

# Target installation directory on remote servers
TOOLBOX_DIR="/etc/vps-toolbox"
REPO_RAW_URL="https://raw.githubusercontent.com/ithtelab/vps-toolbox/main"
CDN_URL="https://cdn.jsdelivr.net/gh/ithtelab/vps-toolbox@main"
GH_PROXY="https://ghproxy.com/https://raw.githubusercontent.com/ithtelab/vps-toolbox/main"

# Download a file with anti-cache & multi-mirror fallback
download_file() {
    local rel_path="$1"
    local target_file="${TOOLBOX_DIR}/${rel_path}"
    local ts
    ts=$(date +%s)
    
    mkdir -p "$(dirname "$target_file")"
    
    # Try GitHub Raw (no-cache) -> jsDelivr CDN -> ghproxy
    if curl -fsSL -H 'Cache-Control: no-cache' "${REPO_RAW_URL}/${rel_path}?v=${ts}" -o "$target_file" 2>/dev/null; then
        return 0
    elif curl -fsSL "${CDN_URL}/${rel_path}?v=${ts}" -o "$target_file" 2>/dev/null; then
        return 0
    elif curl -fsSL "${GH_PROXY}/${rel_path}?v=${ts}" -o "$target_file" 2>/dev/null; then
        return 0
    fi
    return 1
}

# Check if running in a local full repo directory or via curl | bash
if [ -d "$(dirname "${BASH_SOURCE[0]}")/utils" ]; then
    BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
    # Running remotely via curl / pipe / process substitution
    echo -e "\033[1;34m[INFO]\033[0m 正在初始化黑天鹅 Linux 工具箱运行环境..."
    mkdir -p "${TOOLBOX_DIR}/utils" "${TOOLBOX_DIR}/modules"

    files=(
        "utils/colors.sh"
        "utils/sys_detect.sh"
        "utils/helper.sh"
        "modules/bench.sh"
        "modules/proxy.sh"
        "modules/system.sh"
        "modules/security.sh"
        "modules/docker.sh"
        "modules/clean.sh"
        "main.sh"
    )

    for f in "${files[@]}"; do
        download_file "$f" || true
    done

    chmod +x "${TOOLBOX_DIR}/main.sh"
    ln -sf "${TOOLBOX_DIR}/main.sh" /usr/local/bin/hte 2>/dev/null || true
    ln -sf "${TOOLBOX_DIR}/main.sh" /usr/local/bin/toolbox 2>/dev/null || true

    BASE_DIR="${TOOLBOX_DIR}"
fi

# Source Utility Libraries
# shellcheck source=utils/colors.sh
[ -f "${BASE_DIR}/utils/colors.sh" ] && . "${BASE_DIR}/utils/colors.sh"
# shellcheck source=utils/sys_detect.sh
[ -f "${BASE_DIR}/utils/sys_detect.sh" ] && . "${BASE_DIR}/utils/sys_detect.sh"
# shellcheck source=utils/helper.sh
[ -f "${BASE_DIR}/utils/helper.sh" ] && . "${BASE_DIR}/utils/helper.sh"

# Source Business Modules
# shellcheck source=modules/bench.sh
[ -f "${BASE_DIR}/modules/bench.sh" ] && . "${BASE_DIR}/modules/bench.sh"
# shellcheck source=modules/proxy.sh
[ -f "${BASE_DIR}/modules/proxy.sh" ] && . "${BASE_DIR}/modules/proxy.sh"
# shellcheck source=modules/system.sh
[ -f "${BASE_DIR}/modules/system.sh" ] && . "${BASE_DIR}/modules/system.sh"
# shellcheck source=modules/security.sh
[ -f "${BASE_DIR}/modules/security.sh" ] && . "${BASE_DIR}/modules/security.sh"
# shellcheck source=modules/docker.sh
[ -f "${BASE_DIR}/modules/docker.sh" ] && . "${BASE_DIR}/modules/docker.sh"
# shellcheck source=modules/clean.sh
[ -f "${BASE_DIR}/modules/clean.sh" ] && . "${BASE_DIR}/modules/clean.sh"

# Global Init
init_environment() {
    check_root
    detect_system
    install_dependencies
    if [ ! -f /usr/local/bin/hte ] && [ -f "${TOOLBOX_DIR}/main.sh" ]; then
        ln -sf "${TOOLBOX_DIR}/main.sh" /usr/local/bin/hte 2>/dev/null || true
    fi
}

# Self update with cache-busting & instant process reload
update_toolbox() {
    echo ""
    info "正在穿透 CDN 缓存拉取最新代码与所有模块..."
    mkdir -p "${TOOLBOX_DIR}/utils" "${TOOLBOX_DIR}/modules"
    
    local update_files=(
        "utils/colors.sh"
        "utils/sys_detect.sh"
        "utils/helper.sh"
        "modules/bench.sh"
        "modules/proxy.sh"
        "modules/system.sh"
        "modules/security.sh"
        "modules/docker.sh"
        "modules/clean.sh"
        "main.sh"
    )

    local fail_count=0
    for f in "${update_files[@]}"; do
        if ! download_file "$f"; then
            fail_count=$((fail_count + 1))
        fi
    done

    chmod +x "${TOOLBOX_DIR}/main.sh"
    ln -sf "${TOOLBOX_DIR}/main.sh" /usr/local/bin/hte 2>/dev/null || true
    ln -sf "${TOOLBOX_DIR}/main.sh" /usr/local/bin/toolbox 2>/dev/null || true

    if [ "$fail_count" -eq 0 ]; then
        success "黑天鹅工具箱已成功更新至最新版本！正在立即重新载入..."
        sleep 1
        exec bash "${TOOLBOX_DIR}/main.sh"
    else
        warn "部分文件更新可能受网络阻碍，建议检查服务器网络。"
        pause
    fi
}

# Main Interactive Menu
main_menu() {
    while true; do
        print_banner
        
        # System Overview Header
        echo -e " ${WHITE}系统:${NC} ${OS_NAME} ${OS_VERSION} (${CPU_ARCH}) | ${WHITE}虚拟化:${NC} $(get_virt_type) | ${WHITE}内核:${NC} $(uname -r | cut -d- -f1)"
        echo -e " ${WHITE}CPU:${NC}  $(get_cpu_info)"
        echo -e " ${WHITE}内存:${NC} $(get_mem_info) | ${WHITE}Swap:${NC} $(get_swap_info) | ${WHITE}磁盘:${NC} $(get_disk_info)"
        echo -e " ${WHITE}网络:${NC} IP $(get_ip_info) | ${WHITE}BBR加速:${NC} $(get_bbr_status)"
        double_separator

        echo -e " ${B_GREEN}[1]${NC} ${B_WHITE}服务器性能与网络综合测评${NC}  ${PURPLE}(NQ, TQ, Geekbench 5, 流媒体, 路由, Ping)${NC}"
        echo -e " ${B_GREEN}[2]${NC} ${B_WHITE}代理与穿透/转发服务搭建${NC}   ${PURPLE}(Socks5 一键, Clash Party/Mihomo, Realm)${NC}"
        echo -e " ${B_GREEN}[3]${NC} ${B_WHITE}系统优化 / WARP / 一键DD重装${NC} ${PURPLE}(WARP双栈, DD纯净重装, BBR全家桶, Swap, DNS)${NC}"
        echo -e " ${B_GREEN}[4]${NC} ${B_WHITE}Docker 与常用运维环境部署${NC} ${PURPLE}(Docker, 哪吒探针, 1Panel, SSL证书)${NC}"
        echo -e " ${B_GREEN}[5]${NC} ${B_WHITE}VPS 安全加固与防护管理${NC}    ${PURPLE}(SSH改端口, 密钥登录, Fail2ban解封, 防SYN攻击)${NC}"
        echo -e " ${B_GREEN}[6]${NC} ${B_WHITE}系统深度清理与日常监控${NC}   ${PURPLE}(垃圾日志清理, 硬件查看, htop/iftop)${NC}"
        separator
        echo -e " ${B_YELLOW}[u]${NC} 更新脚本自身                  ${B_RED}[0]${NC} 退出工具箱"
        double_separator

        read -r -p "请输入对应的功能编号 [0-6 或 u]: " main_choice

        case "$main_choice" in
            1)
                menu_bench
                ;;
            2)
                menu_proxy
                ;;
            3)
                menu_system
                ;;
            4)
                menu_docker
                ;;
            5)
                menu_security
                ;;
            6)
                menu_clean
                ;;
            u|U)
                update_toolbox
                ;;
            0)
                echo ""
                echo -e "${B_GREEN}感谢使用 黑天鹅 Linux 多功能一体化工具箱，再见！${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}输入有误，请重新输入数字 0-6！${NC}"
                sleep 1
                ;;
        esac
    done
}

# Entrypoint
init_environment
main_menu
