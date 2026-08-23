# Windows Secure Toolkit - 项目总结与维护记录

## 1. 项目概览

本项目面向 Windows 10/11 与 Windows Server，使用 CMD/BAT 作为入口、C# 作为核心。目标不是替代企业端点管理平台，而是把常见检查、保守配置、备份和恢复放在一个能看懂的本地工具里。

核心原则很简单：先读，后预览，再备份，最后才改。电脑如果已经够忙，就不要再给它一个惊喜。

## 2. 结构与职责

### CMD/BAT 入口

`win_secure.cmd` 负责切换 UTF-8 代码页、寻找已构建的 `WinSecure.exe`、在缺少构建输出时调用 `build.cmd`，并保留核心程序的退出码。

`win_secure.bat` 是兼容入口，转发到同目录的 CMD 主入口。

### C# 核心

`src/WinSecure.cs` 负责：

- 系统能力探测与只读审计；
- 注册表、Guest、SMBv1、RDP/NLA 和防火墙策略的备份与恢复；
- 保守基线的预览、确认、执行和逐项结果；
- Defender 扫描、DISM/SFC 验证、监听端口与版本检查；
- 只读 `doctor` 兼容性诊断及其 JSON 输出；
- 只读 `backups` 备份目录和清单状态查看；
- 交互菜单、命令行参数和无修改自检。

`src/WindowsSecureToolkit.csproj` 目标为 .NET Framework 4.8，避免给支持的 Windows 系统再塞一个常驻运行时。

## 3. 安全基线范围

首版只处理这些项目：

1. 全部 Windows 防火墙配置文件开关；
2. Defender 实时保护、PUA 防护，以及 Windows 客户端的网络保护审核模式；
3. UAC、管理员确认行为和安全桌面；
4. SMBv1 可选功能；
5. 本地 Guest 账户；
6. 已启用 RDP 场景下的 NLA；
7. AutoRun 策略。

恢复流程只恢复这些项目，不导入未知注册表键，不删除备份，不自动重启，也不尝试覆盖组织策略。

## 4. 质量控制

`scripts/Test-Repository.cmd` 在本机和 GitHub Actions 中执行同一套门禁：

- C# 构建；
- 核心自检；
- 真实 `cmd.exe` 入口；
- 版本、帮助和计划模式；
- 审计报告生成与 JSON 文件；
- `doctor` 人类可读和 `--json` 两种输出；
- `backups --json` 备份目录状态输出；
- 缺少恢复路径时的错误码；
- 不存在旧脚本核心和动态远程执行模式。

静态和烟雾检查通过，不等于所有 Windows 版本上的系统变更都已经实机验证。发布说明会区分这两件事。

## 5. 版本与发布规则

- 版本遵循语义化版本：`MAJOR.MINOR.PATCH`；
- `src/WinSecure.cs`、`CHANGELOG.md` 和 Git 标签必须一致；
- 发布前必须在干净工作树运行 `scripts\\Test-Repository.cmd`；
- 发布说明必须列明真实验证范围；
- 变更按真实工作拆分为分支和提交，不为了制造活跃度批量创建空分支。

## 6. 后续方向

- 扩展真实 Windows Server 版本测试矩阵；
- 让 `doctor` 输出成为问题报告前的统一环境快照；
- 为审计 JSON 提供稳定 schema 与兼容性测试；
- 增加由用户明确选择的单项配置，而不是扩大默认基线；
- 根据真实 Issue、PR 和运行反馈调整检查项；
- 为 Release 提供可追溯的编译附件，并保留源代码构建路径。
