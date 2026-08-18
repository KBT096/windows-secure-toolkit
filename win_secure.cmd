@echo off
setlocal EnableExtensions DisableDelayedExpansion
chcp 65001 >nul

set "TOOL_ROOT=%~dp0"
set "ENGINE=%TOOL_ROOT%src\WinSecure.ps1"
set "POWERSHELL_EXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if exist "%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe" (
    set "POWERSHELL_EXE=%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe"
)

if not exist "%ENGINE%" (
    echo [错误] 找不到核心脚本：
    echo %ENGINE%
    exit /b 2
)

if not exist "%POWERSHELL_EXE%" (
    for /f "delims=" %%P in ('where powershell.exe 2^>nul') do (
        if not defined POWERSHELL_FALLBACK set "POWERSHELL_FALLBACK=%%P"
    )
    if not defined POWERSHELL_FALLBACK (
        echo [错误] 未找到 Windows PowerShell 5.1 或更高版本。
        exit /b 2
    )
    set "POWERSHELL_EXE=%POWERSHELL_FALLBACK%"
)

if "%~1"=="" goto menu
if /i "%~1"=="menu" goto menu
if /i "%~1"=="audit" goto audit
if /i "%~1"=="plan" goto plan
if /i "%~1"=="apply" goto apply
if /i "%~1"=="restore" goto restore
if /i "%~1"=="scan" goto scan
if /i "%~1"=="verify" goto verify
if /i "%~1"=="ports" goto ports
if /i "%~1"=="update" goto update
if /i "%~1"=="version" goto version
if /i "%~1"=="self-test" goto self_test
if /i "%~1"=="help" goto help
if /i "%~1"=="--help" goto help
if /i "%~1"=="-h" goto help

echo [错误] 未知命令：%~1
echo.
goto help_error

:menu
"%POWERSHELL_EXE%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%ENGINE%" -Action Menu
exit /b %ERRORLEVEL%

:audit
if "%~2"=="" (
    "%POWERSHELL_EXE%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%ENGINE%" -Action Audit
) else (
    "%POWERSHELL_EXE%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%ENGINE%" -Action Audit -ReportPath "%~2"
)
exit /b %ERRORLEVEL%

:plan
"%POWERSHELL_EXE%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%ENGINE%" -Action Apply -DryRun
exit /b %ERRORLEVEL%

:apply
"%POWERSHELL_EXE%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%ENGINE%" -Action Apply
exit /b %ERRORLEVEL%

:restore
if "%~2"=="" (
    echo [错误] restore 需要备份目录或 manifest.json 路径。
    echo 示例：win_secure.cmd restore "C:\ProgramData\WindowsSecureToolkit\Backups\20260818-120000"
    exit /b 2
)
"%POWERSHELL_EXE%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%ENGINE%" -Action Restore -BackupPath "%~2"
exit /b %ERRORLEVEL%

:scan
"%POWERSHELL_EXE%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%ENGINE%" -Action DefenderQuickScan
exit /b %ERRORLEVEL%

:verify
"%POWERSHELL_EXE%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%ENGINE%" -Action SystemVerify
exit /b %ERRORLEVEL%

:ports
"%POWERSHELL_EXE%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%ENGINE%" -Action ListeningPorts
exit /b %ERRORLEVEL%

:update
"%POWERSHELL_EXE%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%ENGINE%" -Action UpdateCheck
exit /b %ERRORLEVEL%

:version
"%POWERSHELL_EXE%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%ENGINE%" -Action Version -NoColor
exit /b %ERRORLEVEL%

:self_test
"%POWERSHELL_EXE%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%ENGINE%" -Action SelfTest -NoColor
exit /b %ERRORLEVEL%

:help
"%POWERSHELL_EXE%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%ENGINE%" -Action Help -NoColor
exit /b %ERRORLEVEL%

:help_error
"%POWERSHELL_EXE%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%ENGINE%" -Action Help -NoColor
exit /b 2
