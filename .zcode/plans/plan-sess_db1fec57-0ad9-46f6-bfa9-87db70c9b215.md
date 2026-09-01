# 黑天鹅工具箱 功能审计 + Bug 修复 + 新功能增强计划

## 一、已有功能可用性结论
已逐项核对所有菜单选项 → 子模块函数 → 辅助函数的映射与定义，**全部 60+ 函数均有真实定义，无断裂入口、无未定义函数调用**。已在测试机验证 NQ / TQ / Geekbench / 全球 Ping / Socks5 均可正常运行。主菜单 1-6 / u / 0 路由全部正确。

## 二、确认的真实 Bug（需修复）
| 级别 | 文件:行 | 问题 | 影响 |
|---|---|---|---|
| 高 | bench.sh:120 | `grep -oP`（PCRE）在 Alpine/BusyBox 无此选项，而 Alpine 是声明支持的发行版 | 全球 Ping 在 Alpine 上静默失效 |
| 高 | bench.sh:129 | `date +%s%3N` 仅 GNU 支持，Alpine 退回整秒 → "ms" 实为秒 | Ping 结果单位错误 |
| 高 | docker.sh:65 | aaPanel 安装用**明文 HTTP** + 旧版 `install_6.0_en.sh` | 不安全 + 地址过时 |
| 中 | proxy.sh:37 / 128 | Gost 锁定 `rc10`（armv7 可能无包）、Mihomo 锁定旧 `1.18.7` | 部分架构安装失败 |
| 中 | docker.sh:74 | 菜单标"泛域名"但实现仅单域名 HTTP-01 | 与实际不符，不能签发泛域名 |

## 三、新增功能（复用现有子菜单，不新增顶层分类）
- `menu_security` 增加 `[7] setup_telegram_alerts`：Telegram 机器人推送 SSH 登录 / Fail2ban 封禁 / 磁盘>90% / 重启事件
- `menu_system` 增加 `[8] setup_auto_security_updates`：仅安全补丁自动更新、不强制重启
- `menu_clean` 增加 `[4] install_netdata`：可视实时监控面板
- `menu_clean` 增加 `[5] check_disk_health`：smartctl 自检 + 文件系统检查
- `menu_clean` 增加 `[6] snapshot_backup`：一键打包 /etc、包清单、cron、防火墙规则的快照与恢复

## 四、实施步骤
1. 修复 5 处确认 Bug（用 `awk`/`grep -oE` 替换 `-oP`；给 `%3N` 加回退；aaPanel 换 HTTPS 当前地址；修正菜单标签；Gost/Mihomo 加固 latest 回退与稳定 tag）。
2. 在对应模块新增 5 个功能函数与新菜单项。
3. `bash -n` 全量语法检查。
4. 同步到测试机 `64.83.11.191` 并对改动函数做冒烟测试，清理残留。
5. push 后 `git ls-remote` 确认提交真实落地（避免再出现"仓库未更新"问题）。

## 五、不改动
- 广告 Banner、菜单配色排版、README、赞助商信息（无功能性改需求）。