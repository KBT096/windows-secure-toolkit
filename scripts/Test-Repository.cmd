@echo off
setlocal EnableExtensions DisableDelayedExpansion
chcp 65001 >nul

set "TOOL_ROOT=%~dp1"
if "%TOOL_ROOT%"=="" set "TOOL_ROOT=%~dp0..\"
for %%P in ("%TOOL_ROOT%.") do set "TOOL_ROOT=%%~fP\"
set /a CHECKS=0
set /a FAILURES=0
set "TEST_ROOT=%TEMP%\windows-secure-toolkit-test-%RANDOM%-%RANDOM%"

echo Repository validation
echo Root: %TOOL_ROOT%
echo.

call :require_file "%TOOL_ROOT%win_secure.cmd"
call :require_file "%TOOL_ROOT%win_secure.bat"
call :require_file "%TOOL_ROOT%build.cmd"
call :require_file "%TOOL_ROOT%src\WindowsSecureToolkit.csproj"
call :require_file "%TOOL_ROOT%src\WinSecure.cs"
call :require_file "%TOOL_ROOT%README.md"
call :require_file "%TOOL_ROOT%LICENSE"
call :require_file "%TOOL_ROOT%SECURITY.md"
call :require_file "%TOOL_ROOT%docs\THREAT_MODEL.md"
call :require_file "%TOOL_ROOT%docs\WINDOWS_VALIDATION.md"

findstr /s /i /n "Invoke-Expression certutil -decode" "%TOOL_ROOT%src\*.cs" "%TOOL_ROOT%*.cmd" >nul 2>nul
if not errorlevel 1 (
    echo [失败] 源码包含被禁止的动态远程执行模式。
    set /a FAILURES+=1
) else (
    echo [完成] 源码未发现动态远程执行模式。
)

call "%TOOL_ROOT%build.cmd"
if errorlevel 1 (
    echo [失败] C# 构建失败。
    set /a FAILURES+=1
) else (
    echo [完成] C# 构建通过。
)
call :run_ok self-test
call :run_ok version
call :run_ok help
call :run_ok plan
call :run_ok doctor
call :run_ok_args doctor --json

if exist "%TEST_ROOT%" rmdir /s /q "%TEST_ROOT%"
mkdir "%TEST_ROOT%" >nul 2>nul
call "%TOOL_ROOT%win_secure.cmd" audit "%TEST_ROOT%"
if errorlevel 1 (
    echo [失败] 审计报告命令失败。
    set /a FAILURES+=1
) else (
    call :require_any "%TEST_ROOT%\*.md"
    call :require_any "%TEST_ROOT%\*.json"
)

call "%TOOL_ROOT%win_secure.cmd" restore >nul 2>nul
if errorlevel 2 (
    echo [完成] 缺少 restore 路径时正确返回 2。
    set /a CHECKS+=1
) else (
    echo [失败] 缺少 restore 路径时没有返回 2。
    set /a FAILURES+=1
)

if exist "%TEST_ROOT%" rmdir /s /q "%TEST_ROOT%"
if %FAILURES%==0 (
    echo.
    echo PASS: %CHECKS% checks completed.
    exit /b 0
)
echo.
echo FAIL: %FAILURES% checks failed.
exit /b 1

:require_file
set /a CHECKS+=1
if exist "%~1" (
    echo [完成] %~1
) else (
    echo [失败] 缺少文件：%~1
    set /a FAILURES+=1
)
exit /b 0

:require_any
set /a CHECKS+=1
dir /b "%~1" >nul 2>nul
if errorlevel 1 (
    echo [失败] 没有生成：%~1
    set /a FAILURES+=1
) else (
    echo [完成] 已生成：%~1
)
exit /b 0

:run_ok
set /a CHECKS+=1
call "%TOOL_ROOT%win_secure.cmd" %~1 >nul
if errorlevel 1 (
    echo [失败] 命令失败：%~1
    set /a FAILURES+=1
) else (
    echo [完成] 命令通过：%~1
)
exit /b 0

:run_ok_args
set /a CHECKS+=1
call "%TOOL_ROOT%win_secure.cmd" %~1 %~2 >nul
if errorlevel 1 (
    echo [失败] 命令失败：%~1 %~2
    set /a FAILURES+=1
) else (
    echo [完成] 命令通过：%~1 %~2
)
exit /b 0
