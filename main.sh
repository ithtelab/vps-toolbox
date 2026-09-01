#!/usr/bin/env bash
# ==============================================================================
# Linux VPS All-in-One Toolbox (多功能服务器一体化综合工具箱)
# ==============================================================================

set -e

# Base directory
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
}

# Main Interactive Menu
main_menu() {
    while true; do
        print_banner
        
        # System Overview Header
        echo -e " ${WHITE}系统:${NC} ${OS_NAME} ${OS_VERSION} (${CPU_ARCH}) | ${WHITE}虚拟化:${NC} $(get_virt_type) | ${WHITE}内核:${NC} $(uname -r | cut -d- -f1)"
        echo -e " ${WHITE}CPU:${NC}  $(get_cpu_info)"
        echo -e " ${WHITE}内存:${NC} $(get_mem_info) | ${WHITE}Swap:${NC} $(get_swap_info) | ${WHITE}磁盘:${NC} $(get_disk_info)"
        double_separator

        echo -e " ${B_GREEN}[1]${NC} ${B_WHITE}服务器性能与网络综合测评${NC}  ${PURPLE}(NQ, TQ, Geekbench 5, 流媒体, 路由)${NC}"
        echo -e " ${B_GREEN}[2]${NC} ${B_WHITE}代理与穿透/转发服务搭建${NC}   ${PURPLE}(Socks5 一键, Clash Party/Mihomo, Realm)${NC}"
        echo -e " ${B_GREEN}[3]${NC} ${B_WHITE}系统底层与网络参数优化${NC}   ${PURPLE}(BBR 加速, Swap 调整, 极速换源, DNS)${NC}"
        echo -e " ${B_GREEN}[4]${NC} ${B_WHITE}Docker 与常用运维环境部署${NC} ${PURPLE}(Docker, 哪吒探针, 1Panel, SSL证书)${NC}"
        echo -e " ${B_GREEN}[5]${NC} ${B_WHITE}VPS 安全加固与防火墙管理${NC}  ${PURPLE}(SSH 改端口, 密钥登录, Fail2ban, 端口放行)${NC}"
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
                info "正在拉取最新脚本版本..."
                success "当前已是最新版本！"
                pause
                ;;
            0)
                echo ""
                echo -e "${B_GREEN}感谢使用 Linux VPS 多功能一体化工具箱，再见！${NC}"
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
