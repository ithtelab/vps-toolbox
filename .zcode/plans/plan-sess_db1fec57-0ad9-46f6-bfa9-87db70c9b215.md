# 黑天鹅工具箱 全面 Bug 修复计划

## 核心问题诊断（用户报告的全球 Ping 全不可达）
- **根因**：`run_global_ping` 中使用的目标 IP 均为 **`.1` 结尾的网段网关地址**（如 `103.200.96.1`、`139.162.65.1`、`45.79.64.1`…）。路由器/网关默认**不响应 ICMP echo**，因此所有目标全部超时，表格整列显示「不可达 / 100%」。
- **修复策略（两层保障）**：
  1. 将目标替换为**保证响应 ICMP 的公共 Anycast / 公共 DNS 服务器 IP**（如 `1.1.1.1`、`8.8.8.8`、`223.5.5.5`、`9.9.9.9`、`114.114.114.114`、`208.67.222.222`）并按香港/东京/新加坡/美西/美东/法兰克福/伦敦分区标注。
  2. 为每个目标增加 **TCP 延迟回退**（`curl --connect-timeout` 测连接耗时），当主机屏蔽 ICMP 时仍能量出延迟，彻底避免再次出现「全部不可达」的假死表格。

## 全量代码审查清单（本轮将一并修复）
| 文件 / 函数 | 发现的问题 | 修复方案 |
|---|---|---|
| **bench.sh `run_global_ping`** | 目标为 `.1` 网关 IP，不响应 ICMP | 替换为可靠 Anycast 目标 + TCP 回退；修正表格与 `pause` 返回 |
| **clean.sh `launch_realtime_monitor`** | `apt...` / `[yum]\|\|[dnf] &&` 依赖运算符优先级，脆弱 | 改写为明确的 `case`/`if` 判断包管理器后再安装 |
| **security.sh `enable_syn_protection`** | 每次运行重复追加相同 sysctl 配置 | 追加前先 `sed -i` 去重已有键，再写入 |
| **security.sh `change_ssh_port`** | `grep ssh` 端口检测可能误匹配 | 收紧为正则 `grep -E '(sshd\|sshd:)'` 并校验 |
| **proxy.sh `install_socks5`/`install_clash_party`** | 二进制下载多架构/多镜像仍不够稳健 | 校验下载非空、架构正常后再 `chmod`，成功即 break（局部已做，予以加固） |
| **helper.sh `run_remote_script`** | 可能遇到 CRLF/BOM 导致 bash 异常 | 下载后统一 `sed -i 's/\r$//'` 归一化 |

## 涉及文件
- `modules/bench.sh`
- `modules/clean.sh`
- `modules/security.sh`
- `modules/proxy.sh`
- `utils/helper.sh`

## 不改动
- `main.sh` 主入口（已含 `set +e`、防缓存下载、`load_modules`+`exec` 热重载，均已验证正确）
- 广告 Banner、菜单架构、README、赞助商信息

## 验证方式
- 本地全部脚本 `bash -n` 语法检查
- 通过 `64.83.11.191`（Ubuntu 24.04）实机联调 ping 修复结果，并清理测试残留
- 推送到 GitHub 后，用户在主菜单 `u` 热重载即可验证