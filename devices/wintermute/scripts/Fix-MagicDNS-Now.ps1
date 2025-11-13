#Requires -RunAsAdministrator
# Quick MagicDNS fix for Wintermute
Write-Host "Fixing MagicDNS on Wintermute..." -ForegroundColor Cyan
$tailscale = "C:\Program Files\Tailscale\tailscale.exe"
if (-not (Test-Path $tailscale)) { $tailscale = "C:\Program Files (x86)\Tailscale\tailscale.exe" }
& $tailscale up --advertise-tags=tag:workstation,tag:windows,tag:gaming --accept-routes --accept-dns
Start-Sleep -Seconds 3
Write-Host "Verifying..." -ForegroundColor Yellow
$status = & $tailscale status --json | ConvertFrom-Json
Write-Host "DNS: $($status.Self.DNS)" -ForegroundColor $(if ($status.Self.DNS) { "Green" } else { "Red" })
Write-Host "Testing hostname resolution..." -ForegroundColor Yellow
Test-NetConnection -ComputerName motoko -InformationLevel Quiet && Write-Host "✅ motoko resolves" -ForegroundColor Green || Write-Host "❌ motoko does not resolve" -ForegroundColor Red


