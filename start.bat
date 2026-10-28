@echo off
setlocal EnableDelayedExpansion
title Blockchain Document Verification Launcher
cd /d "%~dp0"

echo ==========================================================
echo        Blockchain Document Verification Launcher
echo ==========================================================
echo.

:: Check if PowerShell is available
where powershell >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0start.ps1"
    if !ERRORLEVEL! NEQ 0 (
        echo.
        echo [ERROR] Launcher stopped due to an error.
        pause
    )
    goto :eof
)

echo [ERROR] PowerShell is required to run the automated startup.
pause
