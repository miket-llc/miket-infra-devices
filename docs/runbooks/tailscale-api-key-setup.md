---
document_title: "Tailscale API Key Setup Guide"
author: "Codex-NET-006 (Networking Engineer)"
last_updated: 2025-11-24
status: Published
related_initiatives:
  - initiatives/device-onboarding
linked_communications:
  - docs/communications/COMMUNICATION_LOG.md#2025-11-24-wave2-completion
---

# Tailscale API Key Setup Guide

**Purpose:** Guide for setting up and using Tailscale read-only API key for ACL drift detection.

---

## API Key Types

**Important:** Tailscale has two types of keys:

1. **Auth Keys** (`tskey-auth-*`) - For device enrollment
2. **API Keys** (`tskey-api-*`) - For API access (what we need)

The key you have (`tskey-auth-kuCAFDZNtX11CNTRL-mDWU1ZUmVkW6drg9rcUnjWr2qKSSPK7Wd`) appears to be an **auth key**, not an API key.

---

## Generate Read-Only API Key

**Use the generation script:**
```bash
./scripts/tailscale/generate-readonly-api-key.sh
```

**Or manually:**

1. Go to: https://login.tailscale.com/admin/settings/keys
2. Click "Generate API key" or "Generate access token"
3. Description: `Device Team - Read-Only ACL Drift Detection (Wave 2)`
4. Expiry: 90 days
5. **Scopes (READ-ONLY ONLY):**
   - ✅ `devices:read` (read device information)
   - ✅ `acl:read` (read ACL configuration)
   - ❌ `devices:write` (DO NOT ENABLE)
   - ❌ `acl:write` (DO NOT ENABLE)
   - ❌ `keys:write` (DO NOT ENABLE)

---

## Configure API Key

**Option 1: Environment Variable (Temporary)**
```bash
export TAILSCALE_API_KEY="tskey-api-readonly-..."
```

**Option 2: Shell Profile (Persistent)**
```bash
echo 'export TAILSCALE_API_KEY="tskey-api-readonly-..."' >> ~/.bashrc
source ~/.bashrc
```

**Option 3: Azure Key Vault (Recommended)**
Store in Azure Key Vault: `tailscale-api-key-readonly`

**Option 4: GitHub Secrets (CI/CD)**
Add to GitHub repository secrets: `TAILSCALE_API_KEY`

---

## Test API Key

**Test ACL endpoint:**
```bash
export TAILSCALE_API_KEY="tskey-api-readonly-..."
TAILNET="tail2e55fe.ts.net"

curl -u "${TAILSCALE_API_KEY}:" \
  "https://api.tailscale.com/api/v2/tailnet/${TAILNET}/acl" | jq '.'
```

**Test Devices endpoint:**
```bash
curl -u "${TAILSCALE_API_KEY}:" \
  "https://api.tailscale.com/api/v2/tailnet/${TAILNET}/devices" | jq '.devices[0:3]'
```

---

## Use in Playbooks

**Run ACL drift check:**
```bash
export TAILSCALE_API_KEY="tskey-api-readonly-..."
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/validate-tailscale-acl-drift.yml
```

---

## Security Notes

- ⚠️ **Never commit API keys to Git**
- ✅ Store securely (Azure Key Vault, GitHub Secrets, etc.)
- ✅ Rotate every 90 days
- ✅ Document expiry date and set calendar reminder

---

## Troubleshooting

**Error: "API token invalid"**
- Verify you're using an API key (`tskey-api-*`), not an auth key (`tskey-auth-*`)
- Check key hasn't expired
- Verify key has correct scopes (`devices:read`, `acl:read`)

**Error: "404 Not Found"**
- Verify tailnet name (`tail2e55fe.ts.net`)
- Check API endpoint URL is correct

---

## Related Documentation

- [Wave 2 Testing Guide](./wave2-testing-guide.md)
- [Tailscale ACL Drift Check Playbook](../../ansible/playbooks/validate-tailscale-acl-drift.yml)
- [Wave 2 Coordination Response](../communications/WAVE2_COORDINATION_RESPONSE_RECEIVED.md)

---

**End of API Key Setup Guide**

