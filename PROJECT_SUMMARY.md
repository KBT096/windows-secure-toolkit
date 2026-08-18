# Windows Security & Management Toolkit - 项目总结与维护文档

## 1. 项目概览

本项目面向 Windows 10/11 与 Windows Server，提供一个以 CMD/BAT 为统一入口、以 Windows PowerShell 5.1 为能力层的安全审计与管理工具。首要目标不是替代企业安全基线或端点管理平台，而是把常见检查、保守配置、备份及恢复组织为可阅读、可验证、可维护的本地工作流。

### 核心实现原则

- **只读优先**：默认入口为审计和预览；改变系统状态的操作必须显式选择。
- **变更可回滚**：加固前记录原始值、导出防火墙策略并生成 SHA-256 校验；恢复仅接受同机与固定白名单字段。
- **失败可见**：单项失败必须返回真实状态，不以统一“完成”文案覆盖错误。
- **依赖最小化**：使用 Windows 自带 CMD、PowerShell、CIM、DISM、SFC、NetSecurity 与 Defender 命令。
- **远程内容不执行**：更新功能只比较 GitHub Release 版本，不下载后直接运行脚本。
- **兼容性克制**：首版不修改账户密码策略、NTLM、SMB 签名、Credential Guard、RDP 开关或入站端口等高兼容性风险设置。

## 2. 结构与职责

### CMD/BAT 入口

`win_secure.cmd` 负责：

- 将终端切换至 UTF-8 代码页；
- 检查 Windows PowerShell 是否存在；
- 把稳定、有限的子命令映射到核心脚本；
- 保留原始退出码，方便 CI、计划任务与外部调用判断结果。

`win_secure.bat` 是兼容入口，仅转发到同目录的 CMD 主入口。

### PowerShell 核心

`src/WinSecure.ps1` 负责：

- 系统能力探测与只读审计；
- 备份清单、哈希和恢复流程；
- 保守基线的预览、确认、执行和逐项结果；
- Defender 扫描、DISM/SFC 验证、监听端口与版本检查；
- 交互菜单和自动化参数。

### 质量控制

`scripts/Test-Repository.ps1` 在本机与 GitHub Actions 中执行相同门禁：

- PowerShell 全文件语法解析；
- Windows PowerShell 5.1 核心自检；
- 真实 `cmd.exe` 入口自检；
- `.cmd/.bat` UTF-8 无 BOM + CRLF；
- `.ps1` UTF-8 BOM + CRLF；
- 审计报告生成与 JSON 格式；
- 必需维护文件与本地链接；
- 远程内容管道执行等危险模式。

## 3. 安全基线范围

首版只处理下列项目：

1. 全部 Windows 防火墙配置文件开关；
2. Defender 实时保护、PUA 防护，以及 Windows 客户端的网络保护审核模式；
3. UAC、管理员确认行为和安全桌面；
4. SMBv1 可选功能；
5. 本地 Guest 账户；
6. 已启用 RDP 场景下的 NLA；
7. AutoRun 策略。

恢复流程只恢复这些项目，不导入未知注册表键，不删除备份，不自动重启，也不尝试覆盖组织策略。

## 4. 版本与发布规则

- 版本遵循语义化版本：`MAJOR.MINOR.PATCH`。
- `src/WinSecure.ps1` 中的版本号、`CHANGELOG.md` 和 Git 标签必须一致。
- 发布前必须在干净工作树运行 `scripts\Test-Repository.ps1`。
- 发布说明必须列明真实验证范围；CI 通过不能写成所有 Windows 版本实机通过。
- 发布包从 Git 标签生成，不提供无法追溯到提交的独立可执行文件。

## 5. 维护安全规则

- 不在仓库、Issue、日志或测试夹具中保存 API 密钥、令牌、真实公网 IP、组织名称或审计报告。
- 不把用户输入拼接进 `Invoke-Expression`、`cmd /c` 或远程下载执行链。
- 新增系统变更时，必须同步实现读取原值、备份、预览、应用、恢复和测试。
- 涉及兼容性风险的设置必须默认不启用，并在文档中解释影响。
- 安全问题使用 GitHub 私有漏洞报告；公开 Issue 不接收未脱敏的系统数据。

## 6. 后续方向

- 扩展真实 Windows Server 版本测试矩阵；
- 为审计 JSON 提供稳定 schema 与兼容性测试；
- 增加由用户明确选择的单项配置，而不是扩大默认基线；
- 根据真实 Issue、PR 和运行反馈调整检查项；
- 在获得维护需求和预算后，再引入受限、可审计的 PR 分类与发布辅助自动化。
