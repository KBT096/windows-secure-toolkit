@echo off
setlocal EnableExtensions DisableDelayedExpansion
call "%~dp0win_secure.cmd" %*
exit /b %ERRORLEVEL%
