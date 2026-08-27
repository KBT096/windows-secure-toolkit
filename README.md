# Windows Secure Toolkit

[![CI](https://github.com/KBT096/windows-secure-toolkit/actions/workflows/ci.yml/badge.svg)](https://github.com/KBT096/windows-secure-toolkit/actions/workflows/ci.yml)
[![Latest Release](https://img.shields.io/github/v/release/KBT096/windows-secure-toolkit?display_name=tag&sort=semver)](https://github.com/KBT096/windows-secure-toolkit/releases/latest)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![C%23](https://img.shields.io/badge/C%23-.NET%20Framework%204.8-512BD4.svg)](https://dotnet.microsoft.com/)

Windows 的安全设置有点像家里的电箱：平时没人想看，真出问题又希望它有记录。

当前版本：`1.3.3`。

这个小工具从 CMD/BAT 进去，用 C# 做检查、预览、备份和恢复。它不负责把电脑变成“绝对安全”，只负责把常见的几件事做得清楚一点。

## 核心架构与功能

- 只读审计：防火墙、Defender、UAC、SMBv1、Guest、RDP/NLA、AutoRun、更新服务和待重启状态；
- 生成 Markdown 和 JSON 报告；
- 预览一套保守基线，确认以后才应用；
- 应用前保存清单、SHA-256 和防火墙策略；
- 在同一台电脑上校验后恢复备份；
- 只读列出本机备份目录，并显示清单和 SHA-256 状态；
- Defender 快速扫描、DISM/SFC 只读检查、TCP 监听端口查看；
- 本机兼容性诊断：平台、.NET Framework、WMI 和原生命令能力，支持 JSON 输出；
- 只查询 GitHub Release 版本，不下载脚本，更不会下载完就“相信它”。

## 注意事项

- 入站端口、RDP 和管理员账户由用户明确决定，工具不会代为开放或创建；
- 系统重启与 DISM/SFC 修复由用户决定，工具只执行检查和验证；
- 审计结果、用户名、IP 和其他本机数据只保存在本地，不上传；
- 组织策略、MDM 和安全产品保留对系统设置的控制权；
- `Apply` / `Restore` 已由维护者在 Windows 10 和 Windows 11 上完成实机验证；其他版本、组织策略和安全产品环境仍需自行确认；
- GitHub Actions 主要覆盖构建和只读烟雾测试，不代表所有 Windows 版本或策略环境都已验证。

如果电脑由公司策略管理，本地设置可能在策略刷新后恢复；请以组织策略和后续审计结果为准。

## 📖📖 快速入门：如何配置与运行 Windows Secure Toolkit？

支持 Windows 10/11 和 Windows Server 2019/2022/2025。运行已编译版本只需要 .NET Framework 4.8；从源码构建需要 .NET 6 SDK 或更高版本。

### 第一步：准备工具并完成自检

不需要安装 SDK 时，打开[最新 Release](https://github.com/KBT096/windows-secure-toolkit/releases)，选择 Windows x64 压缩包，解压后进入目录。

从源码运行时，在项目目录打开 CMD：

```cmd
build.cmd
win_secure.cmd self-test
```

`self-test` 只检查程序和清单处理，不修改系统设置。

### 第二步：读取状态并预览计划

第一次使用先完成只读检查。下面的命令不会应用安全基线：

```cmd
win_secure.cmd doctor
win_secure.cmd audit
win_secure.cmd plan
```

`doctor` 检查系统兼容性，`audit` 生成 Markdown 和 JSON 报告，`plan` 显示将要处理的项目和可能的影响。

### 第三步：确认后应用设置

阅读计划并确认影响范围后，以管理员身份打开 CMD，再运行：

```cmd
win_secure.cmd apply
```

应用前会先创建备份并再次请求确认。程序不会自动开放入站端口、启用 RDP 或创建管理员账户。

### 第四步：需要时恢复备份

先查看备份目录和清单状态：

```cmd
win_secure.cmd backups
```

恢复操作需要管理员权限，并会校验备份清单、计算机名称和 SHA-256：

```cmd
win_secure.cmd restore "C:\ProgramData\WindowsSecureToolkit\Backups\20260818-120000"
```

## 命令

| 命令 | 说明 |
| --- | --- |
| `win_secure.cmd` | 打开菜单 |
| `win_secure.cmd audit [路径]` | 生成 Markdown + JSON 审计报告 |
| `win_secure.cmd plan` | 预览，不修改系统 |
| `win_secure.cmd apply [--yes]` | 备份并应用基线 |
| `win_secure.cmd restore <路径>` | 校验并恢复备份 |
| `win_secure.cmd backups [目录] [--json]` | 只读列出备份及清单状态 |
| `win_secure.cmd scan` | Defender 快速扫描 |
| `win_secure.cmd verify` | DISM/SFC 只读验证 |
| `win_secure.cmd ports` | TCP 监听端口 |
| `win_secure.cmd doctor [--json]` | 只读检查本机兼容性与依赖能力 |
| `win_secure.cmd update` | 查询最新 Release |
| `win_secure.cmd version` | 输出版本号 |
| `win_secure.cmd self-test` | 无修改自检 |

`win_secure.bat` 是兼容入口，功能和 `.cmd` 相同。

## 目录里有什么

- `src/WinSecure.cs`：核心实现；
- `src/WindowsSecureToolkit.csproj`：.NET Framework 4.8 项目文件；
- `build.cmd`：构建核心程序；
- `win_secure.cmd` / `win_secure.bat`：用户入口；
- `scripts/Test-Repository.cmd`：构建、入口和报告烟雾测试；
- `docs/THREAT_MODEL.md`：边界和威胁模型。
- `docs/WINDOWS_VALIDATION.md`：诊断命令与 Windows 验证矩阵。

## 参与和报告问题

- 普通问题请使用 [Issues](https://github.com/KBT096/windows-secure-toolkit/issues)；
- 可能暴露系统数据的问题请按照 [SECURITY.md](SECURITY.md) 私下报告；
- 提交代码前请阅读 [CONTRIBUTING.md](CONTRIBUTING.md)；
- 如果在 Windows 10/11 上遇到问题，请附上版本、Windows 版本/构建号、是否以管理员身份运行、完整命令和脱敏输出，不要上传备份或原始审计报告。

当前维护者：[@KBT096](https://github.com/KBT096)。

## 版权与组件声明

本项目自身代码遵循 [MIT License](LICENSE) 协议发布。构建目标使用 .NET Framework 4.8；运行时调用 `netsh`、`dism`、`sfc`、`netstat`、WMI 和 Microsoft Defender 等 Windows 系统组件，相关组件的授权和使用条件以 Microsoft Windows 许可条款为准。CI 使用 GitHub Actions 与固定提交的 `actions/checkout`，仅用于仓库验证，不随工具运行。本仓库不捆绑 YABS、NextTrace 或其他 VPS 探针组件。

## 许可证

本项目采用 MIT License。外部诊断工具仍分别受其上游许可证约束。
