# Windows MagicDNS Fix Commands

## Armitage
Run this in PowerShell as Administrator on armitage:
```powershell
tailscale up --advertise-tags=tag:workstation,tag:windows,tag:gaming --accept-routes --accept-dns
```

## Wintermute
Run this in PowerShell as Administrator on wintermute:
```powershell
tailscale up --advertise-tags=tag:workstation,tag:windows,tag:gaming --accept-routes --accept-dns
```

## Verification (run on each):
```powershell
tailscale status --json | ConvertFrom-Json | Select-Object -ExpandProperty Self | Select-Object DNS
Test-NetConnection -ComputerName motoko -InformationLevel Quiet
```


