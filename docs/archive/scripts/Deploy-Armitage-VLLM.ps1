<#
.SYNOPSIS
    Deploys updated vLLM configuration to Armitage and validates deployment
.DESCRIPTION
    This script:
    1. Copies updated config.yml and Start-VLLM.ps1 to Armitage
    2. Stops existing vLLM container
    3. Starts vLLM with new Qwen2.5-7B-Instruct (bf16) configuration
    4. Validates deployment
    5. Tests API endpoints
#>

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path $ScriptDir -Parent
$ConfigSource = Join-Path $RepoRoot "devices\armitage\config.yml"
$ScriptSource = Join-Path $RepoRoot "devices\armitage\scripts\Start-VLLM.ps1"

# Deployment locations (where scripts/config should be on Armitage)
$DeployScriptDir = "C:\Users\$env:USERNAME\dev\armitage\scripts"
$DeployConfigDir = "C:\Users\$env:USERNAME\dev\armitage"
$ConfigDest = Join-Path $DeployConfigDir "config.yml"
$ScriptDest = Join-Path $DeployScriptDir "Start-VLLM.ps1"
$VLLMScript = $ScriptDest

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  Armitage vLLM Deployment and Validation" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Copy updated files
Write-Host "[1/5] Copying updated configuration files..." -ForegroundColor Yellow

# Ensure deployment directories exist
if (-not (Test-Path $DeployScriptDir)) {
    New-Item -ItemType Directory -Path $DeployScriptDir -Force | Out-Null
    Write-Host "  Created directory: $DeployScriptDir" -ForegroundColor Cyan
}
if (-not (Test-Path $DeployConfigDir)) {
    New-Item -ItemType Directory -Path $DeployConfigDir -Force | Out-Null
    Write-Host "  Created directory: $DeployConfigDir" -ForegroundColor Cyan
}

if (Test-Path $ConfigSource) {
    Copy-Item -Path $ConfigSource -Destination $ConfigDest -Force
    Write-Host "  ✅ Copied config.yml to $ConfigDest" -ForegroundColor Green
} else {
    Write-Host "  ⚠️  Config source not found: $ConfigSource" -ForegroundColor Yellow
}

if (Test-Path $ScriptSource) {
    Copy-Item -Path $ScriptSource -Destination $ScriptDest -Force
    Write-Host "  ✅ Copied Start-VLLM.ps1 to $ScriptDest" -ForegroundColor Green
} else {
    Write-Host "  ⚠️  Script source not found: $ScriptSource" -ForegroundColor Yellow
}

# Step 2: Check Docker
Write-Host ""
Write-Host "[2/5] Checking Docker Desktop..." -ForegroundColor Yellow
$dockerService = Get-Service -Name "com.docker.service" -ErrorAction SilentlyContinue
if (-not $dockerService -or $dockerService.Status -ne 'Running') {
    Write-Host "  ❌ Docker Desktop service is not running" -ForegroundColor Red
    Write-Host "  Please start Docker Desktop and try again" -ForegroundColor Yellow
    exit 1
}
Write-Host "  ✅ Docker Desktop is running" -ForegroundColor Green

# Step 3: Stop existing container
Write-Host ""
Write-Host "[3/5] Stopping existing vLLM container..." -ForegroundColor Yellow
if (Test-Path $VLLMScript) {
    & powershell.exe -ExecutionPolicy Bypass -File $VLLMScript -Action Stop
    Start-Sleep -Seconds 3
    Write-Host "  ✅ Stopped existing container" -ForegroundColor Green
} else {
    Write-Host "  ⚠️  Start-VLLM.ps1 not found at expected location" -ForegroundColor Yellow
    # Try to stop container directly
    docker stop vllm-armitage 2>&1 | Out-Null
    docker rm vllm-armitage 2>&1 | Out-Null
}

# Step 4: Start vLLM with new configuration
Write-Host ""
Write-Host "[4/5] Starting vLLM with Qwen2.5-7B-Instruct (bf16)..." -ForegroundColor Yellow
if (Test-Path $VLLMScript) {
    & powershell.exe -ExecutionPolicy Bypass -File $VLLMScript -Action Start
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✅ vLLM container started" -ForegroundColor Green
    } else {
        Write-Host "  ❌ Failed to start vLLM container" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "  ❌ Start-VLLM.ps1 not found" -ForegroundColor Red
    exit 1
}

# Step 5: Wait for container to be ready and validate
Write-Host ""
Write-Host "[5/5] Waiting for vLLM to be ready and validating..." -ForegroundColor Yellow
$maxWait = 300  # 5 minutes
$elapsed = 0
$checkInterval = 10

while ($elapsed -lt $maxWait) {
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:8000/health" -TimeoutSec 5 -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            Write-Host "  ✅ vLLM health check passed" -ForegroundColor Green
            break
        }
    } catch {
        $percent = [math]::Round(($elapsed / $maxWait) * 100, 1)
        Write-Host "  ⏳ Waiting for vLLM to start... (${elapsed}s/${maxWait}s - ${percent}%)" -ForegroundColor Cyan
    }
    
    Start-Sleep -Seconds $checkInterval
    $elapsed += $checkInterval
}

if ($elapsed -ge $maxWait) {
    Write-Host "  ⚠️  vLLM did not become ready within timeout" -ForegroundColor Yellow
    Write-Host "  Checking container logs..." -ForegroundColor Yellow
    docker logs vllm-armitage --tail 50
    exit 1
}

# Test models endpoint
Write-Host ""
Write-Host "Testing models endpoint..." -ForegroundColor Yellow
try {
    $modelsResponse = Invoke-RestMethod -Uri "http://localhost:8000/v1/models" -Method Get -TimeoutSec 10
    Write-Host "  ✅ Models endpoint responding" -ForegroundColor Green
    
    $modelId = $modelsResponse.data[0].id
    Write-Host "  Detected Model: $modelId" -ForegroundColor Cyan
    
    if ($modelId -like "*Qwen*7B*" -and $modelId -notlike "*AWQ*") {
        Write-Host "  ✅ Model matches Qwen2.5-7B-Instruct (fp16/bf16)" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️  Model may not match expected: $modelId" -ForegroundColor Yellow
    }
    
    # Display full response
    Write-Host ""
    Write-Host "Models API Response:" -ForegroundColor Cyan
    $modelsResponse | ConvertTo-Json -Depth 10 | Write-Host
    
} catch {
    Write-Host "  ❌ Failed to query models endpoint: $_" -ForegroundColor Red
}

# Test completion endpoint
Write-Host ""
Write-Host "Testing completion endpoint..." -ForegroundColor Yellow
try {
    $completionBody = @{
        model = "Qwen/Qwen2.5-7B-Instruct"
        prompt = "Hello, how are you?"
        max_tokens = 50
    } | ConvertTo-Json

    $startTime = Get-Date
    $completionResponse = Invoke-RestMethod -Uri "http://localhost:8000/v1/completions" -Method Post -Body $completionBody -ContentType "application/json" -TimeoutSec 30
    $endTime = Get-Date
    $latency = ($endTime - $startTime).TotalSeconds

    Write-Host "  ✅ Completion endpoint working (latency: ${latency}s)" -ForegroundColor Green
    Write-Host "  Response: $($completionResponse.choices[0].text.Trim())" -ForegroundColor Cyan
    
} catch {
    Write-Host "  ⚠️  Completion test failed: $_" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  ✅ Deployment Complete" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Check container logs: docker logs vllm-armitage" -ForegroundColor White
Write-Host "  2. Check GPU usage: nvidia-smi" -ForegroundColor White
Write-Host "  3. Test from Motoko: ./scripts/Validate-Armitage-Model.sh" -ForegroundColor White
Write-Host ""

