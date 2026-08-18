# Windows Secure Toolkit

[![CI](https://github.com/KBT096/windows-secure-toolkit/actions/workflows/ci.yml/badge.svg)](https://github.com/KBT096/windows-secure-toolkit/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![C%23](https://img.shields.io/badge/C%23-.NET%20Framework%204.8-512BD4.svg)](https://dotnet.microsoft.com/)

Windows 的安全设置有点像家里的电箱：平时没人想看，真出问题又希望它有记录。

当前版本：`1.2.0`。

这个小工具从 CMD/BAT 进去，用 C# 做检查、预览、备份和恢复。它不负责把电脑变成“绝对安全”，只负责把常见的几件事做得清楚一点。

## 能做什么

- 只读审计：防火墙、Defender、UAC、SMBv1、Guest、RDP/NLA、AutoRun、更新服务和待重启状态；
- 生成 Markdown 和 JSON 报告；
- 预览一套保守基线，确认以后才应用；
- 应用前保存清单、SHA-256 和防火墙策略；
- 在同一台电脑上校验后恢复备份；
- Defender 快速扫描、DISM/SFC 只读检查、TCP 监听端口查看；
- 只查询 GitHub Release 版本，不下载脚本，更不会下载完就“相信它”。

## 不会做什么

- 不自动开放入站端口、打开 RDP 或创建管理员；
- 不自动重启，也不替你修复 DISM/SFC；
- 不上传审计结果、用户名、IP 或其他本机数据；
- 不绕过组织策略、MDM 或安全产品；
- 不把静态检查写成“所有 Windows 版本都实测通过”。

如果你的电脑由公司策略管理，策略可能在下一次刷新时把本地设置改回去。这不是程序闹脾气，是 Windows 的工作方式。

## 快速开始

支持 Windows 10/11 和 Windows Server 2019/2022/2025。运行已编译版本只需要 .NET Framework 4.8；从源码构建需要 .NET 6 SDK 或更高版本。

```cmd
build.cmd
win_secure.cmd self-test
win_secure.cmd audit
win_secure.cmd plan
```

第一次使用建议只读审计，然后看计划：

```cmd
win_secure.cmd audit
win_secure.cmd plan
```

确认影响范围并以管理员身份打开 CMD 后，才运行：

```cmd
win_secure.cmd apply
```

恢复示例：

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
| `win_secure.cmd scan` | Defender 快速扫描 |
| `win_secure.cmd verify` | DISM/SFC 只读验证 |
| `win_secure.cmd ports` | TCP 监听端口 |
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

## 验证范围

本机 Windows 11 专业工作站版 build 26200 已验证：C# 构建、CMD/BAT 启动、版本、自检、审计、计划、报告生成、端口查看和 Release 检查。公开 GitHub Actions 也会在 Windows runner 上构建并运行烟雾测试。

实际修改系统的 Apply/Restore 流程没有在维护者机器上执行，因此发布说明不会把它写成已经覆盖所有环境。请先看计划，备份也别删，电脑通常不会因为你多看一眼就生气。

## 参与和报告问题

- 普通问题请使用 [Issues](https://github.com/KBT096/windows-secure-toolkit/issues)；
- 可能暴露系统数据的问题请按照 [SECURITY.md](SECURITY.md) 私下报告；
- 提交代码前请阅读 [CONTRIBUTING.md](CONTRIBUTING.md)。

当前维护者：[@KBT096](https://github.com/KBT096)。

## 许可证

[MIT License](LICENSE)。本项目与 Microsoft 没有隶属或认可关系。
