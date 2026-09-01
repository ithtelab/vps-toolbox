#!/usr/bin/env bash
# ==============================================================================
# Linux VPS Toolbox - Helper & Dependency Management
# ==============================================================================

# Check Root Privileges
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}[ERROR] 当前脚本需要 root 权限运行，请使用 sudo -i 或切换为 root 用户重试。${NC}"
        exit 1
    fi
}

# Install essential dependencies if missing
install_dependencies() {
    local missing_pkgs=()
    local required_cmds=("curl" "wget" "tar" "gzip" "jq" "cron")

    for cmd in "${required_cmds[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            case "$cmd" in
                cron)
                    if [ "$OS_TYPE" = "debian" ]; then
                        missing_pkgs+=("cron")
                    elif [ "$OS_TYPE" = "rhel" ]; then
                        missing_pkgs+=("crontabs")
                    fi
                    ;;
                *)
                    missing_pkgs+=("$cmd")
                    ;;
            esac
        fi
    done

    if [ ${#missing_pkgs[@]} -gt 0 ]; then
        info "正在安装基础必要依赖: ${missing_pkgs[*]} ..."
        case "$PKG_MANAGER" in
            apt)
                apt-get update -y -q >/dev/null 2>&1
                apt-get install -y -q "${missing_pkgs[@]}" >/dev/null 2>&1
                ;;
            dnf|yum)
                $PKG_MANAGER makecache -q >/dev/null 2>&1
                $PKG_MANAGER install -y -q "${missing_pkgs[@]}" >/dev/null 2>&1
                ;;
            apk)
                apk update >/dev/null 2>&1
                apk add --no-cache "${missing_pkgs[@]}" >/dev/null 2>&1
                ;;
            pacman)
                pacman -Sy --noconfirm "${missing_pkgs[@]}" >/dev/null 2>&1
                ;;
        esac
        success "基础依赖环境准备就绪"
    fi
}

# Open Firewall Port (Supports UFW, Firewalld, iptables)
open_port() {
    local port="$1"
    local proto="${2:-tcp}"

    if [ -z "$port" ]; then
        return
    fi

    # UFW
    if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
        ufw allow "${port}/${proto}" >/dev/null 2>&1
    fi

    # Firewalld
    if command -v firewall-cmd >/dev/null 2>&1 && systemctl is-active --quiet firewalld; then
        firewall-cmd --zone=public --add-port="${port}/${proto}" --permanent >/dev/null 2>&1
        firewall-cmd --reload >/dev/null 2>&1
    fi

    # iptables rule fallback
    if command -v iptables >/dev/null 2>&1; then
        iptables -I INPUT -p "$proto" --dport "$port" -j ACCEPT 2>/dev/null || true
    fi
}
