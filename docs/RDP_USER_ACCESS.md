# RDP User Access Configuration

## Overview

By default, Windows only allows users in the "Remote Desktop Users" group to connect via RDP. The RDP configuration role now automatically adds all Administrators to this group, ensuring that:

- All administrator accounts (including Microsoft accounts) can access RDP
- The `mdt` automation account can access RDP
- Any additional users specified in `rdp_users` variable are added

## Automatic Configuration

The `remote_server_windows_rdp` role now includes a task that:

1. **Adds all Administrators to Remote Desktop Users group**
   - This includes local administrators
   - This includes Microsoft accounts that are administrators
   - This ensures admin accounts can always RDP

2. **Adds additional users** (if configured)
   - Set `rdp_users` variable in host_vars or group_vars
   - Example: `rdp_users: ["username1", "username2"]`

## Verifying RDP Access

To check who has RDP access:

```powershell
# On the Windows device
Get-LocalGroupMember -Group "Remote Desktop Users" | Format-Table Name, PrincipalSource
```

## Adding Users Manually (if needed)

If you need to add a specific user to Remote Desktop Users:

```powershell
# For local users
Add-LocalGroupMember -Group "Remote Desktop Users" -Member "username"

# For Microsoft accounts (use the full account name)
Add-LocalGroupMember -Group "Remote Desktop Users" -Member "MicrosoftAccount\email@domain.com"
```

## Microsoft Account Authentication

When connecting via RDP with a Microsoft account:

1. **Use the full account format:**
   - Format: `MicrosoftAccount\your-email@domain.com`
   - Or just your email address (Windows will resolve it)

2. **If authentication fails:**
   - Verify the account is in Administrators group
   - Verify the account is in Remote Desktop Users group
   - Try using the full Microsoft account format

## Configuration Variables

You can configure additional RDP users in host_vars:

```yaml
# ansible/host_vars/armitage.yml
rdp_users:
  - "username1"
  - "username2"
```

These users will be automatically added to the Remote Desktop Users group when the RDP role runs.

## Troubleshooting

### "The credentials that were used to connect to [computer] did not work"

This means the user is not in the Remote Desktop Users group. Solutions:

1. **Run the RDP configuration playbook again:**
   ```bash
   ansible-playbook -i inventory/hosts.yml playbooks/configure-windows-rdp.yml --limit armitage
   ```

2. **Manually add the user (on armitage):**
   ```powershell
   # Find your Microsoft account name
   Get-LocalUser | Where-Object { $_.PrincipalSource -eq "MicrosoftAccount" }
   
   # Add to Remote Desktop Users
   Add-LocalGroupMember -Group "Remote Desktop Users" -Member "MicrosoftAccount\your-email@domain.com"
   ```

3. **Verify the user is an administrator:**
   ```powershell
   Get-LocalGroupMember -Group "Administrators"
   ```

### "The remote computer requires Network Level Authentication"

This is expected and configured. Ensure you're using an RDP client that supports NLA (most modern clients do).

## Summary

- ✅ All Administrators are automatically added to Remote Desktop Users
- ✅ Microsoft accounts that are administrators can access RDP
- ✅ Additional users can be configured via `rdp_users` variable
- ✅ The `mdt` automation account has RDP access



