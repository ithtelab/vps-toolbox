#!/usr/bin/env bash
# ==============================================================================
# Linux VPS Toolbox - System & Hardware Detection
# ==============================================================================

# OS & Architecture Variables
export OS_NAME=""
export OS_VERSION=""
export OS_TYPE="" # debian, rhel, alpine, arch
export CPU_ARCH="" # x86_64, aarch64, arm, etc.
export PKG_MANAGER=""

detect_system() {
    # 1. Detect Architecture
    local arch
    arch=$(uname -m)
    case "$arch" in
        x86_64|amd64)
            CPU_ARCH="x86_64"
            ;;
        aarch64|arm64)
            CPU_ARCH="aarch64"
            ;;
        armv7l|armhf)
            CPU_ARCH="armv7"
            ;;
        i386|i686)
            CPU_ARCH="x86"
            ;;
        *)
            CPU_ARCH="$arch"
            ;;
    esac

    # 2. Detect Linux Distribution
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_NAME=$ID
        OS_VERSION=$VERSION_ID
    elif [ -f /etc/redhat-release ]; then
        OS_NAME="centos"
        OS_VERSION=$(grep -oE '[0-9]+(\.[0-9]+)?' /etc/redhat-release | head -n 1)
    elif [ -f /etc/issue ]; then
        if grep -qi "ubuntu" /etc/issue; then
            OS_NAME="ubuntu"
        elif grep -qi "debian" /etc/issue; then
            OS_NAME="debian"
        elif grep -qi "centos" /etc/issue; then
            OS_NAME="centos"
        fi
    fi

    case "$OS_NAME" in
        debian|ubuntu|deepin|linuxmint|kali)
            OS_TYPE="debian"
            PKG_MANAGER="apt"
            ;;
        centos|rhel|almalinux|rocky|fedora|oracle|amzn)
            OS_TYPE="rhel"
            if command -v dnf >/dev/null 2>&1; then
                PKG_MANAGER="dnf"
            else
                PKG_MANAGER="yum"
            fi
            ;;
        alpine)
            OS_TYPE="alpine"
            PKG_MANAGER="apk"
            ;;
        arch|manjaro)
            OS_TYPE="arch"
            PKG_MANAGER="pacman"
            ;;
        *)
            OS_TYPE="unknown"
            PKG_MANAGER="unknown"
            ;;
    esac
}

get_cpu_info() {
    local cpu_model
    cpu_model=$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | awk -F: '{print $2}' | sed 's/^[ \t]*//')
    [ -z "$cpu_model" ] && cpu_model=$(lscpu 2>/dev/null | grep 'Model name' | awk -F: '{print $2}' | sed 's/^[ \t]*//')
    [ -z "$cpu_model" ] && cpu_model="未知 CPU"
    local cpu_cores
    cpu_cores=$(grep -c 'processor' /proc/cpuinfo 2>/dev/null || echo 1)
    echo "${cpu_model} (${cpu_cores} 核心, ${CPU_ARCH})"
}

get_mem_info() {
    local mem_total
    mem_total=$(free -m 2>/dev/null | awk '/Mem:/ {print $2}')
    local mem_used
    mem_used=$(free -m 2>/dev/null | awk '/Mem:/ {print $3}')
    if [ -n "$mem_total" ] && [ -n "$mem_used" ]; then
        echo "${mem_used} MB / ${mem_total} MB"
    else
        echo "未知"
    fi
}

get_swap_info() {
    local swap_total
    swap_total=$(free -m 2>/dev/null | awk '/Swap:/ {print $2}')
    local swap_used
    swap_used=$(free -m 2>/dev/null | awk '/Swap:/ {print $3}')
    if [ -n "$swap_total" ] && [ "$swap_total" -gt 0 ]; then
        echo "${swap_used} MB / ${swap_total} MB"
    else
        echo "未开启"
    fi
}

get_disk_info() {
    df -h / 2>/dev/null | awk 'NR==2 {print $3 " / " $2 " (" $5 ")"}'
}

get_virt_type() {
    local virt="未知"
    if command -v systemd-detect-virt >/dev/null 2>&1; then
        virt=$(systemd-detect-virt 2>/dev/null)
    elif [ -f /proc/user_beancounters ]; then
        virt="OpenVZ"
    elif [ -d /proc/xen ]; then
        virt="Xen"
    elif grep -q "QEMU" /proc/cpuinfo 2>/dev/null; then
        virt="KVM"
    fi
    echo "$virt"
}

get_ip_info() {
    local ip
    ip=$(curl -s4m 3 https://api.ipify.org || curl -s4m 3 https://ip.sb || echo "未知")
    echo "$ip"
}
