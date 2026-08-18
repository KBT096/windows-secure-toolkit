@echo off
setlocal EnableExtensions DisableDelayedExpansion
chcp 65001 >nul

set "TOOL_ROOT=%~dp0"
where dotnet.exe >nul 2>nul
if errorlevel 1 (
    echo [错误] 未找到 .NET SDK。请安装 .NET 6 SDK 或更高版本。
    exit /b 2
)

dotnet build "%TOOL_ROOT%src\WindowsSecureToolkit.csproj" --configuration Release --nologo
exit /b %ERRORLEVEL%
