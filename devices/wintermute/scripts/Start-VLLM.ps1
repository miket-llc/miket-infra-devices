<#
.SYNOPSIS
    Manages vLLM Docker container on Windows with Docker Desktop
.DESCRIPTION
    Starts, stops, and manages vLLM inference containers using Docker Desktop
    with NVIDIA GPU support via WSL2 backend
.PARAMETER Action
    Action to perform: Start, Stop, Restart, Status, Logs
.PARAMETER Model
    Model name to serve (default from config)
.PARAMETER Port
    API port (default: 8000)
#>

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('Start', 'Stop', 'Restart', 'Status', 'Logs')]
    [string]$Action,
    
    [string]$Model = "mistralai/Mistral-7B-Instruct-v0.2",
    [int]$Port = 8000,
    [string]$ContainerName = "vllm-wintermute"
)

$ErrorActionPreference = "Stop"
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigPath = Join-Path (Split-Path $ScriptPath -Parent) "config.yml"

# Load configuration if available
$Config = @{
    Model = $Model
    Port = $Port
    ContainerName = $ContainerName
    Image = "vllm/vllm-openai:latest"
    GpuCount = 1
    MaxModelLen = 9000
    MaxNumSeqs = 2
    GpuMemoryUtilization = 0.88
    TensorParallelSize = 1
    Quantization = $null
    Dtype = $null
    KvCacheDtype = $null
    ServedModelName = $null
}

if (Test-Path $ConfigPath) {
    try {
        $yamlContent = Get-Content $ConfigPath -Raw
        # Simple YAML parsing (basic) - matches within vllm section
        if ($yamlContent -match 'model:\s*"([^"]+)"') {
            $Config.Model = $matches[1].Trim()
        }
        if ($yamlContent -match 'port:\s*(\d+)') {
            $Config.Port = [int]$matches[1]
        }
        if ($yamlContent -match 'container_name:\s*"([^"]+)"') {
            $Config.ContainerName = $matches[1].Trim()
        }
        if ($yamlContent -match 'max_model_len:\s*(\d+)') {
            $Config.MaxModelLen = [int]$matches[1]
        }
        if ($yamlContent -match 'max_num_seqs:\s*(\d+)') {
            $Config.MaxNumSeqs = [int]$matches[1]
        }
        if ($yamlContent -match 'gpu_memory_utilization:\s*([\d.]+)') {
            $Config.GpuMemoryUtilization = [double]$matches[1]
        }
        if ($yamlContent -match 'quantization:\s*"([^"]+)"') {
            $Config.Quantization = $matches[1].Trim()
        }
        if ($yamlContent -match 'dtype:\s*"([^"]+)"') {
            $Config.Dtype = $matches[1].Trim()
        }
        if ($yamlContent -match 'kv_cache_dtype:\s*"([^"]+)"') {
            $Config.KvCacheDtype = $matches[1].Trim()
        }
        if ($yamlContent -match 'served_model_name:\s*"([^"]+)"') {
            $Config.ServedModelName = $matches[1].Trim()
        }
    } catch {
        Write-Warning "Could not parse config file: $_"
    }
}

function Test-DockerAvailable {
    $dockerService = Get-Service -Name "com.docker.service" -ErrorAction SilentlyContinue
    if (-not $dockerService -or $dockerService.Status -ne 'Running') {
        Write-Error "Docker Desktop service is not running. Please start Docker Desktop."
        return $false
    }
    
    try {
        docker version 2>&1 | Out-Null
        return ($LASTEXITCODE -eq 0)
    } catch {
        Write-Error "Docker is not accessible. Is Docker Desktop running?"
        return $false
    }
}

function Test-NvidiaGPU {
    $nvidiaSmi = "${env:ProgramFiles}\NVIDIA Corporation\NVSMI\nvidia-smi.exe"
    if (-not (Test-Path $nvidiaSmi)) {
        Write-Warning "NVIDIA GPU tools not found. GPU acceleration may not work."
        return $false
    }
    
    try {
        $gpuInfo = & $nvidiaSmi --query-gpu=name --format=csv,noheader 2>&1
        if ($LASTEXITCODE -eq 0 -and $gpuInfo) {
            Write-Host "Detected GPU: $gpuInfo"
            return $true
        }
    } catch {
        Write-Warning "Could not query GPU: $_"
    }
    
    return $false
}

function Get-ContainerStatus {
    if (-not (Test-DockerAvailable)) {
        return "docker_unavailable"
    }
    
    try {
        $container = docker ps -a --filter "name=$($Config.ContainerName)" --format "{{.Status}}" 2>&1
        if ($LASTEXITCODE -eq 0 -and $container) {
            if ($container -like "*Up*") {
                return "running"
            } else {
                return "stopped"
            }
        }
        return "not_found"
    } catch {
        return "error"
    }
}

function Start-VLLM {
    if (-not (Test-DockerAvailable)) {
        return $false
    }
    
    $status = Get-ContainerStatus
    if ($status -eq "running") {
        Write-Host "vLLM container is already running"
        return $true
    }
    
    Write-Host "Starting vLLM container..."
    Write-Host "  Model: $($Config.Model)"
    Write-Host "  Port: $($Config.Port)"
    Write-Host "  Container: $($Config.ContainerName)"
    Write-Host "  Max Model Length: $($Config.MaxModelLen)"
    Write-Host "  Max Num Seqs: $($Config.MaxNumSeqs)"
    Write-Host "  GPU Memory Utilization: $($Config.GpuMemoryUtilization)"
    if ($Config.ServedModelName) {
        Write-Host "  Served Model Name: $($Config.ServedModelName)"
    }
    if ($Config.KvCacheDtype) {
        Write-Host "  KV Cache Dtype: $($Config.KvCacheDtype)"
    }
    
    # Check if container exists and remove if stopped
    if ($status -eq "stopped") {
        Write-Host "Removing stopped container..."
        docker rm $Config.ContainerName 2>&1 | Out-Null
    }
    
    # Build docker run command
    # Note: vllm/vllm-openai image has entrypoint pre-configured, just pass model args
    # vLLM 0.11.0+ requires V1 engine, so we don't disable it
    $dockerArgs = @(
        "run",
        "-d",
        "--name", $Config.ContainerName,
        "--gpus", "all",
        "-p", "$($Config.Port):8000",
        "--restart", "unless-stopped",
        "--shm-size", "4g",
        "-e", "VLLM_ALLOW_LONG_MAX_MODEL_LEN=1",
        $Config.Image,
        "--model", $Config.Model,
        "--max-model-len", $Config.MaxModelLen.ToString(),
        "--max-num-seqs", $Config.MaxNumSeqs.ToString(),
        "--gpu-memory-utilization", $Config.GpuMemoryUtilization.ToString(),
        "--port", "8000",
        "--host", "0.0.0.0",
        "--tensor-parallel-size", $Config.TensorParallelSize.ToString()
    )
    
    # Add served-model-name if specified (required for LiteLLM routing)
    if ($Config.ServedModelName) {
        $dockerArgs += "--served-model-name"
        $dockerArgs += $Config.ServedModelName
    }
    
    # Add dtype if specified
    if ($Config.Dtype) {
        $dockerArgs += "--dtype"
        $dockerArgs += $Config.Dtype
    }
    
    # Add KV cache dtype if specified (for memory optimization with long contexts)
    if ($Config.KvCacheDtype) {
        $dockerArgs += "--kv-cache-dtype"
        $dockerArgs += $Config.KvCacheDtype
    }
    
    # Add quantization parameter if specified
    if ($Config.Quantization) {
        $dockerArgs += "--quantization"
        $dockerArgs += $Config.Quantization
    }
    
    try {
        & docker $dockerArgs
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ vLLM container started successfully"
            Write-Host "API available at: http://localhost:$($Config.Port)"
            Write-Host "Tailnet: http://wintermute.pangolin-vega.ts.net:$($Config.Port)"
            return $true
        } else {
            Write-Error "Failed to start container"
            return $false
        }
    } catch {
        Write-Error "Error starting container: $_"
        return $false
    }
}

function Stop-VLLM {
    if (-not (Test-DockerAvailable)) {
        return $false
    }
    
    $status = Get-ContainerStatus
    if ($status -eq "not_found") {
        Write-Host "vLLM container not found"
        return $true
    }
    
    if ($status -eq "stopped") {
        Write-Host "vLLM container is already stopped"
        return $true
    }
    
    Write-Host "Stopping vLLM container..."
    try {
        docker stop $Config.ContainerName
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ vLLM container stopped"
            return $true
        } else {
            Write-Error "Failed to stop container"
            return $false
        }
    } catch {
        Write-Error "Error stopping container: $_"
        return $false
    }
}

function Restart-VLLM {
    Write-Host "Restarting vLLM container..."
    Stop-VLLM | Out-Null
    Start-Sleep -Seconds 2
    return Start-VLLM
}

function Show-Status {
    Write-Host "`nvLLM Container Status" -ForegroundColor Cyan
    Write-Host "======================" -ForegroundColor Cyan
    
    if (-not (Test-DockerAvailable)) {
        Write-Host "❌ Docker Desktop is not running" -ForegroundColor Red
        return
    }
    
    $status = Get-ContainerStatus
    $gpuAvailable = Test-NvidiaGPU
    
    Write-Host "Docker: ✅ Running"
    Write-Host "GPU: $(if ($gpuAvailable) { '✅ Available' } else { '⚠️  Not detected' })"
    Write-Host "Container: $status"
    
    if ($status -eq "running") {
        Write-Host "`nContainer Details:" -ForegroundColor Yellow
        docker ps --filter "name=$($Config.ContainerName)" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        
        Write-Host "`nAPI Endpoint: http://localhost:$($Config.Port)" -ForegroundColor Green
        Write-Host "Tailnet: http://wintermute.pangolin-vega.ts.net:$($Config.Port)" -ForegroundColor Green
        Write-Host "Health Check: http://localhost:$($Config.Port)/health" -ForegroundColor Green
    }
}

function Show-Logs {
    if (-not (Test-DockerAvailable)) {
        Write-Error "Docker Desktop is not running"
        return
    }
    
    $status = Get-ContainerStatus
    if ($status -ne "running") {
        Write-Error "Container is not running"
        return
    }
    
    docker logs -f $Config.ContainerName
}

# Main execution
switch ($Action) {
    "Start" {
        Start-VLLM
    }
    "Stop" {
        Stop-VLLM
    }
    "Restart" {
        Restart-VLLM
    }
    "Status" {
        Show-Status
    }
    "Logs" {
        Show-Logs
    }
}

