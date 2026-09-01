#!/usr/bin/env bash
# ==============================================================================
# Linux VPS Toolbox - Server Benchmark & Network Quality Module
# ==============================================================================

run_node_quality() {
    print_banner
    echo -e "${B_YELLOW}=== [1] NodeQuality (NQ) 综合质量测试 ===${NC}"
    info "正在拉取并执行 NodeQuality 权威测评..."
    bash <(curl -sL https://raw.githubusercontent.com/Aniverse/inexistence/master/tools/nodequality.sh) || \
    bash <(curl -sL https://cdn.jsdelivr.net/gh/Aniverse/inexistence@master/tools/nodequality.sh)
    pause
}

run_tcp_quality() {
    print_banner
    echo -e "${B_YELLOW}=== [2] TcpQuality (TQ) 三网回程与 TCP 质量测试 ===${NC}"
    info "正在拉取并执行 TcpQuality 网络质量测试..."
    bash <(curl -sL https://raw.githubusercontent.com/Aniverse/inexistence/master/tools/tcpquality.sh) || \
    bash <(curl -sL https://cdn.jsdelivr.net/gh/Aniverse/inexistence@master/tools/tcpquality.sh)
    pause
}

run_geekbench5() {
    print_banner
    echo -e "${B_YELLOW}=== [3] Geekbench 5 官方纯净跑分 (Linux) ===${NC}"
    info "检测系统架构: ${CPU_ARCH}"

    local gb5_dir="/tmp/geekbench5"
    rm -rf "$gb5_dir"
    mkdir -p "$gb5_dir"
    cd "$gb5_dir" || exit 1

    local download_url=""
    if [ "$CPU_ARCH" = "x86_64" ]; then
        download_url="https://cdn.geekbench.com/Geekbench-5.4.4-Linux.tar.gz"
    elif [ "$CPU_ARCH" = "aarch64" ]; then
        download_url="https://cdn.geekbench.com/Geekbench-5.4.4-LinuxARM.tar.gz"
    else
        error "Geekbench 5 暂不支持当前系统架构: ${CPU_ARCH} (仅支持 x86_64 / aarch64)"
        pause
        return
    fi

    info "正在下载官方 Geekbench 5 测试包..."
    if ! wget -q --no-check-certificate -O gb5.tar.gz "$download_url"; then
        error "Geekbench 5 下载失败，请检查网络连接。"
        pause
        return
    fi

    info "解压中..."
    tar -zxf gb5.tar.gz
    cd Geekbench-5.4.4-Linux* || cd Geekbench-5.4.4-LinuxARM* || {
        error "解压失败"
        pause
        return
    }

    echo ""
    info "正在启动 Geekbench 5 CPU 性能测试 (需要大约 2-5 分钟，请耐心等待)..."
    separator

    ./geekbench5 2>&1 | tee /tmp/gb5_result.log

    separator
    local score_url
    score_url=$(grep "https://browser.geekbench.com/v5/cpu/" /tmp/gb5_result.log | tail -n 1)
    if [ -n "$score_url" ]; then
        echo ""
        success "Geekbench 5 测试完成！"
        echo -e "${B_GREEN}★ 官方跑分结果在线链接:${NC} ${B_YELLOW}${score_url}${NC}"
    fi

    # Clean up
    cd /root || cd /tmp || true
    rm -rf "$gb5_dir" /tmp/gb5_result.log
    pause
}

run_unlock_test() {
    print_banner
    echo -e "${B_YELLOW}=== [4] IP 纯净度与流媒体解锁综合检测 ===${NC}"
    info "正在启动流媒体与 AI 服务解锁检测..."
    bash <(curl -L -s media.ispvps.com) || \
    bash <(curl -L -s https://raw.githubusercontent.com/lmc999/RegionRestrictionCheck/master/check.sh)
    pause
}

run_route_trace() {
    print_banner
    echo -e "${B_YELLOW}=== [5] 三网回程路由追踪 (NextTrace) ===${NC}"
    info "正在调用 NextTrace 快速追踪电信、联通、移动、教育网回程路由..."
    bash <(curl -N -sL https://raw.githubusercontent.com/sjlleo/nexttrace/main/nt_auto.sh) || \
    bash <(curl -N -sL https://ghproxy.com/https://raw.githubusercontent.com/sjlleo/nexttrace/main/nt_auto.sh)
    pause
}

run_speedtest() {
    print_banner
    echo -e "${B_YELLOW}=== [6] 国内三网多节点 Speedtest 测速 ===${NC}"
    info "正在启动多节点网络测速脚本..."
    bash <(curl -sL https://raw.githubusercontent.com/i-abc/Speedtest/main/speedtest.sh) || \
    bash <(curl -sL https://bench.im/speedtest)
    pause
}

run_yabs_bench() {
    print_banner
    echo -e "${B_YELLOW}=== [7] YABS (Yet-Another-Bench-Script) 综合性能测试 ===${NC}"
    info "正在执行 YABS (含 CPU/磁盘IO/网络)..."
    curl -sL yabs.sh | bash
    pause
}

run_fusion_monster() {
    print_banner
    echo -e "${B_YELLOW}=== [8] 融合怪全套综合测评脚本 ===${NC}"
    info "正在加载融合怪综合评测..."
    bash <(curl -sL https://raw.githubusercontent.com/spiritLHLS/ecs/main/ecs.sh) || \
    bash <(curl -sL https://gitlab.com/spiritysdx/ecs/-/raw/main/ecs.sh)
    pause
}

menu_bench() {
    while true; do
        print_banner
        echo -e "${B_CYAN}【 服务器性能与网络综合测评 】${NC}"
        separator
        echo -e " ${B_GREEN}1.${NC} NodeQuality (NQ) 综合质量测试"
        echo -e " ${B_GREEN}2.${NC} TcpQuality (TQ) 三网回程与 TCP 质量测试"
        echo -e " ${B_GREEN}3.${NC} Geekbench 5 官方 CPU 纯净跑分 (含官方链接)"
        echo -e " ${B_GREEN}4.${NC} IP 纯净度与流媒体/ChatGPT 解锁测试"
        echo -e " ${B_GREEN}5.${NC} 三网回程路由追踪 (NextTrace/BestTrace)"
        echo -e " ${B_GREEN}6.${NC} 国内三网节点 Speedtest 测速"
        echo -e " ${B_GREEN}7.${NC} YABS 国际经典性能与磁盘测速"
        echo -e " ${B_GREEN}8.${NC} 融合怪全功能一键深度体检"
        separator
        echo -e " ${B_RED}0.${NC} 返回主菜单"
        echo ""
        read -r -p "请输入选项 [0-8]: " bench_choice
        case "$bench_choice" in
            1) run_node_quality ;;
            2) run_tcp_quality ;;
            3) run_geekbench5 ;;
            4) run_unlock_test ;;
            5) run_route_trace ;;
            6) run_speedtest ;;
            7) run_yabs_bench ;;
            8) run_fusion_monster ;;
            0) break ;;
            *)
                echo -e "${RED}输入错误，请重新选择！${NC}"
                sleep 1
                ;;
        esac
    done
}
