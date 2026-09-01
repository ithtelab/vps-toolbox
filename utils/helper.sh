#!/usr/bin/env bash
# ==============================================================================
# Linux VPS Toolbox - Helper & Dependency Management
# ==============================================================================

# Check Root Privileges
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "\033[0;31m[ERROR] 当前脚本需要 root 权限运行，请使用 sudo -i 或切换为 root 用户重试。\033[0m"
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

# Safely download and run a remote script with fallback mirrors
# Prevents executing Cloudflare Challenge HTML / WAF error pages
run_remote_script() {
    local tmp_script="/tmp/remote_script_$$.sh"
    rm -f "$tmp_script"

    for url in "$@"; do
        if [ -z "$url" ]; then
            continue
        fi

        if curl -fsSL --connect-timeout 6 --max-time 60 "$url" -o "$tmp_script" 2>/dev/null || \
           wget -q --no-check-certificate --timeout=15 "$url" -O "$tmp_script" 2>/dev/null; then
            # Verify the downloaded file is a valid text/bash script and NOT an HTML / Cloudflare Challenge page
            if [ -s "$tmp_script" ] && ! head -n 5 "$tmp_script" | grep -qiE "<!DOCTYPE|<html|<head|Just a moment"; then
                chmod +x "$tmp_script"
                bash "$tmp_script"
                local exit_code=$?
                rm -f "$tmp_script"
                return $exit_code
            fi
        fi
    done

    error "远程脚本拉取失败（可能因节点网络受阻或被上游拦截），请稍后重试！"
    rm -f "$tmp_script"
    return 1
}
