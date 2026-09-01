#!/usr/bin/env bash
# ==============================================================================
# Linux VPS Toolbox - Color & UI Utilities
# ==============================================================================

# ANSI Color Codes
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[0;33m'
export BLUE='\033[0;34m'
export PURPLE='\033[0;35m'
export CYAN='\033[0;36m'
export WHITE='\033[0;37m'

# Bold Colors
export B_RED='\033[1;31m'
export B_GREEN='\033[1;32m'
export B_YELLOW='\033[1;33m'
export B_BLUE='\033[1;34m'
export B_PURPLE='\033[1;35m'
export B_CYAN='\033[1;36m'
export B_WHITE='\033[1;37m'

# Background & Reset
export BG_BLUE='\033[44;37m'
export BG_GREEN='\033[42;37m'
export BG_RED='\033[41;37m'
export NC='\033[0m'

# Print Helpers
info() {
    echo -e "${B_BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${B_GREEN}[OK]${NC} $1"
}

warn() {
    echo -e "${B_YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${B_RED}[ERROR]${NC} $1"
}

separator() {
    echo -e "${B_CYAN}----------------------------------------------------------------------${NC}"
}

double_separator() {
    echo -e "${B_CYAN}======================================================================${NC}"
}

print_banner() {
    clear
    echo -e "${B_CYAN}======================================================================${NC}"
    echo -e "       ${B_YELLOW}★ 黑天鹅 Linux 多功能综合运维与测评工具箱 (HTE-Box) ★${NC}"
    echo -e "${B_CYAN}----------------------------------------------------------------------${NC}"
    echo -e " ${B_PURPLE}【特约赞助】${NC} ${B_GREEN}爱维云官网:${NC} ${CYAN}https://lovevps.cn/${NC}"
    echo -e " ${YELLOW}美国双ISP住宅云主机 2核2GB 38元起 首单享七五折 续费同价 支持24小时全额退款${NC}"
    echo -e "${B_CYAN}======================================================================${NC}"
}

pause() {
    echo ""
    echo -e "${B_YELLOW}按回车键 [Enter] 返回菜单...${NC}"
    read -r -s -n 1
}
