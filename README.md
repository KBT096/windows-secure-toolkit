# Windows Security & Management Toolkit

[![CI](https://github.com/KBT096/windows-secure-toolkit/actions/workflows/ci.yml/badge.svg)](https://github.com/KBT096/windows-secure-toolkit/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Windows PowerShell 5.1](https://img.shields.io/badge/Windows%20PowerShell-5.1%2B-5391FE.svg)](https://learn.microsoft.com/powershell/)

本项目为 Windows 10/11 与 Windows Server 提供本地安全审计、保守基线加固、配置备份及恢复能力。用户通过 `win_secure.cmd` 或 `win_secure.bat` 进入菜单，无需安装第三方运行时。

项目默认执行只读检查。需要管理员权限的设置变更会先展示影响范围、请求确认并创建可校验备份；脚本不会下载后直接执行远程代码，也不会自动重启计算机。

## 核心架构与功能

功能分为三个逻辑模块：安全状态审计、可回滚基线、系统维护诊断。

### 一、安全状态审计

- 检查 Windows 防火墙、Microsoft Defender、UAC、SMBv1、Guest 账户、RDP/NLA、BitLocker、安全启动与 Windows Update。
- 汇总本地管理员数量、待重启标记和 TCP 监听端口。
- 同时生成 Markdown 与 JSON 报告，便于人工复核、问题跟踪和后续自动化。
- 不把检查结果包装成“安全评分”，也不将本地配置快照表述为渗透测试或合规认证。

### 二、可回滚安全基线

- 开启域、专用和公用网络的 Windows 防火墙。
- 开启 Defender 实时保护与潜在有害应用（PUA）防护。
- 在 Windows 客户端将 Defender 网络保护设为审核模式，先收集兼容性证据；Windows Server 默认不修改该项。
- 开启 UAC 与安全桌面提示。
- 禁用 SMBv1、Guest 账户和所有驱动器的 AutoRun。
- 仅在 RDP 已启用时要求网络级别身份验证（NLA）。
- 应用前保存配置清单、SHA-256 校验文件和完整防火墙策略导出。

### 三、系统维护诊断

- 运行 Microsoft Defender 快速扫描。
- 使用 `DISM /ScanHealth` 与 `SFC /verifyonly` 执行只读系统验证。
- 列出 TCP 监听地址、端口、PID 与进程名称。
- 只查询 GitHub Release 元数据进行版本比较，不自动覆盖本地脚本。

## 安全边界

本工具不会：

- 绕过组织策略、篡改防护或端点管理平台；
- 自动开放入站端口、启用远程桌面或创建管理员账户；
- 自动修复 DISM/SFC 发现的问题；
- 上传审计结果、用户名、IP 地址或其他本机数据；
- 从短链接、动态脚本地址或未固定来源下载并执行代码；
- 承诺某一基线适合所有个人、企业、学校或生产环境。

CMD 入口只为新建的子 PowerShell 进程设置 `ExecutionPolicy Bypass`，不会写入 CurrentUser 或 LocalMachine 配置；由 Group Policy 设置的 MachinePolicy/UserPolicy 仍具有更高优先级。

详细边界见 [威胁模型](docs/THREAT_MODEL.md)。

## 部署与使用指南

### 系统要求

- Windows 10/11，或 Windows Server 2019/2022/2025；
- Windows PowerShell 5.1 或更高版本；
- 审计通常可使用标准权限；加固、恢复、Defender 扫描与系统验证需要管理员权限；
- 组织管理设备应先与管理员确认组策略、MDM 和安全产品的优先级。

首版验证范围：

| 环境 | 已验证 | 未验证 |
| --- | --- | --- |
| Windows 11 专业工作站版 build 26200 + Windows PowerShell 5.1 | CMD/BAT 启动、语法、自检、审计报告、监听端口、基线预览 | 实际应用与恢复 |
| GitHub Actions `windows-latest` | 首次推送后由公开 CI 记录 | 提权后的系统配置变更 |
| Windows 10 与 Windows Server 2019/2022/2025 | 目标兼容环境 | 首版尚无对应实机变更证据 |

未验证项目不会在发布说明中写成“已通过实机测试”。

### 下载

建议从仓库的 [Releases](https://github.com/KBT096/windows-secure-toolkit/releases) 页面下载带版本号的源代码包，解压后在本地运行。也可以使用 Git：

```powershell
git clone https://github.com/KBT096/windows-secure-toolkit.git
cd windows-secure-toolkit
```

### 第一次运行

先使用标准权限执行只读审计：

```cmd
win_secure.cmd audit
```

报告默认写入：

```text
%LOCALAPPDATA%\WindowsSecureToolkit\Reports
```

在应用设置之前，先预览变更：

```cmd
win_secure.cmd plan
```

确认兼容性后，以管理员身份打开 CMD 或 PowerShell，再执行：

```cmd
win_secure.cmd apply
```

备份默认写入：

```text
%ProgramData%\WindowsSecureToolkit\Backups
```

### 命令一览

| 命令 | 权限 | 行为 |
| --- | --- | --- |
| `win_secure.cmd` | 标准 | 打开交互菜单 |
| `win_secure.cmd audit [路径]` | 标准 | 生成 Markdown + JSON 审计报告 |
| `win_secure.cmd plan` | 标准 | 预览基线，不修改系统 |
| `win_secure.cmd apply` | 管理员 | 备份并交互式应用基线 |
| `win_secure.cmd restore "备份路径"` | 管理员 | 校验并恢复本工具管理的设置 |
| `win_secure.cmd scan` | 管理员 | 运行 Defender 快速扫描 |
| `win_secure.cmd verify` | 管理员 | 运行 DISM/SFC 只读验证 |
| `win_secure.cmd ports` | 标准 | 查看 TCP 监听端口 |
| `win_secure.cmd update` | 标准 | 查询最新 GitHub Release |
| `win_secure.cmd self-test` | 标准 | 运行无修改自检 |

### 恢复示例

恢复前不要修改 `manifest.json` 或 `manifest.sha256`：

```cmd
win_secure.cmd restore "C:\ProgramData\WindowsSecureToolkit\Backups\20260818-120000"
```

恢复只接受当前计算机生成、SHA-256 匹配且字段落在固定白名单内的清单；只处理本工具记录的设置，不删除备份，也不自动重启计算机。若系统由组策略或安全产品管理，策略可能在恢复后再次覆盖本地值。

## 验证

仓库测试同时覆盖 PowerShell 语法、Windows PowerShell 5.1 自检、真实 CMD 启动、中文批处理编码/换行、审计报告生成、必需文件与危险远程执行模式：

```powershell
.\scripts\Test-Repository.ps1
```

静态检查通过不等于所有 Windows 版本上的实际策略变更都已验证。发布说明会区分“CI 验证”和“真实 Windows 版本运行验证”。

## 贡献与安全报告

- 提交变更前请阅读 [贡献指南](CONTRIBUTING.md)。
- 普通问题可使用 [GitHub Issues](https://github.com/KBT096/windows-secure-toolkit/issues)。
- 漏洞或可能暴露系统数据的问题请按 [安全策略](SECURITY.md) 私下报告。
- 当前维护者：[@KBT096](https://github.com/KBT096)。

## 许可证

项目以 [MIT License](LICENSE) 发布。Windows、Microsoft Defender 和 PowerShell 是其各自权利人的商标或产品名称；本项目与 Microsoft 无隶属或认可关系。
