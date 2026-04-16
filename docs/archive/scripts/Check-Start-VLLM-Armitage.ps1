<#
.SYNOPSIS
    Check and start vLLM container on Armitage
.DESCRIPTION
    This script checks the vLLM container status and starts it if needed.
    Run this directly on armitage if Ansible connectivity is unavailable.
#>

$ErrorActionPreference = "Continue"

Write-Host "=== Armitage vLLM Container Status ===" -ForegroundColor Cyan
Write-Host ""

# Check Docker service
Write-Host "[1/5] Checking Docker service..." -ForegroundColor Yellow
$dockerService = Get-Service -Name "com.docker.service" -ErrorAction SilentlyContinue
if ($dockerService -and $dockerService.Status -eq 'Running') {
    Write-Host "  ✅ Docker service is running" -ForegroundColor Green
} else {
    Write-Host "  ❌ Docker service is not running" -ForegroundColor Red
    Write-Host "  Please start Docker Desktop and try again" -ForegroundColor Yellow
    exit 1
}

# Check if scripts exist
Write-Host ""
Write-Host "[2/5] Checking deployment scripts..." -ForegroundColor Yellow
$scriptPath = "C:\Users\mdt\dev\armitage\scripts\Start-VLLM.ps1"
if (Test-Path $scriptPath) {
    Write-Host "  ✅ Start-VLLM.ps1 found" -ForegroundColor Green
} else {
    Write-Host "  ⚠️  Start-VLLM.ps1 not found at: $scriptPath" -ForegroundColor Yellow
    Write-Host "  Deployment may not have completed" -ForegroundColor Yellow
}

# Check Docker containers
Write-Host ""
Write-Host "[3/5] Checking Docker containers..." -ForegroundColor Yellow
$allContainers = docker ps -a 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✅ Docker is accessible" -ForegroundColor Green
    
    $vllmContainer = docker ps -a --filter name=vllm-armitage 2>&1
    if ($vllmContainer -match "vllm-armitage") {
        Write-Host "  ✅ vLLM container found" -ForegroundColor Green
        Write-Host ""
        Write-Host "Container status:" -ForegroundColor Cyan
        docker ps -a --filter name=vllm-armitage
    } else {
        Write-Host "  ⚠️  vLLM container not found" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "All containers:" -ForegroundColor Cyan
    docker ps -a
} else {
    Write-Host "  ❌ Cannot access Docker: $allContainers" -ForegroundColor Red
    exit 1
}

# Check if container is running
Write-Host ""
Write-Host "[4/5] Checking if vLLM container is running..." -ForegroundColor Yellow
$running = docker ps --filter name=vllm-armitage --format "{{.Names}}" 2>&1
if ($running -match "vllm-armitage") {
    Write-Host "  ✅ vLLM container is RUNNING" -ForegroundColor Green
    Write-Host ""
    Write-Host "Container details:" -ForegroundColor Cyan
    docker ps --filter name=vllm-armitage
    Write-Host ""
    Write-Host "Container logs (last 20 lines):" -ForegroundColor Cyan
    docker logs vllm-armitage --tail 20
} else {
    Write-Host "  ⚠️  vLLM container is NOT running" -ForegroundColor Yellow
    
    # Try to start using script if it exists
    if (Test-Path $scriptPath) {
        Write-Host ""
        Write-Host "[5/5] Starting vLLM container using Start-VLLM.ps1..." -ForegroundColor Yellow
        Push-Location (Split-Path $scriptPath)
        try {
            & .\Start-VLLM.ps1 -Action Start
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  ✅ Container start command executed" -ForegroundColor Green
                Write-Host ""
                Write-Host "Waiting for container to start..." -ForegroundColor Yellow
                Start-Sleep -Seconds 5
                
                $running = docker ps --filter name=vllm-armitage --format "{{.Names}}" 2>&1
                if ($running -match "vllm-armitage") {
                    Write-Host "  ✅ Container is now RUNNING" -ForegroundColor Green
                } else {
                    Write-Host "  ⚠️  Container may still be starting. Check logs:" -ForegroundColor Yellow
                    Write-Host "     docker logs vllm-armitage" -ForegroundColor White
                }
            } else {
                Write-Host "  ❌ Failed to start container" -ForegroundColor Red
            }
        } catch {
            Write-Host "  ❌ Error starting container: $($_.Exception.Message)" -ForegroundColor Red
        } finally {
            Pop-Location
        }
    } else {
        Write-Host ""
        Write-Host "[5/5] Start-VLLM.ps1 not found. Starting container manually..." -ForegroundColor Yellow
        
        # Check if container exists but is stopped
        $stopped = docker ps -a --filter name=vllm-armitage --filter status=exited --format "{{.Names}}" 2>&1
        if ($stopped -match "vllm-armitage") {
            Write-Host "  Found stopped container, starting it..." -ForegroundColor Yellow
            docker start vllm-armitage
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  ✅ Container started" -ForegroundColor Green
            } else {
                Write-Host "  ❌ Failed to start container. Try removing and recreating:" -ForegroundColor Red
                Write-Host "     docker rm vllm-armitage" -ForegroundColor White
                Write-Host "     # Then run deployment playbook or Start-VLLM.ps1" -ForegroundColor White
            }
        } else {
            Write-Host "  ⚠️  Container doesn't exist. Need to deploy first:" -ForegroundColor Yellow
            Write-Host "     Run from motoko:" -ForegroundColor White
            Write-Host "     ansible-playbook -i inventory/hosts.yml playbooks/armitage-vllm-deploy-scripts.yml --limit armitage" -ForegroundColor White
        }
    }
}

Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Cyan
$finalStatus = docker ps --filter name=vllm-armitage --format "{{.Names}}" 2>&1
if ($finalStatus -match "vllm-armitage") {
    Write-Host "✅ vLLM container is RUNNING" -ForegroundColor Green
    Write-Host ""
    Write-Host "API should be available at:" -ForegroundColor Cyan
    Write-Host "  http://localhost:8000/v1" -ForegroundColor White
    Write-Host "  http://armitage.pangolin-vega.ts.net:8000/v1" -ForegroundColor White
} else {
    Write-Host "⚠️  vLLM container is NOT running" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "  1. Ensure Docker Desktop is running" -ForegroundColor White
    Write-Host "  2. Run deployment playbook from motoko" -ForegroundColor White
    Write-Host "  3. Or manually start: docker run ... (see config.yml)" -ForegroundColor White
}




