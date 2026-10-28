# ==========================================================
# Blockchain Document Verification - Startup Script
# ==========================================================
$ErrorActionPreference = "Stop"

# Set Window Title
try {
    $host.UI.RawUI.WindowTitle = "Blockchain Document Verification"
} catch {}

function Write-Step($step, $text) {
    Write-Host "[$step] " -ForegroundColor Cyan -NoNewline
    Write-Host $text -ForegroundColor White
}

function Write-Success($text) {
    Write-Host "      [OK] $text" -ForegroundColor Green
}

function Write-WarnMsg($text) {
    Write-Host "      [WARN] $text" -ForegroundColor Yellow
}

function Write-Fail($text) {
    Write-Host "      [FAIL] $text" -ForegroundColor Red
}

function Test-Port($port) {
    $tcp = New-Object System.Net.Sockets.TcpClient
    try {
        $iar = $tcp.BeginConnect("127.0.0.1", $port, $null, $null)
        $wait = $iar.AsyncWaitHandle.WaitOne(400, $false)
        if ($wait -and $tcp.Connected) {
            $tcp.EndConnect($iar)
            return $true
        }
        return $false
    } catch {
        return $false
    } finally {
        $tcp.Dispose()
    }
}

function Stop-PortProcess($port) {
    try {
        $conns = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
        foreach ($c in $conns) {
            $procId = $c.OwningProcess
            if ($procId -gt 0) {
                Write-WarnMsg "Stopping existing process on port $port (PID: $procId)..."
                Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue
            }
        }
    } catch {
        $lines = netstat -ano | Select-String ":$port\s"
        foreach ($line in $lines) {
            $parts = $line.ToString().Trim() -split '\s+'
            $pidToKill = $parts[-1]
            if ($pidToKill -as [int] -and [int]$pidToKill -gt 0) {
                taskkill /F /PID $pidToKill 2>$null | Out-Null
            }
        }
    }
}

Clear-Host
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "        Blockchain Document Verification Launcher         " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Check Node.js
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Fail "Node.js was not found in your system PATH."
    Write-Host "Please download and install Node.js from https://nodejs.org/" -ForegroundColor Yellow
    Read-Host "Press Enter to exit..."
    exit 1
}

# 2. Check Dependencies
if (-not (Test-Path "$PSScriptRoot\node_modules")) {
    Write-Step "1/4" "Installing project dependencies (npm install)..."
    Start-Process -FilePath "npm.cmd" -ArgumentList "install" -WorkingDirectory $PSScriptRoot -Wait -NoNewWindow
    if ($LASTEXITCODE -ne 0) {
        Write-Fail "npm install failed. Please check your internet connection."
        Read-Host "Press Enter to exit..."
        exit 1
    }
    Write-Success "Dependencies installed successfully."
} else {
    Write-Step "1/4" "Dependencies already installed."
    Write-Success "node_modules present."
}

# 3. Blockchain Node
Write-Step "2/4" "Preparing local blockchain node (port 8545)..."
$hardhatProc = $null
$weStartedNode = $false

if (Test-Port 8545) {
    Write-Success "Local blockchain node is already active on port 8545."
} else {
    Write-Host "      Starting Hardhat blockchain node in background..." -ForegroundColor Gray
    $logFile = Join-Path $PSScriptRoot "hardhat.log"
    if (Test-Path $logFile) { Remove-Item $logFile -Force }

    $hardhatProc = Start-Process -FilePath "cmd.exe" -ArgumentList "/c npx hardhat node > `"$logFile`" 2>&1" -WorkingDirectory $PSScriptRoot -PassThru -WindowStyle Hidden
    $weStartedNode = $true

    # Wait for node to be responsive
    $maxSeconds = 25
    $ready = $false
    for ($i = 0; $i -lt ($maxSeconds * 2); $i++) {
        Start-Sleep -Milliseconds 500
        if (Test-Port 8545) {
            $ready = $true
            break
        }
        if ($hardhatProc.HasExited) {
            break
        }
    }

    if (-not $ready) {
        Write-Fail "Failed to start local blockchain node."
        if (Test-Path $logFile) {
            Write-Host "`n--- Recent hardhat.log output ---" -ForegroundColor Yellow
            Get-Content $logFile -Tail 15
        }
        Read-Host "Press Enter to exit..."
        exit 1
    }
    Write-Success "Hardhat blockchain node running (port 8545)."
}

# 4. Deploy Smart Contract
Write-Step "3/4" "Deploying smart contract to local network..."
$deployOutput = & cmd.exe /c npx hardhat run scripts/deploy.js --network localhost 2>&1
$deployExit = $LASTEXITCODE

if ($deployExit -ne 0) {
    Write-Fail "Smart contract deployment failed:"
    $deployOutput | ForEach-Object { Write-Host "      $_" -ForegroundColor Red }
    if ($weStartedNode -and $hardhatProc -and -not $hardhatProc.HasExited) {
        taskkill /F /T /PID $hardhatProc.Id 2>$null | Out-Null
    }
    Read-Host "Press Enter to exit..."
    exit 1
}

$contractAddress = "unknown"
if (Test-Path "$PSScriptRoot\deployment.json") {
    try {
        $dep = Get-Content "$PSScriptRoot\deployment.json" -Raw | ConvertFrom-Json
        $contractAddress = $dep.address
    } catch {}
}
Write-Success "Contract deployed successfully at $contractAddress"

# 5. Check Web Server Port 3000
if (Test-Port 3000) {
    Write-WarnMsg "Port 3000 is occupied. Stopping previous server process..."
    Stop-PortProcess 3000
    Start-Sleep -Milliseconds 800
}

# 6. Launch Browser & Start Server
Write-Step "4/4" "Launching web application..."
Start-Process "http://localhost:3000"

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "   Blockchain Document Verification is LIVE!              " -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "  URL:       http://localhost:3000" -ForegroundColor Cyan
Write-Host "  Admin Key: admin" -ForegroundColor Yellow
Write-Host "  Contract:  $contractAddress" -ForegroundColor Gray
Write-Host "----------------------------------------------------------" -ForegroundColor DarkGray
Write-Host "  Press Ctrl+C to stop both web server and blockchain node." -ForegroundColor Gray
Write-Host "==========================================================" -ForegroundColor Green
Write-Host ""

try {
    & node "$PSScriptRoot\server.js"
} finally {
    Write-Host "`nShutting down services..." -ForegroundColor Yellow
    if ($weStartedNode -and $hardhatProc -and -not $hardhatProc.HasExited) {
        Write-Host "Stopping blockchain node..." -ForegroundColor Gray
        taskkill /F /T /PID $hardhatProc.Id 2>$null | Out-Null
    }
    Stop-PortProcess 3000
    Write-Host "All services stopped." -ForegroundColor Green
}
