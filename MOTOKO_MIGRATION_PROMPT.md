# Prompt for Motoko Migration Execution

Copy and paste this prompt when you SSH into motoko:

---

**I'm now on motoko and ready to execute the OneDrive to /space migration. Here's the current status:**

**Prerequisites Check:**
- Rclone is installed
- Disk space verified (11TB available on /space)
- /space/mike directory exists
- Migration script and Ansible automation deployed

**Next Steps:**
1. Pull latest changes from git repository
2. Configure Rclone M365 remote (if not already done)
3. Execute Phase 1: Assessment & Preparation (inventory OneDrive content)
4. Execute Phase 2: Dry Run Migration
5. Execute Phase 3: Production Migration (after dry run validation)

**Please help me:**
- Pull the latest migration code
- Check if Rclone M365 remote is configured
- If not configured, guide me through setup
- Then execute the migration phases step by step

**Reference Documentation:**
- Migration Plan: `docs/initiatives/onedrive-to-space-migration/MIGRATION_PLAN.md`
- Deployment Guide: `docs/initiatives/onedrive-to-space-migration/DEPLOYMENT_GUIDE.md`
- Quick Start: `MIGRATION_QUICK_START.md`

Let's proceed with the migration execution.

---

