---
document_title: "Wave 2 Testing Guide"
author: "Codex-PD-002 (Platform DevOps)"
last_updated: 2025-11-24
status: Published
related_initiatives:
  - initiatives/device-onboarding
linked_communications:
  - docs/communications/COMMUNICATION_LOG.md#2025-11-24-wave2-completion
---

# Wave 2 Testing Guide

**Purpose:** Guide for testing Wave 2 implementations (Cloudflare Access mapping, certificate enrollment, Tailscale ACL drift checks)

---

## Prerequisites

### 1. Tailscale API Key

**Generate Read-Only API Key:**
```bash
./scripts/tailscale/generate-readonly-api-key.sh
```

**Configure API Key:**
```bash
export TAILSCALE_API_KEY="tskey-api-readonly-..."
```

**Verify API Key:**
```bash
curl -u "${TAILSCALE_API_KEY}:" \
  "https://api.tailscale.com/api/v2/tailnet/tail2e55fe.ts.net/acl" | jq '.'
```

### 2. Ansible Environment

**Verify Ansible Setup:**
```bash
cd ansible
ansible-playbook -i inventory/hosts.yml playbooks/diag_no_prompts.yml
```

---

## Testing Cloudflare Access Mapping

### Validate Device Persona Mapping

```bash
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/validate-cloudflare-access.yml
```

**Expected Output:**
- Device personas mapped correctly
- Cloudflare Access groups identified (`group:devs`, `group:owners`)
- Certificate enrollment status (NOT REQUIRED)

### Test Access Policies (Manual)

**NoMachine Access:**
1. Verify user is in `group:devs` or `group:owners` (Entra ID)
2. Access NoMachine via Cloudflare Access (once configured)
3. Verify MFA requirement

**SSH Access:**
1. Verify user is in `group:devs` or `group:owners` (Entra ID)
2. Access SSH via Cloudflare Access (once configured)
3. Verify MFA requirement

---

## Testing Tailscale ACL Drift Checks

### Run ACL Drift Check

```bash
export TAILSCALE_API_KEY="tskey-api-readonly-..."
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/validate-tailscale-acl-drift.yml
```

**Expected Output:**
- ACL configuration fetched from Tailscale API
- Device tags compared against ACL tagOwners
- SSH rules validated
- NoMachine port rules validated
- Drift report generated

### Check Mode (Dry Run)

```bash
export TAILSCALE_API_KEY="tskey-api-readonly-..."
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/validate-tailscale-acl-drift.yml --check
```

---

## Testing Certificate Enrollment (Optional)

**Note:** Certificate enrollment is NOT REQUIRED for current Cloudflare Access architecture. This test is for future use if Cloudflare Gateway is deployed.

### Test Certificate Enrollment Role

```bash
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/enroll-certificates.yml --limit count-zero
```

**Expected Output:**
- Cloudflare WARP client installation (if not installed)
- Certificate enrollment status
- Validation report

---

## Validation Checklist

### Cloudflare Access Mapping
- [ ] Device personas mapped correctly
- [ ] Cloudflare Access groups identified
- [ ] Access policies documented
- [ ] Certificate enrollment status confirmed (NOT REQUIRED)

### Tailscale ACL Drift Checks
- [ ] API key configured
- [ ] ACL configuration fetched successfully
- [ ] Device tags validated against ACL tagOwners
- [ ] SSH rules validated
- [ ] NoMachine port rules validated
- [ ] Drift report generated

### Documentation
- [ ] Cloudflare Access mapping documented
- [ ] Certificate enrollment role documented
- [ ] ACL drift check playbook documented
- [ ] Testing guide created

---

## Troubleshooting

### Tailscale API Key Issues

**Error:** `Tailscale API key not configured`
**Solution:** Set `TAILSCALE_API_KEY` environment variable

**Error:** `401 Unauthorized`
**Solution:** Verify API key is correct and has read-only permissions

**Error:** `404 Not Found`
**Solution:** Verify tailnet name (`tail2e55fe.ts.net`)

### Cloudflare Access Issues

**Error:** `Device persona not found`
**Solution:** Verify device inventory includes all devices

**Error:** `Cloudflare Access group not found`
**Solution:** Verify Entra ID groups exist (`group:devs`, `group:owners`)

---

## Related Documentation

- [Cloudflare Access Mapping](./cloudflare-access-mapping.md)
- [Certificate Enrollment Role](../../ansible/roles/certificate_enrollment/README.md)
- [Tailscale ACL Drift Check Playbook](../../ansible/playbooks/validate-tailscale-acl-drift.yml)
- [Wave 2 Coordination Response](../communications/WAVE2_COORDINATION_RESPONSE_RECEIVED.md)

---

**End of Testing Guide**

