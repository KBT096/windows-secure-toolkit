using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Management;
using System.Net;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Security.Principal;
using System.ServiceProcess;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Win32;
using System.Web.Script.Serialization;

namespace WindowsSecureToolkit
{
    internal static class Program
    {
        private const string Version = "1.2.1";
        private const string ToolkitName = "Windows Secure Toolkit";
        private const string ReleaseApiUrl = "https://api.github.com/repos/KBT096/windows-secure-toolkit/releases/latest";
        private static readonly string[] RegistryAllowlist =
        {
            "HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\System\\EnableLUA",
            "HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\System\\ConsentPromptBehaviorAdmin",
            "HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\System\\PromptOnSecureDesktop",
            "HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\Explorer\\NoDriveTypeAutoRun",
            "HKLM\\SYSTEM\\CurrentControlSet\\Control\\Terminal Server\\WinStations\\RDP-Tcp\\UserAuthentication",
            "HKLM\\SOFTWARE\\Microsoft\\Windows Defender\\Windows Defender Exploit Guard\\Network Protection\\EnableNetworkProtection"
        };
        private static readonly JavaScriptSerializer Json = new JavaScriptSerializer { MaxJsonLength = int.MaxValue };
        private static bool noColor;

        private static int Main(string[] args)
        {
            try
            {
                Console.OutputEncoding = Encoding.UTF8;
                Console.InputEncoding = Encoding.UTF8;
            }
            catch
            {
                // Some redirected consoles do not allow changing the encoding.
            }

            CliOptions options;
            try
            {
                options = CliOptions.Parse(args);
                noColor = options.NoColor;
            }
            catch (ArgumentException ex)
            {
                Message("错误", ex.Message);
                ShowHelp();
                return 2;
            }

            try
            {
                switch (options.Action)
                {
                    case "menu": return ShowMenu();
                    case "audit": return RunAudit(options.ReportPath);
                    case "apply": return RunApply(options.DryRun, options.Yes);
                    case "restore":
                        if (string.IsNullOrWhiteSpace(options.BackupPath))
                        {
                            Message("错误", "restore 需要备份目录或 manifest.json 路径。");
                            return 2;
                        }
                        return RunRestore(options.BackupPath);
                    case "scan": return RunDefenderScan();
                    case "verify": return RunSystemVerify();
                    case "ports": return ShowListeningPorts();
                    case "doctor": return RunDoctor(options.JsonOutput);
                    case "update": return CheckForUpdate();
                    case "version": Console.WriteLine(Version); return 0;
                    case "self-test": return RunSelfTest();
                    case "help": ShowHelp(); return 0;
                    default:
                        Message("错误", "未知命令：" + options.Action);
                        ShowHelp();
                        return 2;
                }
            }
            catch (Exception ex)
            {
                Message("错误", ex.Message);
                return 1;
            }
        }

        private static void Message(string level, string text)
        {
            ConsoleColor old = Console.ForegroundColor;
            if (!noColor)
            {
                if (level == "错误") Console.ForegroundColor = ConsoleColor.Red;
                else if (level == "警告") Console.ForegroundColor = ConsoleColor.Yellow;
                else if (level == "完成") Console.ForegroundColor = ConsoleColor.Green;
                else if (level == "计划") Console.ForegroundColor = ConsoleColor.Cyan;
            }
            Console.WriteLine("[" + level + "] " + text);
            if (!noColor) Console.ForegroundColor = old;
        }

        private static void Section(string title)
        {
            Console.WriteLine();
            Console.WriteLine("================================================================");
            Console.WriteLine("  " + title);
            Console.WriteLine("================================================================");
        }

        private static void ShowHelp()
        {
            Console.WriteLine(ToolkitName + " v" + Version);
            Console.WriteLine();
            Console.WriteLine("用法：win_secure.cmd <命令> [选项]");
            Console.WriteLine();
            Console.WriteLine("  menu                         打开交互菜单");
            Console.WriteLine("  audit [报告目录或 .md]       生成只读 Markdown + JSON 报告");
            Console.WriteLine("  plan                         预览基线，不修改系统");
            Console.WriteLine("  apply [--yes]                备份并交互式应用基线");
            Console.WriteLine("  restore <备份目录或清单>      校验并恢复本工具管理的设置");
            Console.WriteLine("  scan                         运行 Defender 快速扫描");
            Console.WriteLine("  verify                       运行 DISM/SFC 只读验证");
            Console.WriteLine("  ports                        查看 TCP 监听端口");
            Console.WriteLine("  doctor [--json]             运行本机兼容性诊断（只读）");
            Console.WriteLine("  update                       查询 GitHub 最新 Release");
            Console.WriteLine("  version                      输出版本号");
            Console.WriteLine("  self-test                    运行无修改自检");
            Console.WriteLine("  help                         显示本帮助");
            Console.WriteLine();
            Console.WriteLine("它会先看一眼，再问你一声，最后才考虑改系统。没有远程脚本下载执行。 ");
        }

        private static int ShowMenu()
        {
            Section(ToolkitName + " v" + Version);
            Console.WriteLine("1. 只读安全审计");
            Console.WriteLine("2. 预览安全基线");
            Console.WriteLine("3. 应用安全基线（需要管理员）");
            Console.WriteLine("4. 恢复备份");
            Console.WriteLine("5. Defender 快速扫描");
            Console.WriteLine("6. DISM/SFC 只读验证");
            Console.WriteLine("7. 查看监听端口");
            Console.WriteLine("8. 检查版本");
            Console.WriteLine("9. 自检");
            Console.WriteLine("10. 本机兼容性诊断（只读）");
            Console.WriteLine("0. 退出");
            Console.Write("请选择：");
            string choice = Console.ReadLine();
            switch (choice)
            {
                case "1": return RunAudit(null);
                case "2": return RunApply(true, false);
                case "3": return RunApply(false, false);
                case "4":
                    Console.Write("备份路径：");
                    return RunRestore(Console.ReadLine());
                case "5": return RunDefenderScan();
                case "6": return RunSystemVerify();
                case "7": return ShowListeningPorts();
                case "8": return CheckForUpdate();
                case "9": return RunSelfTest();
                case "10": return RunDoctor(false);
                case "0": return 0;
                default: Message("错误", "没有这个选项。"); return 2;
            }
        }

        private sealed class CliOptions
        {
            public string Action = "menu";
            public string BackupPath;
            public string ReportPath;
            public bool Yes;
            public bool DryRun;
            public bool NoColor;
            public bool JsonOutput;

            public static CliOptions Parse(string[] args)
            {
                var result = new CliOptions();
                if (args == null || args.Length == 0) return result;
                int index = 0;
                string command = args[index];
                if (command.Equals("--action", StringComparison.OrdinalIgnoreCase) || command.Equals("-Action", StringComparison.OrdinalIgnoreCase))
                {
                    if (++index >= args.Length) throw new ArgumentException("--action 缺少值。");
                    command = args[index++];
                }
                else index++;

                result.Action = NormalizeAction(command);
                if (result.Action == "audit" && index < args.Length && !args[index].StartsWith("-")) result.ReportPath = args[index++];
                if (result.Action == "restore" && index < args.Length && !args[index].StartsWith("-")) result.BackupPath = args[index++];

                while (index < args.Length)
                {
                    string arg = args[index++];
                    if (arg.Equals("--yes", StringComparison.OrdinalIgnoreCase) || arg.Equals("-Yes", StringComparison.OrdinalIgnoreCase)) result.Yes = true;
                    else if (arg.Equals("--dry-run", StringComparison.OrdinalIgnoreCase) || arg.Equals("-DryRun", StringComparison.OrdinalIgnoreCase)) result.DryRun = true;
                    else if (arg.Equals("--no-color", StringComparison.OrdinalIgnoreCase) || arg.Equals("-NoColor", StringComparison.OrdinalIgnoreCase)) result.NoColor = true;
                    else if (arg.Equals("--json", StringComparison.OrdinalIgnoreCase) || arg.Equals("-Json", StringComparison.OrdinalIgnoreCase)) result.JsonOutput = true;
                    else if (arg.Equals("--backup-path", StringComparison.OrdinalIgnoreCase) || arg.Equals("-BackupPath", StringComparison.OrdinalIgnoreCase))
                    {
                        if (index >= args.Length) throw new ArgumentException(arg + " 缺少路径。");
                        result.BackupPath = args[index++];
                    }
                    else if (arg.Equals("--report-path", StringComparison.OrdinalIgnoreCase) || arg.Equals("-ReportPath", StringComparison.OrdinalIgnoreCase))
                    {
                        if (index >= args.Length) throw new ArgumentException(arg + " 缺少路径。");
                        result.ReportPath = args[index++];
                    }
                    else if (arg.Equals("--help", StringComparison.OrdinalIgnoreCase) || arg.Equals("-h", StringComparison.OrdinalIgnoreCase)) result.Action = "help";
                    else throw new ArgumentException("无法识别选项：" + arg);
                }
                if (result.Action == "plan") { result.Action = "apply"; result.DryRun = true; }
                return result;
            }

            private static string NormalizeAction(string value)
            {
                if (string.IsNullOrWhiteSpace(value)) return "menu";
                string action = value.Trim().ToLowerInvariant();
                if (action == "--help" || action == "-h") return "help";
                if (action == "defenderquickscan" || action == "defender-scan") return "scan";
                if (action == "systemverify") return "verify";
                if (action == "listeningports") return "ports";
                if (action == "updatecheck") return "update";
                if (action == "selftest") return "self-test";
                string[] known = { "menu", "audit", "apply", "plan", "restore", "scan", "verify", "ports", "doctor", "update", "version", "self-test", "help" };
                if (!known.Contains(action)) throw new ArgumentException("未知命令：" + value);
                return action;
            }
        }

        private sealed class ProcessResult
        {
            public int ExitCode;
            public string Stdout = string.Empty;
            public string Stderr = string.Empty;
            public bool Started;
        }

        private static ProcessResult RunNative(string fileName, string arguments, int timeoutMilliseconds = 600000)
        {
            var result = new ProcessResult();
            using (var process = new Process())
            {
                process.StartInfo = new ProcessStartInfo
                {
                    FileName = fileName,
                    Arguments = arguments ?? string.Empty,
                    UseShellExecute = false,
                    CreateNoWindow = true,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    StandardOutputEncoding = Encoding.UTF8,
                    StandardErrorEncoding = Encoding.UTF8
                };
                try
                {
                    result.Started = process.Start();
                }
                catch (Exception ex)
                {
                    result.Stderr = ex.Message;
                    result.ExitCode = -1;
                    return result;
                }

                Task<string> stdout = process.StandardOutput.ReadToEndAsync();
                Task<string> stderr = process.StandardError.ReadToEndAsync();
                if (!process.WaitForExit(timeoutMilliseconds))
                {
                    try { process.Kill(); } catch { }
                    result.ExitCode = 124;
                    result.Stdout = stdout.GetAwaiter().GetResult();
                    result.Stderr = stderr.GetAwaiter().GetResult();
                    return result;
                }
                Task.WaitAll(stdout, stderr);
                result.ExitCode = process.ExitCode;
                result.Stdout = stdout.Result ?? string.Empty;
                result.Stderr = stderr.Result ?? string.Empty;
                return result;
            }
        }

        private static string Quote(string value)
        {
            if (value == null) return "\"\"";
            return "\"" + value.Replace("\"", "\\\"") + "\"";
        }

        private sealed class RegistryLocation
        {
            public RegistryKey Root;
            public string SubKey;
        }

        private static RegistryLocation ParseRegistryPath(string fullPath)
        {
            if (string.IsNullOrWhiteSpace(fullPath)) throw new ArgumentException("注册表路径为空。");
            string normalized = fullPath.Replace('/', '\\');
            int separator = normalized.IndexOf('\\');
            string hive = separator < 0 ? normalized : normalized.Substring(0, separator);
            string subKey = separator < 0 ? string.Empty : normalized.Substring(separator + 1);
            RegistryKey root;
            if (hive.Equals("HKLM", StringComparison.OrdinalIgnoreCase) || hive.Equals("HKEY_LOCAL_MACHINE", StringComparison.OrdinalIgnoreCase)) root = Registry.LocalMachine;
            else if (hive.Equals("HKCU", StringComparison.OrdinalIgnoreCase) || hive.Equals("HKEY_CURRENT_USER", StringComparison.OrdinalIgnoreCase)) root = Registry.CurrentUser;
            else throw new ArgumentException("不支持的注册表配置单元：" + hive);
            return new RegistryLocation { Root = root, SubKey = subKey };
        }

        private sealed class RegistrySnapshot
        {
            public string Hive;
            public string SubKey;
            public string Name;
            public bool Exists;
            public string Kind;
            public int Value;

            public string FullPath { get { return Hive + "\\" + SubKey; } }
        }

        private static RegistrySnapshot ReadDword(string path, string name)
        {
            RegistryLocation location = ParseRegistryPath(path);
            var snapshot = new RegistrySnapshot
            {
                Hive = path.Split('\\')[0].ToUpperInvariant(),
                SubKey = location.SubKey,
                Name = name,
                Exists = false,
                Kind = "DWord",
                Value = 0
            };
            using (RegistryKey key = location.Root.OpenSubKey(location.SubKey, false))
            {
                if (key == null) return snapshot;
                object value = key.GetValue(name, null, RegistryValueOptions.DoNotExpandEnvironmentNames);
                if (value == null) return snapshot;
                RegistryValueKind kind = key.GetValueKind(name);
                if (kind != RegistryValueKind.DWord)
                {
                    snapshot.Exists = true;
                    snapshot.Kind = kind.ToString();
                    return snapshot;
                }
                snapshot.Exists = true;
                snapshot.Value = Convert.ToInt32(value);
                return snapshot;
            }
        }

        private static int? ReadDwordValue(string path, string name)
        {
            RegistrySnapshot snapshot = ReadDword(path, name);
            return snapshot.Exists && snapshot.Kind == "DWord" ? (int?)snapshot.Value : null;
        }

        private static void WriteDword(string path, string name, int value)
        {
            RegistryLocation location = ParseRegistryPath(path);
            using (RegistryKey key = location.Root.CreateSubKey(location.SubKey, true))
            {
                if (key == null) throw new InvalidOperationException("无法打开注册表项：" + path);
                key.SetValue(name, value, RegistryValueKind.DWord);
            }
        }

        private static void RestoreDword(RegistrySnapshot snapshot)
        {
            if (snapshot == null) throw new ArgumentNullException("snapshot");
            if (snapshot.Exists && snapshot.Kind != "DWord") throw new InvalidOperationException("备份中的注册表值不是 DWord：" + snapshot.FullPath + "\\" + snapshot.Name);
            RegistryLocation location = ParseRegistryPath(snapshot.FullPath);
            using (RegistryKey key = location.Root.OpenSubKey(location.SubKey, snapshot.Exists))
            {
                if (!snapshot.Exists)
                {
                    if (key != null) key.DeleteValue(snapshot.Name, false);
                    return;
                }
                if (key == null) throw new InvalidOperationException("无法打开注册表项：" + snapshot.FullPath);
                key.SetValue(snapshot.Name, snapshot.Value, RegistryValueKind.DWord);
            }
        }

        private sealed class GuestState
        {
            public string Name;
            public bool Disabled;
            public string Sid;
        }

        private static GuestState ReadGuestState()
        {
            try
            {
                using (var searcher = new ManagementObjectSearcher("root\\cimv2", "SELECT Name, Disabled, SID FROM Win32_UserAccount WHERE LocalAccount=True"))
                using (ManagementObjectCollection results = searcher.Get())
                {
                    foreach (ManagementObject item in results)
                    {
                        string sid = Convert.ToString(item["SID"]);
                        if (!string.IsNullOrWhiteSpace(sid) && sid.EndsWith("-501", StringComparison.OrdinalIgnoreCase))
                        {
                            return new GuestState
                            {
                                Name = Convert.ToString(item["Name"]),
                                Sid = sid,
                                Disabled = Convert.ToBoolean(item["Disabled"])
                            };
                        }
                    }
                }
            }
            catch
            {
                // A restricted WMI provider is reported as unavailable by the caller.
            }
            return null;
        }

        private static bool? ReadRdpEnabled()
        {
            int? deny = ReadDwordValue("HKLM\\SYSTEM\\CurrentControlSet\\Control\\Terminal Server", "fDenyTSConnections");
            return deny.HasValue ? (bool?)(deny.Value == 0) : null;
        }

        private static string ReadSmb1State()
        {
            ProcessResult result = RunNative("dism.exe", "/online /Get-FeatureInfo /FeatureName:SMB1Protocol /English /NoRestart", 120000);
            string text = (result.Stdout ?? string.Empty) + "\n" + (result.Stderr ?? string.Empty);
            Match match = Regex.Match(text, @"(?im)^\s*State\s*:\s*(?<state>[^\r\n]+)");
            if (!match.Success) return null;
            return match.Groups["state"].Value.Trim();
        }

        private static bool IsServerOperatingSystem()
        {
            try
            {
                using (var searcher = new ManagementObjectSearcher("root\\cimv2", "SELECT ProductType FROM Win32_OperatingSystem"))
                using (ManagementObjectCollection results = searcher.Get())
                {
                    ManagementObject item = results.Cast<ManagementObject>().FirstOrDefault();
                    if (item != null) return Convert.ToInt32(item["ProductType"]) != 1;
                }
            }
            catch { }
            return false;
        }

        private sealed class DefenderState
        {
            public bool? RealtimeProtection;
            public int? PuaProtection;
            public int? NetworkProtection;
            public bool? AntivirusEnabled;
        }

        private static DefenderState ReadDefenderState()
        {
            var state = new DefenderState();
            try
            {
                using (var searcher = new ManagementObjectSearcher("root\\Microsoft\\Windows\\Defender", "SELECT AMServiceEnabled, AntivirusEnabled, RealTimeProtectionEnabled FROM MSFT_MpComputerStatus"))
                using (ManagementObjectCollection results = searcher.Get())
                {
                    ManagementObject item = results.Cast<ManagementObject>().FirstOrDefault();
                    if (item != null)
                    {
                        state.RealtimeProtection = Convert.ToBoolean(item["RealTimeProtectionEnabled"]);
                        state.AntivirusEnabled = Convert.ToBoolean(item["AntivirusEnabled"]);
                    }
                }
            }
            catch { }

            try
            {
                using (var searcher = new ManagementObjectSearcher("root\\Microsoft\\Windows\\Defender", "SELECT PUAProtection, EnableNetworkProtection, DisableRealtimeMonitoring FROM MSFT_MpPreference"))
                using (ManagementObjectCollection results = searcher.Get())
                {
                    ManagementObject item = results.Cast<ManagementObject>().FirstOrDefault();
                    if (item != null)
                    {
                        if (item["PUAProtection"] != null) state.PuaProtection = Convert.ToInt32(item["PUAProtection"]);
                        if (item["EnableNetworkProtection"] != null) state.NetworkProtection = Convert.ToInt32(item["EnableNetworkProtection"]);
                        if (item["DisableRealtimeMonitoring"] != null) state.RealtimeProtection = !Convert.ToBoolean(item["DisableRealtimeMonitoring"]);
                    }
                }
            }
            catch { }
            return state;
        }

        private static void SetDefenderState(int? networkProtection)
        {
            using (var searcher = new ManagementObjectSearcher("root\\Microsoft\\Windows\\Defender", "SELECT * FROM MSFT_MpPreference"))
            using (ManagementObjectCollection results = searcher.Get())
            {
                ManagementObject item = results.Cast<ManagementObject>().FirstOrDefault();
                if (item == null) throw new InvalidOperationException("未找到 Microsoft Defender 配置提供程序。");
                ManagementBaseObject parameters = item.GetMethodParameters("Set");
                parameters["DisableRealtimeMonitoring"] = false;
                parameters["PUAProtection"] = (byte)1;
                if (networkProtection.HasValue) parameters["EnableNetworkProtection"] = (byte)networkProtection.Value;
                parameters["Force"] = true;
                item.InvokeMethod("Set", parameters, null);
            }
        }

        private sealed class BaselineSnapshot
        {
            public int SchemaVersion = 1;
            public string ToolkitVersion = Version;
            public string ComputerName;
            public string CreatedUtc;
            public string FirewallExportFile = "firewall.wfw";
            public RegistrySnapshot[] Registry;
            public GuestState Guest;
            public string Smb1State;
            public bool? RdpEnabled;
            public DefenderState Defender;
        }

        private static BaselineSnapshot CaptureSnapshot(string firewallFileName = "firewall.wfw")
        {
            return new BaselineSnapshot
            {
                SchemaVersion = 1,
                ToolkitVersion = Version,
                ComputerName = Environment.MachineName,
                CreatedUtc = DateTime.UtcNow.ToString("o"),
                FirewallExportFile = firewallFileName,
                Registry = new[]
                {
                    ReadDword("HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\System", "EnableLUA"),
                    ReadDword("HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\System", "ConsentPromptBehaviorAdmin"),
                    ReadDword("HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\System", "PromptOnSecureDesktop"),
                    ReadDword("HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\Explorer", "NoDriveTypeAutoRun"),
                    ReadDword("HKLM\\SYSTEM\\CurrentControlSet\\Control\\Terminal Server\\WinStations\\RDP-Tcp", "UserAuthentication"),
                    ReadDword("HKLM\\SOFTWARE\\Microsoft\\Windows Defender\\Windows Defender Exploit Guard\\Network Protection", "EnableNetworkProtection")
                },
                Guest = ReadGuestState(),
                Smb1State = ReadSmb1State(),
                RdpEnabled = ReadRdpEnabled(),
                Defender = ReadDefenderState()
            };
        }

        private static string DataRoot(bool common)
        {
            string root = Environment.GetFolderPath(common ? Environment.SpecialFolder.CommonApplicationData : Environment.SpecialFolder.LocalApplicationData);
            return Path.Combine(root, "WindowsSecureToolkit");
        }

        private static string NewBackup(string backupDirectory = null)
        {
            string directory = backupDirectory ?? Path.Combine(DataRoot(true), "Backups", DateTime.Now.ToString("yyyyMMdd-HHmmss"));
            Directory.CreateDirectory(directory);
            string firewallFile = Path.Combine(directory, "firewall.wfw");
            ProcessResult export = RunNative("netsh.exe", "advfirewall export " + Quote(firewallFile));
            if (export.ExitCode != 0) throw new InvalidOperationException("防火墙策略导出失败：" + FirstError(export));
            BaselineSnapshot snapshot = CaptureSnapshot();
            string manifest = Json.Serialize(snapshot);
            string manifestPath = Path.Combine(directory, "manifest.json");
            File.WriteAllText(manifestPath, manifest, new UTF8Encoding(false));
            File.WriteAllText(Path.Combine(directory, "manifest.sha256"), HashFile(manifestPath) + "  manifest.json\r\n", new UTF8Encoding(false));
            return directory;
        }

        private static string HashFile(string path)
        {
            using (var sha = SHA256.Create())
            using (FileStream stream = File.OpenRead(path))
            {
                return BitConverter.ToString(sha.ComputeHash(stream)).Replace("-", string.Empty).ToLowerInvariant();
            }
        }

        private static string FirstError(ProcessResult result)
        {
            string text = (result.Stderr ?? string.Empty).Trim();
            if (text.Length == 0) text = (result.Stdout ?? string.Empty).Trim();
            if (text.Length > 300) text = text.Substring(0, 300);
            return text.Length == 0 ? "未知错误" : text;
        }

        private static bool IsAdministrator()
        {
            try
            {
                using (WindowsIdentity identity = WindowsIdentity.GetCurrent())
                {
                    return identity != null && new WindowsPrincipal(identity).IsInRole(WindowsBuiltInRole.Administrator);
                }
            }
            catch { return false; }
        }

        private static bool Confirm(string prompt)
        {
            Console.Write(prompt + " [y/N] ");
            string value = Console.ReadLine();
            return value != null && (value.Equals("y", StringComparison.OrdinalIgnoreCase) || value.Equals("yes", StringComparison.OrdinalIgnoreCase));
        }

        private static List<ChangeResult> BuildPlan()
        {
            bool server = IsServerOperatingSystem();
            var plan = new List<ChangeResult>
            {
                new ChangeResult("firewall", "开启全部 Windows 防火墙配置文件"),
                new ChangeResult("defender-base", "开启 Defender 实时保护与 PUA 防护"),
                new ChangeResult("uac", "启用 UAC 与安全桌面提示"),
                new ChangeResult("smb1", "禁用 SMBv1 可选功能（不自动重启）"),
                new ChangeResult("guest", "禁用本地 Guest 账户"),
                new ChangeResult("rdp-nla", "RDP 已启用时要求网络级别身份验证（NLA）"),
                new ChangeResult("autorun", "禁用所有驱动器的 AutoRun")
            };
            if (server) plan.Insert(2, new ChangeResult("defender-network", "跳过 Windows Server 的网络保护设置（按服务器角色评估）") { Status = "Skipped" });
            else plan.Insert(2, new ChangeResult("defender-network", "将 Defender 网络保护设为审核模式（Windows 客户端）"));
            string smbState = ReadSmb1State();
            ChangeResult smb = plan.First(item => item.Id == "smb1");
            if (string.IsNullOrWhiteSpace(smbState) || smbState.IndexOf("Disabled", StringComparison.OrdinalIgnoreCase) >= 0)
            {
                smb.Status = "Skipped";
                smb.Detail = string.IsNullOrWhiteSpace(smbState) ? "当前系统不提供可读取的 SMB1Protocol 状态" : "SMBv1 已禁用";
            }
            GuestState guest = ReadGuestState();
            ChangeResult guestChange = plan.First(item => item.Id == "guest");
            if (guest != null && guest.Disabled)
            {
                guestChange.Status = "Skipped";
                guestChange.Detail = "Guest 账户已禁用";
            }
            if (ReadRdpEnabled() != true)
            {
                ChangeResult rdp = plan.First(item => item.Id == "rdp-nla");
                rdp.Status = "Skipped";
                rdp.Detail = "RDP 未启用，无需修改 NLA";
            }
            return plan;
        }

        private static void PrintResults(IEnumerable<ChangeResult> results)
        {
            Console.WriteLine();
            Console.WriteLine("Id               Status   Description");
            Console.WriteLine("--               ------   -----------");
            foreach (ChangeResult item in results)
            {
                Console.WriteLine("{0,-16} {1,-8} {2}", item.Id, item.Status, item.Description);
                if (!string.IsNullOrWhiteSpace(item.Detail)) Console.WriteLine("                 " + item.Detail);
            }
        }

        private static int RunApply(bool dryRun, bool yes)
        {
            Section("保守安全基线");
            Console.WriteLine("将检查并处理以下项目：");
            foreach (ChangeResult item in BuildPlan()) Console.WriteLine("  - " + item.Description);
            Console.WriteLine();
            Message("警告", "防火墙、旧版 SMB 设备和远程桌面策略可能影响现有业务。");
            Message("信息", "实际应用前会在 ProgramData 下创建带 SHA-256 校验的配置备份。");
            Message("信息", "程序不会自动重启计算机，也不会打开新的入站端口。");

            List<ChangeResult> plan = BuildPlan();
            if (dryRun)
            {
                foreach (ChangeResult item in plan)
                {
                    if (item.Status == "Skipped") Message("警告", item.Description + "：已跳过");
                    else Message("计划", item.Description);
                }
                PrintResults(plan);
                Message("完成", "预览完成，系统未被修改。");
                return 0;
            }

            if (!IsAdministrator())
            {
                Message("错误", "应用基线需要管理员权限。请从提升后的 CMD 启动。");
                return 2;
            }
            if (!yes && !Confirm("继续应用这些设置？"))
            {
                Message("警告", "用户取消了操作。");
                return 5;
            }

            string backupDirectory = NewBackup();
            Message("完成", "备份已创建：" + backupDirectory);
            var results = new List<ChangeResult>();
            results.Add(ApplyChange("firewall", "开启全部 Windows 防火墙配置文件", delegate
            {
                ProcessResult result = RunNative("netsh.exe", "advfirewall set allprofiles state on");
                EnsureSuccess(result, "防火墙配置文件开启失败");
            }));
            results.Add(ApplyChange("defender-base", "开启 Defender 实时保护与 PUA 防护", delegate
            {
                SetDefenderState(null);
            }));
            bool server = IsServerOperatingSystem();
            results.Add(server
                ? new ChangeResult("defender-network", "跳过 Windows Server 的网络保护设置（按服务器角色评估）") { Status = "Skipped", Detail = "Server 默认不修改" }
                : ApplyChange("defender-network", "将 Defender 网络保护设为审核模式（Windows 客户端）", delegate { SetDefenderState(2); }));
            results.Add(ApplyChange("uac", "启用 UAC 与安全桌面提示", delegate
            {
                WriteDword("HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\System", "EnableLUA", 1);
                WriteDword("HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\System", "ConsentPromptBehaviorAdmin", 5);
                WriteDword("HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\System", "PromptOnSecureDesktop", 1);
            }));
            results.Add(ApplyChange("smb1", "禁用 SMBv1 可选功能（不自动重启）", delegate
            {
                string state = ReadSmb1State();
                if (string.IsNullOrWhiteSpace(state) || state.IndexOf("Disabled", StringComparison.OrdinalIgnoreCase) >= 0)
                    throw new SkipChangeException("当前系统没有启用 SMB1Protocol 可选功能");
                ProcessResult result = RunNative("dism.exe", "/online /Disable-Feature /FeatureName:SMB1Protocol /NoRestart", 180000);
                EnsureSuccess(result, "SMBv1 禁用失败");
            }));
            results.Add(ApplyChange("guest", "禁用本地 Guest 账户", delegate
            {
                GuestState guest = ReadGuestState();
                if (guest == null) throw new SkipChangeException("无法读取本地 Guest 账户");
                if (guest.Disabled) throw new SkipChangeException("Guest 账户已禁用");
                ProcessResult result = RunNative("net.exe", "user " + Quote(guest.Name) + " /active:no");
                EnsureSuccess(result, "Guest 账户禁用失败");
            }));
            results.Add(ApplyChange("rdp-nla", "RDP 已启用时要求网络级别身份验证（NLA）", delegate
            {
                bool? enabled = ReadRdpEnabled();
                if (enabled != true) throw new SkipChangeException("RDP 未启用，无需修改 NLA");
                WriteDword("HKLM\\SYSTEM\\CurrentControlSet\\Control\\Terminal Server\\WinStations\\RDP-Tcp", "UserAuthentication", 1);
            }));
            results.Add(ApplyChange("autorun", "禁用所有驱动器的 AutoRun", delegate
            {
                WriteDword("HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\Explorer", "NoDriveTypeAutoRun", 255);
            }));
            PrintResults(results);
            Message("完成", results.Any(item => item.Status == "Failed") ? "部分设置失败，请查看结果和备份。" : "安全基线应用完成；如策略或产品覆盖本地值，应以实际状态为准。");
            return results.Any(item => item.Status == "Failed") ? 4 : 0;
        }

        private static ChangeResult ApplyChange(string id, string description, Action action)
        {
            var result = new ChangeResult(id, description);
            try
            {
                action();
                result.Status = "Applied";
            }
            catch (SkipChangeException ex)
            {
                result.Status = "Skipped";
                result.Detail = ex.Message;
            }
            catch (Exception ex)
            {
                result.Status = "Failed";
                result.Detail = ex.Message;
            }
            return result;
        }

        private static void EnsureSuccess(ProcessResult result, string message)
        {
            if (result.ExitCode != 0) throw new InvalidOperationException(message + "：" + FirstError(result));
        }

        private sealed class SkipChangeException : Exception
        {
            public SkipChangeException(string message) : base(message) { }
        }

        private sealed class ChangeResult
        {
            public string Id;
            public string Status = "Planned";
            public string Description;
            public string Detail;

            public ChangeResult(string id, string description)
            {
                Id = id;
                Description = description;
            }
        }

        private static string ResolveManifest(string suppliedPath)
        {
            string full = Path.GetFullPath(suppliedPath);
            if (Directory.Exists(full)) return Path.Combine(full, "manifest.json");
            if (File.Exists(full)) return full;
            throw new FileNotFoundException("找不到备份清单：" + full);
        }

        private static BaselineSnapshot ReadAndValidateManifest(string manifestPath)
        {
            string directory = Path.GetDirectoryName(manifestPath);
            string hashPath = Path.Combine(directory, "manifest.sha256");
            if (!File.Exists(hashPath)) throw new InvalidOperationException("备份缺少 manifest.sha256。");
            string expected = File.ReadAllText(hashPath, Encoding.UTF8).Trim().Split(new[] { ' ', '\t', '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries).FirstOrDefault();
            if (string.IsNullOrWhiteSpace(expected) || !Regex.IsMatch(expected, "^[0-9a-fA-F]{64}$")) throw new InvalidOperationException("manifest.sha256 格式不正确。");
            string actual = HashFile(manifestPath);
            if (!actual.Equals(expected, StringComparison.OrdinalIgnoreCase)) throw new InvalidOperationException("备份清单 SHA-256 校验失败。");

            BaselineSnapshot snapshot = Json.Deserialize<BaselineSnapshot>(File.ReadAllText(manifestPath, Encoding.UTF8));
            if (snapshot == null || snapshot.SchemaVersion != 1) throw new InvalidOperationException("不支持的备份格式版本。");
            if (!snapshot.ToolkitVersion.Equals(Version, StringComparison.OrdinalIgnoreCase)) throw new InvalidOperationException("备份版本与当前程序不匹配：" + snapshot.ToolkitVersion);
            if (!Environment.MachineName.Equals(snapshot.ComputerName, StringComparison.OrdinalIgnoreCase)) throw new InvalidOperationException("备份不是由当前计算机生成的。");
            if (!string.Equals(snapshot.FirewallExportFile, "firewall.wfw", StringComparison.Ordinal)) throw new InvalidOperationException("防火墙导出文件名不在白名单内。");
            string firewallPath = Path.Combine(directory, snapshot.FirewallExportFile);
            if (!File.Exists(firewallPath) || Path.GetFullPath(firewallPath).StartsWith(Path.GetFullPath(directory) + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase) == false)
                throw new InvalidOperationException("备份防火墙文件路径不合法。");
            ValidateRegistryAllowlist(snapshot.Registry);
            if (snapshot.Defender != null)
            {
                if (snapshot.Defender.PuaProtection.HasValue && (snapshot.Defender.PuaProtection.Value < 0 || snapshot.Defender.PuaProtection.Value > 6)) throw new InvalidOperationException("备份中的 PUAProtection 不在允许范围内。");
                if (snapshot.Defender.NetworkProtection.HasValue && (snapshot.Defender.NetworkProtection.Value < 0 || snapshot.Defender.NetworkProtection.Value > 2)) throw new InvalidOperationException("备份中的 NetworkProtection 不在允许范围内。");
            }
            if (snapshot.Guest != null && (string.IsNullOrWhiteSpace(snapshot.Guest.Sid) || !snapshot.Guest.Sid.EndsWith("-501", StringComparison.OrdinalIgnoreCase))) throw new InvalidOperationException("备份中的 Guest SID 不合法。");
            return snapshot;
        }

        private static void ValidateRegistryAllowlist(IEnumerable<RegistrySnapshot> values)
        {
            var allowed = new HashSet<string>(RegistryAllowlist, StringComparer.OrdinalIgnoreCase);
            RegistrySnapshot[] array = values == null ? new RegistrySnapshot[0] : values.ToArray();
            if (array.Length != allowed.Count) throw new InvalidOperationException("备份中的注册表项目数量不正确。");
            var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (RegistrySnapshot item in array)
            {
                string target = item == null ? string.Empty : item.FullPath + "\\" + item.Name;
                if (!allowed.Contains(target)) throw new InvalidOperationException("备份包含未授权的注册表目标。");
                if (!seen.Add(target)) throw new InvalidOperationException("备份包含重复的注册表目标。");
                if (item.Exists && item.Kind != "DWord") throw new InvalidOperationException("备份包含非 DWord 注册表值。");
            }
            if (!seen.SetEquals(allowed)) throw new InvalidOperationException("备份没有覆盖完整的注册表白名单。");
        }

        private static int RunRestore(string suppliedPath)
        {
            if (!IsAdministrator())
            {
                Message("错误", "恢复需要管理员权限。");
                return 2;
            }
            string manifestPath = ResolveManifest(suppliedPath);
            BaselineSnapshot snapshot = ReadAndValidateManifest(manifestPath);
            if (!Confirm("将恢复本工具记录的设置，继续吗？"))
            {
                Message("警告", "用户取消了恢复。");
                return 5;
            }
            string directory = Path.GetDirectoryName(manifestPath);
            var results = new List<ChangeResult>();
            results.Add(ApplyChange("firewall", "导入备份中的防火墙策略", delegate
            {
                ProcessResult result = RunNative("netsh.exe", "advfirewall import " + Quote(Path.Combine(directory, snapshot.FirewallExportFile)));
                EnsureSuccess(result, "防火墙策略恢复失败");
            }));
            results.Add(ApplyChange("defender", "恢复 Defender 配置", delegate
            {
                if (snapshot.Defender == null) throw new SkipChangeException("备份没有 Defender 状态");
                SetDefenderSnapshot(snapshot.Defender);
            }));
            foreach (RegistrySnapshot item in snapshot.Registry)
            {
                RegistrySnapshot local = item;
                results.Add(ApplyChange("registry", "恢复 " + local.FullPath + "\\" + local.Name, delegate { RestoreDword(local); }));
            }
            if (snapshot.Guest != null)
            {
                GuestState guest = snapshot.Guest;
                results.Add(ApplyChange("guest", "恢复 Guest 账户状态", delegate
                {
                    GuestState current = ReadGuestState();
                    if (current == null || !current.Sid.Equals(guest.Sid, StringComparison.OrdinalIgnoreCase)) throw new InvalidOperationException("当前 Guest SID 与备份不匹配。");
                    ProcessResult result = RunNative("net.exe", "user " + Quote(current.Name) + " /active:" + (guest.Disabled ? "no" : "yes"));
                    EnsureSuccess(result, "Guest 账户恢复失败");
                }));
            }
            if (!string.IsNullOrWhiteSpace(snapshot.Smb1State))
            {
                string smbState = snapshot.Smb1State;
                results.Add(ApplyChange("smb1", "恢复 SMBv1 功能状态", delegate
                {
                    bool enable = smbState.IndexOf("Enabled", StringComparison.OrdinalIgnoreCase) >= 0;
                    string args = enable ? "/online /Enable-Feature /FeatureName:SMB1Protocol /NoRestart" : "/online /Disable-Feature /FeatureName:SMB1Protocol /NoRestart";
                    ProcessResult result = RunNative("dism.exe", args, 180000);
                    EnsureSuccess(result, "SMBv1 状态恢复失败");
                }));
            }
            PrintResults(results);
            return results.Any(item => item.Status == "Failed") ? 4 : 0;
        }

        private static void SetDefenderSnapshot(DefenderState state)
        {
            using (var searcher = new ManagementObjectSearcher("root\\Microsoft\\Windows\\Defender", "SELECT * FROM MSFT_MpPreference"))
            using (ManagementObjectCollection results = searcher.Get())
            {
                ManagementObject item = results.Cast<ManagementObject>().FirstOrDefault();
                if (item == null) throw new InvalidOperationException("未找到 Microsoft Defender 配置提供程序。");
                ManagementBaseObject parameters = item.GetMethodParameters("Set");
                if (state.RealtimeProtection.HasValue) parameters["DisableRealtimeMonitoring"] = !state.RealtimeProtection.Value;
                if (state.PuaProtection.HasValue) parameters["PUAProtection"] = (byte)state.PuaProtection.Value;
                if (state.NetworkProtection.HasValue) parameters["EnableNetworkProtection"] = (byte)state.NetworkProtection.Value;
                parameters["Force"] = true;
                item.InvokeMethod("Set", parameters, null);
            }
        }

        private sealed class AuditItem
        {
            public string Status;
            public string Category;
            public string Id;
            public string Summary;
            public string Detail;
            public string Recommendation;
        }

        private sealed class AuditDocument
        {
            public int SchemaVersion = 1;
            public string ToolkitVersion = Version;
            public string GeneratedUtc;
            public string ComputerName;
            public List<AuditItem> Items;
        }

        private static AuditItem Item(string status, string category, string id, string summary, string detail = "", string recommendation = "")
        {
            return new AuditItem { Status = status, Category = category, Id = id, Summary = summary, Detail = detail, Recommendation = recommendation };
        }

        private static List<AuditItem> CollectAudit()
        {
            var items = new List<AuditItem>();
            items.Add(Item("Info", "系统", "system", GetOsDescription()));
            items.Add(Item(IsAdministrator() ? "Info" : "Review", "权限", "administrator", IsAdministrator() ? "当前为管理员权限" : "当前为标准权限；部分检查可能不可用"));

            FirewallState firewall = ReadFirewallState();
            items.Add(firewall.AllEnabled.HasValue
                ? Item(firewall.AllEnabled.Value ? "Pass" : "Review", "网络", "firewall", firewall.AllEnabled.Value ? "域、专用和公用防火墙均已开启" : "存在已关闭的 Windows 防火墙配置文件", firewall.Raw, firewall.AllEnabled.Value ? "" : "检查防火墙服务、组策略和云安全组")
                : Item("Unavailable", "网络", "firewall", "无法读取 Windows 防火墙状态", firewall.Raw));

            DefenderState defender = ReadDefenderState();
            if (defender.RealtimeProtection.HasValue || defender.AntivirusEnabled.HasValue)
            {
                bool ok = defender.RealtimeProtection != false && defender.AntivirusEnabled != false;
                items.Add(Item(ok ? "Pass" : "Review", "恶意软件防护", "defender", ok ? "Microsoft Defender 防病毒与实时保护已开启" : "Microsoft Defender 状态需要复核", "Realtime=" + defender.RealtimeProtection + "; Antivirus=" + defender.AntivirusEnabled));
                items.Add(Item(defender.PuaProtection == 1 ? "Pass" : "Review", "恶意软件防护", "pua", "PUA 防护状态：" + (defender.PuaProtection.HasValue ? defender.PuaProtection.Value.ToString() : "未知"), "通常 1 表示启用"));
            }
            else items.Add(Item("Unavailable", "恶意软件防护", "defender", "无法读取 Microsoft Defender 状态"));

            int? lua = ReadDwordValue("HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\System", "EnableLUA");
            int? secureDesktop = ReadDwordValue("HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\System", "PromptOnSecureDesktop");
            items.Add(Item(lua == 1 && secureDesktop == 1 ? "Pass" : "Review", "权限", "uac", lua == 1 ? "用户账户控制（UAC）已开启" : "用户账户控制需要复核", "EnableLUA=" + lua + "; PromptOnSecureDesktop=" + secureDesktop));

            string smb = ReadSmb1State();
            items.Add(string.IsNullOrWhiteSpace(smb) ? Item("Unavailable", "旧协议", "smb1", "无法读取 SMBv1 可选功能状态") : Item(smb.IndexOf("Disabled", StringComparison.OrdinalIgnoreCase) >= 0 ? "Pass" : "Review", "旧协议", "smb1", "SMBv1 状态：" + smb));

            GuestState guest = ReadGuestState();
            items.Add(guest == null ? Item("Unavailable", "账户", "guest", "无法读取本地 Guest 账户状态") : Item(guest.Disabled ? "Pass" : "Review", "账户", "guest", guest.Disabled ? "本地 Guest 账户已禁用" : "本地 Guest 账户仍处于启用状态", "SID=" + guest.Sid));

            bool? rdp = ReadRdpEnabled();
            int? nla = ReadDwordValue("HKLM\\SYSTEM\\CurrentControlSet\\Control\\Terminal Server\\WinStations\\RDP-Tcp", "UserAuthentication");
            items.Add(rdp == true ? Item(nla == 1 ? "Pass" : "Review", "远程访问", "rdp-nla", nla == 1 ? "RDP 已启用且要求 NLA" : "RDP 已启用但 NLA 需要复核") : Item("Info", "远程访问", "rdp", "远程桌面未启用"));

            int? autorun = ReadDwordValue("HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\Explorer", "NoDriveTypeAutoRun");
            items.Add(Item(autorun == 255 ? "Pass" : "Review", "启动", "autorun", autorun == 255 ? "所有驱动器 AutoRun 已禁用" : "AutoRun 策略需要复核", "NoDriveTypeAutoRun=" + autorun));

            try
            {
                using (var service = new ServiceController("wuauserv"))
                {
                    bool disabled = service.StartType == ServiceStartMode.Disabled;
                    items.Add(Item(disabled ? "Review" : "Pass", "更新", "windows-update", disabled ? "Windows Update 服务被禁用" : "Windows Update 服务未被禁用", "Status=" + service.Status + "; StartType=" + service.StartType));
                }
            }
            catch { items.Add(Item("Unavailable", "更新", "windows-update", "无法读取 Windows Update 服务状态")); }

            bool pending = Registry.LocalMachine.OpenSubKey("SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Component Based Servicing\\RebootPending") != null || Registry.LocalMachine.OpenSubKey("SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\WindowsUpdate\\Auto Update\\RebootRequired") != null;
            items.Add(Item(pending ? "Info" : "Pass", "维护", "pending-reboot", pending ? "检测到待重启状态" : "未检测到待重启状态"));

            items.Add(Item("Unavailable", "磁盘", "bitlocker", "当前版本不读取 BitLocker 状态"));
            items.Add(Item("Unavailable", "启动", "secure-boot", "当前版本不读取安全启动状态"));
            items.Add(Item("Info", "网络", "listening-ports", "监听端口请使用 ports 命令查看；监听不等于公网开放"));
            return items;
        }

        private sealed class FirewallState
        {
            public bool? AllEnabled;
            public string Raw;
        }

        private static FirewallState ReadFirewallState()
        {
            string[] profiles = { "DomainProfile", "PublicProfile" };
            var registryStates = profiles.Select(profile => ReadDwordValue("HKLM\\SYSTEM\\CurrentControlSet\\Services\\SharedAccess\\Parameters\\FirewallPolicy\\" + profile, "EnableFirewall")).ToList();
            int? privateState = ReadDwordValue("HKLM\\SYSTEM\\CurrentControlSet\\Services\\SharedAccess\\Parameters\\FirewallPolicy\\PrivateProfile", "EnableFirewall");
            if (!privateState.HasValue) privateState = ReadDwordValue("HKLM\\SYSTEM\\CurrentControlSet\\Services\\SharedAccess\\Parameters\\FirewallPolicy\\StandardProfile", "EnableFirewall");
            registryStates.Add(privateState);
            if (registryStates.All(value => value.HasValue))
            {
                return new FirewallState
                {
                    AllEnabled = registryStates.All(value => value.Value != 0),
                    Raw = "读取了 Domain、Private、Public 三个防火墙配置文件"
                };
            }
            ProcessResult result = RunNative("netsh.exe", "advfirewall show allprofiles state", 60000);
            string raw = ((result.Stdout ?? string.Empty) + "\n" + (result.Stderr ?? string.Empty)).Trim();
            int stateCount = CountText(raw, "State") + CountText(raw, "状态");
            int enabledCount = CountText(raw, "ON") + CountText(raw, "启用");
            int disabledCount = CountText(raw, "OFF") + CountText(raw, "禁用");
            if (stateCount == 0 || enabledCount + disabledCount < stateCount) return new FirewallState { AllEnabled = null, Raw = raw };
            return new FirewallState { AllEnabled = disabledCount == 0 && enabledCount >= stateCount, Raw = "检测到 " + stateCount + " 个配置文件状态" };
        }

        private static int CountText(string text, string value)
        {
            int count = 0;
            int start = 0;
            while (start < text.Length)
            {
                int found = text.IndexOf(value, start, StringComparison.OrdinalIgnoreCase);
                if (found < 0) break;
                count++;
                start = found + value.Length;
            }
            return count;
        }

        private static string GetOsDescription()
        {
            try
            {
                using (var searcher = new ManagementObjectSearcher("root\\cimv2", "SELECT Caption, Version, BuildNumber FROM Win32_OperatingSystem"))
                using (ManagementObjectCollection results = searcher.Get())
                {
                    ManagementObject item = results.Cast<ManagementObject>().FirstOrDefault();
                    if (item != null)
                    {
                        return Convert.ToString(item["Caption"]) + " build " + Convert.ToString(item["BuildNumber"]);
                    }
                }
            }
            catch { }
            return "Windows（版本信息不可用）";
        }

        private sealed class DoctorCheck
        {
            public string Id;
            public string Status;
            public string Summary;
            public string Detail;
            public bool Required;
        }

        private sealed class DoctorDocument
        {
            public int SchemaVersion = 1;
            public string ToolkitVersion = Version;
            public string GeneratedUtc;
            public string ComputerName;
            public List<DoctorCheck> Checks;
        }

        private static int RunDoctor(bool jsonOutput)
        {
            List<DoctorCheck> checks = CollectDoctorChecks();
            int failures = checks.Count(check => check.Status == "Fail");
            if (jsonOutput)
            {
                Console.WriteLine(Json.Serialize(new DoctorDocument
                {
                    GeneratedUtc = DateTime.UtcNow.ToString("o"),
                    ComputerName = Environment.MachineName,
                    Checks = checks
                }));
                return failures == 0 ? 0 : 4;
            }

            Section("本机兼容性诊断（只读）");
            Console.WriteLine("检查项              状态          说明");
            Console.WriteLine("------------------------------------------------------------");
            foreach (DoctorCheck check in checks)
            {
                Console.WriteLine("{0,-19} {1,-11} {2}", check.Id, check.Status, check.Summary);
                if (!string.IsNullOrWhiteSpace(check.Detail)) Console.WriteLine("                    {0}", check.Detail);
            }
            int unavailable = checks.Count(check => check.Status == "Unavailable");
            if (failures > 0)
            {
                Message("错误", "诊断发现 " + failures + " 个阻断项；没有修改系统。");
                return 4;
            }
            Message(unavailable > 0 ? "警告" : "完成", "诊断完成：" + checks.Count + " 项检查，没有修改系统。" + (unavailable > 0 ? "部分能力需要人工复核。" : string.Empty));
            return 0;
        }

        private static List<DoctorCheck> CollectDoctorChecks()
        {
            var checks = new List<DoctorCheck>();
            bool isWindows = Environment.OSVersion.Platform == PlatformID.Win32NT;
            checks.Add(new DoctorCheck
            {
                Id = "platform",
                Status = isWindows ? "Pass" : "Fail",
                Summary = isWindows ? "检测到 Windows 平台" : "当前平台不是 Windows",
                Detail = Environment.OSVersion.VersionString,
                Required = true
            });

            string osDescription = GetOsDescription();
            bool wmiAvailable = !string.IsNullOrWhiteSpace(osDescription) && osDescription.IndexOf("不可用", StringComparison.OrdinalIgnoreCase) < 0;
            checks.Add(new DoctorCheck
            {
                Id = "wmi",
                Status = wmiAvailable ? "Pass" : "Unavailable",
                Summary = wmiAvailable ? "WMI 可以读取操作系统信息" : "WMI 操作系统信息不可用",
                Detail = osDescription,
                Required = false
            });

            int? frameworkRelease = ReadDotNetFrameworkRelease();
            checks.Add(new DoctorCheck
            {
                Id = "dotnet-framework",
                Status = frameworkRelease.HasValue && frameworkRelease.Value >= 528040 ? "Pass" : (frameworkRelease.HasValue ? "Fail" : "Unavailable"),
                Summary = frameworkRelease.HasValue ? ".NET Framework 4.8 Release key：" + frameworkRelease.Value : "无法读取 .NET Framework 4.x Release key",
                Detail = "要求 Release >= 528040（.NET Framework 4.8）",
                Required = true
            });

            checks.Add(new DoctorCheck
            {
                Id = "administrator",
                Status = IsAdministrator() ? "Info" : "Review",
                Summary = IsAdministrator() ? "当前进程具有管理员权限" : "当前进程不是管理员权限",
                Detail = "审计、doctor 和 plan 不需要提权；apply、restore、scan、verify 的部分步骤需要管理员权限。",
                Required = false
            });

            AddToolCheck(checks, "netsh", "netsh.exe 可用（防火墙状态与备份）", true);
            AddToolCheck(checks, "netstat", "netstat.exe 可用（监听端口）", true);
            AddToolCheck(checks, "dism", "dism.exe 可用（SMBv1 与系统验证）", true);
            AddToolCheck(checks, "sfc", "sfc.exe 可用（系统文件验证）", true);

            string defenderPath = FindDefenderExecutable();
            checks.Add(new DoctorCheck
            {
                Id = "defender",
                Status = string.IsNullOrWhiteSpace(defenderPath) ? "Unavailable" : "Pass",
                Summary = string.IsNullOrWhiteSpace(defenderPath) ? "未找到 MpCmdRun.exe" : "找到 Microsoft Defender 命令行工具",
                Detail = string.IsNullOrWhiteSpace(defenderPath) ? "可能由组织策略、版本差异或第三方防护软件导致。" : defenderPath,
                Required = false
            });

            checks.Add(new DoctorCheck
            {
                Id = "release-api",
                Status = ReleaseApiUrl.StartsWith("https://api.github.com/", StringComparison.OrdinalIgnoreCase) ? "Pass" : "Fail",
                Summary = "Release 查询地址固定为 GitHub HTTPS API",
                Detail = ReleaseApiUrl,
                Required = false
            });
            return checks;
        }

        private static void AddToolCheck(List<DoctorCheck> checks, string id, string summary, bool required)
        {
            string executable = FindExecutable(id + ".exe");
            checks.Add(new DoctorCheck
            {
                Id = id,
                Status = string.IsNullOrWhiteSpace(executable) ? "Unavailable" : "Pass",
                Summary = string.IsNullOrWhiteSpace(executable) ? summary.Replace("可用", "未找到") : summary,
                Detail = string.IsNullOrWhiteSpace(executable) ? "当前环境没有找到该系统工具；对应命令可能无法运行。" : executable,
                Required = required
            });
        }

        private static string FindDefenderExecutable()
        {
            var candidates = new List<string>();
            string programFiles = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles);
            string programFilesX86 = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86);
            if (!string.IsNullOrWhiteSpace(programFiles)) candidates.Add(Path.Combine(programFiles, "Windows Defender", "MpCmdRun.exe"));
            if (!string.IsNullOrWhiteSpace(programFilesX86)) candidates.Add(Path.Combine(programFilesX86, "Windows Defender", "MpCmdRun.exe"));
            foreach (string candidate in candidates)
            {
                try { if (File.Exists(candidate)) return candidate; } catch { }
            }
            return FindExecutable("MpCmdRun.exe");
        }

        private static string FindExecutable(string fileName)
        {
            if (string.IsNullOrWhiteSpace(fileName)) return null;
            var directories = new List<string>();
            string systemRoot = Environment.GetEnvironmentVariable("SystemRoot");
            if (!string.IsNullOrWhiteSpace(systemRoot)) directories.Add(Path.Combine(systemRoot, "System32"));
            string path = Environment.GetEnvironmentVariable("PATH");
            if (!string.IsNullOrWhiteSpace(path)) directories.AddRange(path.Split(new[] { Path.PathSeparator }, StringSplitOptions.RemoveEmptyEntries));
            foreach (string directory in directories)
            {
                try
                {
                    string candidate = Path.Combine(directory.Trim().Trim('"'), fileName);
                    if (File.Exists(candidate)) return candidate;
                }
                catch { }
            }
            return null;
        }

        private static int? ReadDotNetFrameworkRelease()
        {
            try
            {
                using (RegistryKey key = Registry.LocalMachine.OpenSubKey("SOFTWARE\\Microsoft\\NET Framework Setup\\NDP\\v4\\Full", false))
                {
                    if (key == null) return null;
                    object value = key.GetValue("Release", null, RegistryValueOptions.DoNotExpandEnvironmentNames);
                    int release;
                    return value != null && int.TryParse(Convert.ToString(value), out release) ? (int?)release : null;
                }
            }
            catch { return null; }
        }

        private static int RunAudit(string requestedPath)
        {
            Section("只读安全审计");
            Message("信息", "正在读取本机安全配置，不修改系统设置。");
            List<AuditItem> items = CollectAudit();
            foreach (AuditItem item in items)
            {
                Console.WriteLine("{0,-12} {1,-8} {2,-18} {3}", item.Status, item.Category, item.Id, item.Summary);
            }
            string[] paths = WriteAuditReports(items, requestedPath);
            Message("完成", "Markdown 报告：" + paths[0]);
            Message("完成", "JSON 报告：" + paths[1]);
            if (items.Any(item => item.Status == "Review")) Message("警告", "有项目需要人工复核；这不等同于确认存在漏洞。");
            return 0;
        }

        private static string[] WriteAuditReports(List<AuditItem> items, string requestedPath)
        {
            string directory;
            string markdownPath;
            string jsonPath;
            if (!string.IsNullOrWhiteSpace(requestedPath) && Path.HasExtension(requestedPath) && requestedPath.EndsWith(".md", StringComparison.OrdinalIgnoreCase))
            {
                markdownPath = Path.GetFullPath(requestedPath);
                directory = Path.GetDirectoryName(markdownPath);
                jsonPath = Path.ChangeExtension(markdownPath, ".json");
            }
            else
            {
                directory = string.IsNullOrWhiteSpace(requestedPath) ? Path.Combine(DataRoot(false), "Reports") : Path.GetFullPath(requestedPath);
                string stamp = DateTime.Now.ToString("yyyyMMdd-HHmmss");
                string stem = "audit-" + Environment.MachineName + "-" + stamp;
                markdownPath = Path.Combine(directory, stem + ".md");
                jsonPath = Path.Combine(directory, stem + ".json");
            }
            Directory.CreateDirectory(directory);
            var document = new AuditDocument
            {
                SchemaVersion = 1,
                ToolkitVersion = Version,
                GeneratedUtc = DateTime.UtcNow.ToString("o"),
                ComputerName = Environment.MachineName,
                Items = items
            };
            File.WriteAllText(jsonPath, Json.Serialize(document), new UTF8Encoding(false));
            var markdown = new StringBuilder();
            markdown.AppendLine("# Windows Secure Toolkit audit");
            markdown.AppendLine();
            markdown.AppendLine("- Toolkit version: " + Version);
            markdown.AppendLine("- Computer: " + Environment.MachineName);
            markdown.AppendLine("- Generated UTC: " + document.GeneratedUtc);
            markdown.AppendLine();
            markdown.AppendLine("| Status | Category | Id | Summary | Detail |");
            markdown.AppendLine("| --- | --- | --- | --- | --- |");
            foreach (AuditItem item in items)
            {
                markdown.AppendLine("| " + SafeMarkdown(item.Status) + " | " + SafeMarkdown(item.Category) + " | " + SafeMarkdown(item.Id) + " | " + SafeMarkdown(item.Summary) + " | " + SafeMarkdown(item.Detail) + " |");
            }
            File.WriteAllText(markdownPath, markdown.ToString(), new UTF8Encoding(false));
            return new[] { markdownPath, jsonPath };
        }

        private static string SafeMarkdown(string value)
        {
            return (value ?? string.Empty).Replace("|", "\\|").Replace("\r", " ").Replace("\n", " ");
        }

        private static int RunDefenderScan()
        {
            Section("Microsoft Defender 快速扫描");
            if (!IsAdministrator())
            {
                Message("错误", "Defender 扫描需要管理员权限。");
                return 2;
            }
            string path = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "Windows Defender", "MpCmdRun.exe");
            if (!File.Exists(path))
            {
                Message("错误", "找不到 MpCmdRun.exe。");
                return 4;
            }
            ProcessResult result = RunNative(path, "-Scan -ScanType 1", 1800000);
            Console.WriteLine(result.Stdout);
            if (result.ExitCode != 0)
            {
                Message("错误", "Defender 快速扫描失败：" + FirstError(result));
                return 4;
            }
            Message("完成", "Defender 快速扫描命令已返回成功。");
            return 0;
        }

        private static int RunSystemVerify()
        {
            Section("系统文件只读验证");
            if (!IsAdministrator())
            {
                Message("错误", "系统验证通常需要管理员权限。");
                return 2;
            }
            ProcessResult dism = RunNative("dism.exe", "/online /cleanup-image /scanhealth", 1800000);
            Console.WriteLine(dism.Stdout);
            if (dism.ExitCode != 0) Message("警告", "DISM 返回 " + dism.ExitCode + "：" + FirstError(dism));
            ProcessResult sfc = RunNative("sfc.exe", "/verifyonly", 1800000);
            Console.WriteLine(sfc.Stdout);
            if (sfc.ExitCode != 0) Message("警告", "SFC 返回 " + sfc.ExitCode + "：" + FirstError(sfc));
            if (dism.ExitCode != 0 || sfc.ExitCode != 0) return 4;
            Message("完成", "系统映像与文件验证命令完成；程序没有自动修复问题。");
            return 0;
        }

        private static int ShowListeningPorts()
        {
            Section("TCP 监听端口");
            ProcessResult result = RunNative("netstat.exe", "-ano -p tcp", 60000);
            if (result.ExitCode != 0)
            {
                Message("错误", "无法读取监听端口：" + FirstError(result));
                return 4;
            }
            var lines = new List<string>();
            foreach (string line in (result.Stdout ?? string.Empty).Split(new[] { '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries))
            {
                if (Regex.IsMatch(line, @"\s+(LISTENING|LISTEN)\s+\d+\s*$", RegexOptions.IgnoreCase)) lines.Add(line.Trim());
            }
            if (lines.Count == 0) Console.WriteLine("没有检测到 TCP 监听端点。");
            foreach (string line in lines) Console.WriteLine(line);
            Message("信息", "监听端口不自动等于对公网开放；还需结合防火墙、路由与云安全组判断。");
            return 0;
        }

        private static int CheckForUpdate()
        {
            Section("版本检查");
            Message("信息", "仅查询 GitHub Release 元数据，不下载或执行远程代码。");
            try
            {
                ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12;
                using (var client = new WebClient())
                {
                    client.Headers[HttpRequestHeader.UserAgent] = "windows-secure-toolkit";
                    client.Headers[HttpRequestHeader.Accept] = "application/vnd.github+json";
                    string payload = client.DownloadString(ReleaseApiUrl);
                    Match tagMatch = Regex.Match(payload, @"""tag_name""\s*:\s*""(?<tag>[^""]+)""", RegexOptions.IgnoreCase);
                    Match urlMatch = Regex.Match(payload, @"""html_url""\s*:\s*""(?<url>[^""]+)""", RegexOptions.IgnoreCase);
                    if (!tagMatch.Success) throw new InvalidOperationException("Release 响应缺少 tag_name。");
                    string remoteText = tagMatch.Groups["tag"].Value.TrimStart('v');
                    Version remote = new Version(remoteText);
                    Version local = new Version(Version);
                    if (remote > local)
                    {
                        Message("警告", "发现新版本 v" + remote + "；当前版本 v" + local + "。");
                        if (urlMatch.Success) Console.WriteLine("发布页：" + urlMatch.Groups["url"].Value);
                    }
                    else if (remote == local) Message("完成", "当前已是最新发布版本 v" + local + "。");
                    else Message("信息", "当前版本 v" + local + "高于最新公开发布 v" + remote + "。");
                    return 0;
                }
            }
            catch (Exception ex)
            {
                Message("错误", "无法读取 GitHub Release：" + ex.Message);
                return 4;
            }
        }

        private static int RunSelfTest()
        {
            Section("核心自检");
            var failures = new List<string>();
            Version parsed;
            if (!System.Version.TryParse(Version, out parsed)) failures.Add("版本号不是有效的语义版本。");
            if (!ReleaseApiUrl.StartsWith("https://api.github.com/", StringComparison.OrdinalIgnoreCase)) failures.Add("Release API 地址不是受限的 HTTPS 地址。");
            if (Quote("C:\\a b\\file.txt") != "\"C:\\a b\\file.txt\"") failures.Add("命令行路径引用测试失败。");
            var expected = new RegistrySnapshot
            {
                Hive = "HKLM",
                SubKey = "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\System",
                Name = "EnableLUA",
                Exists = true,
                Kind = "DWord",
                Value = 1
            };
            try
            {
                string roundTrip = Json.Serialize(new BaselineSnapshot
                {
                    ComputerName = Environment.MachineName,
                    CreatedUtc = DateTime.UtcNow.ToString("o"),
                    Registry = new[] { expected }
                });
                BaselineSnapshot restored = Json.Deserialize<BaselineSnapshot>(roundTrip);
                if (restored == null || restored.Registry == null || restored.Registry.Length != 1 || restored.Registry[0].Name != expected.Name) failures.Add("清单 JSON 往返测试失败。");
            }
            catch (Exception ex) { failures.Add("清单 JSON 测试失败：" + ex.Message); }

            try
            {
                RegistrySnapshot[] validRegistry = RegistryAllowlist.Select(CreateSelfTestRegistrySnapshot).ToArray();
                ValidateRegistryAllowlist(validRegistry);
                RegistrySnapshot[] duplicateRegistry = validRegistry.ToArray();
                duplicateRegistry[duplicateRegistry.Length - 1] = duplicateRegistry[0];
                try
                {
                    ValidateRegistryAllowlist(duplicateRegistry);
                    failures.Add("重复的注册表清单项目没有被拒绝。");
                }
                catch (InvalidOperationException)
                {
                    // Expected: restore manifests must contain each allowlisted target once.
                }
            }
            catch (Exception ex) { failures.Add("注册表白名单测试失败：" + ex.Message); }

            try
            {
                List<DoctorCheck> doctorChecks = CollectDoctorChecks();
                string doctorJson = Json.Serialize(new DoctorDocument
                {
                    GeneratedUtc = DateTime.UtcNow.ToString("o"),
                    ComputerName = Environment.MachineName,
                    Checks = doctorChecks
                });
                DoctorDocument doctorRoundTrip = Json.Deserialize<DoctorDocument>(doctorJson);
                if (doctorRoundTrip == null || doctorRoundTrip.SchemaVersion != 1 || doctorRoundTrip.Checks == null || doctorRoundTrip.Checks.Count == 0)
                {
                    failures.Add("doctor JSON 往返测试失败。");
                }
            }
            catch (Exception ex) { failures.Add("doctor 诊断测试失败：" + ex.Message); }

            string temp = Path.Combine(Path.GetTempPath(), "windows-secure-toolkit-selftest-" + Guid.NewGuid().ToString("N"));
            try
            {
                Directory.CreateDirectory(temp);
                string manifest = Path.Combine(temp, "manifest.json");
                File.WriteAllText(manifest, "{}", new UTF8Encoding(false));
                string hash = HashFile(manifest);
                if (!Regex.IsMatch(hash, "^[0-9a-f]{64}$")) failures.Add("SHA-256 测试失败。");
                File.WriteAllText(Path.Combine(temp, "manifest.sha256"), hash + "  manifest.json\r\n", new UTF8Encoding(false));
                if (!File.Exists(Path.Combine(temp, "manifest.sha256"))) failures.Add("临时清单写入测试失败。");
            }
            catch (Exception ex) { failures.Add("临时文件测试失败：" + ex.Message); }
            finally
            {
                try { if (Directory.Exists(temp)) Directory.Delete(temp, true); } catch { }
            }

            if (failures.Count > 0)
            {
                foreach (string failure in failures) Message("错误", failure);
                return 1;
            }
            Message("完成", "WinSecure C# 核心自检通过。");
            return 0;
        }

        private static RegistrySnapshot CreateSelfTestRegistrySnapshot(string target)
        {
            int hiveSeparator = target.IndexOf('\\');
            int nameSeparator = target.LastIndexOf('\\');
            return new RegistrySnapshot
            {
                Hive = target.Substring(0, hiveSeparator),
                SubKey = target.Substring(hiveSeparator + 1, nameSeparator - hiveSeparator - 1),
                Name = target.Substring(nameSeparator + 1),
                Exists = false,
                Kind = "DWord",
                Value = 0
            };
        }
    }
}
