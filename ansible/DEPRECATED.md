# Deprecated Playbooks

## deploy-motoko-embeddings.yml

**Status:** Deprecated - Consolidated into `ansible/playbooks/motoko/deploy-vllm.yml`

This playbook has been replaced by the `vllm-motoko` role which handles both reasoning and embeddings models in a unified way.

**Migration:**
- Use `ansible/playbooks/motoko/deploy-vllm.yml` instead
- The new playbook uses the `vllm-motoko` role with better GPU allocation and health checks

**Removal Date:** After verification that new playbook works correctly

---

## deploy-litellm.yml (root)

**Status:** Moved to `ansible/playbooks/motoko/deploy-litellm.yml`

This playbook has been moved to the proper location in the playbooks directory structure.

**Migration:**
- Use `ansible/playbooks/motoko/deploy-litellm.yml` instead

