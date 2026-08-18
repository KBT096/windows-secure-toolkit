@echo off
setlocal EnableExtensions DisableDelayedExpansion
chcp 65001 >nul

set "TOOL_ROOT=%~dp0"
set "ENGINE=%TOOL_ROOT%src\bin\Release\net48\WinSecure.exe"
set "DOTNET_EXE="
for /f "delims=" %%P in ('where dotnet.exe 2^>nul') do (
    if not defined DOTNET_EXE set "DOTNET_EXE=%%P"
)

if not exist "%ENGINE%" (
    if not defined DOTNET_EXE (
        echo [错误] 找不到 WinSecure.exe，也找不到 .NET SDK。
        echo 请先运行 build.cmd，或从 Release 下载已编译版本。
        exit /b 2
    )
    call "%TOOL_ROOT%build.cmd"
    if errorlevel 1 exit /b 1
)

"%ENGINE%" %*
exit /b %ERRORLEVEL%
