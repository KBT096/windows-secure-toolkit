@echo off
setlocal EnableExtensions DisableDelayedExpansion
chcp 65001 >nul

set "TOOL_ROOT=%~dp1"
if "%TOOL_ROOT%"=="" set "TOOL_ROOT=%~dp0..\"
for %%P in ("%TOOL_ROOT%.\") do set "TOOL_ROOT=%%~fP\"
set /a CHECKS=0
set /a FAILURES=0

echo Security regression gate
echo Root: %TOOL_ROOT%
echo.

rem Scan only executable source and entry points. Documentation may quote rejected patterns.
call :reject "curl"
call :reject "wget"
call :reject "bash"
call :reject "eval "
call :reject "eval("
call :reject "Invoke-Expression"
call :reject "certutil -decode"
call :reject "powershell"
call :reject "sshd_config"
call :reject "/etc/ssh"
call :reject "ssh_config"
call :reject "firewall add rule"
call :reject "advfirewall firewall add"
call :reject "localport 22"
call :reject "localport=22"
call :reject "localport 80"
call :reject "localport=80"
call :reject "localport 443"
call :reject "localport=443"

if %FAILURES%==0 (
    echo.
    echo PASS: %CHECKS% security invariants checked.
    exit /b 0
)
echo.
echo FAIL: %FAILURES% security invariants failed.
exit /b 1

:reject
set /a CHECKS+=1
findstr /s /i /n /c:"%~1" "%TOOL_ROOT%src\*.cs" "%TOOL_ROOT%win_secure.cmd" "%TOOL_ROOT%win_secure.bat" "%TOOL_ROOT%build.cmd" >nul 2>nul
if not errorlevel 1 (
    echo [失败] 发现禁止模式：%~1
    set /a FAILURES+=1
) else (
    echo [完成] 未发现：%~1
)
exit /b 0
