@echo off
setlocal EnableDelayedExpansion
title Stop Blockchain Services
cd /d "%~dp0"

echo ==========================================================
echo        Stopping Blockchain Document Verification
echo ==========================================================
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ports = 8545, 3000; foreach ($p in $ports) { try { $conns = Get-NetTCPConnection -LocalPort $p -State Listen -ErrorAction SilentlyContinue; foreach ($c in $conns) { Stop-Process -Id $c.OwningProcess -Force -ErrorAction SilentlyContinue; Write-Host ('[OK] Stopped PID ' + $c.OwningProcess + ' on port ' + $p) -ForegroundColor Green } } catch {} }; Start-Sleep -Seconds 2"

echo.
echo Cleaned up all services running on ports 8545 and 3000.
