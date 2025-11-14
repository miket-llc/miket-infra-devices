.PHONY: help deploy-wintermute deploy-armitage deploy-proxy rollback-wintermute rollback-armitage rollback-proxy test-context test-burst backup-configs health-check

# Configuration
WINTERMUTE_HOST ?= wintermute.tailnet.local
ARMITAGE_HOST ?= armitage.tailnet.local
MOTOKO_HOST ?= motoko.tailnet.local
LITELLM_PORT ?= 8000
VLLM_PORT ?= 8000

# Directories
LOGS_DIR := logs
ARTIFACTS_DIR := artifacts
BACKUP_DIR := backups
TESTS_DIR := tests

help:
	@echo "Available targets:"
	@echo "  deploy-wintermute    - Deploy vLLM updates to Wintermute"
	@echo "  deploy-armitage      - Deploy vLLM updates to Armitage"
	@echo "  deploy-proxy         - Deploy LiteLLM proxy updates to Motoko"
	@echo "  rollback-wintermute  - Rollback Wintermute vLLM to previous config"
	@echo "  rollback-armitage    - Rollback Armitage vLLM to previous config"
	@echo "  rollback-proxy       - Rollback LiteLLM proxy to previous config"
	@echo "  backup-configs       - Backup current configurations"
	@echo "  health-check         - Check health of all services"
	@echo "  test-context         - Run context window smoke tests"
	@echo "  test-burst           - Run burst load tests"
	@echo ""
	@echo "Environment variables:"
	@echo "  WINTERMUTE_HOST     - Wintermute hostname (default: wintermute.tailnet.local)"
	@echo "  ARMITAGE_HOST       - Armitage hostname (default: armitage.tailnet.local)"
	@echo "  MOTOKO_HOST         - Motoko hostname (default: motoko.tailnet.local)"

# Create necessary directories
$(LOGS_DIR) $(ARTIFACTS_DIR) $(BACKUP_DIR):
	mkdir -p $@

# Backup configurations before deployment
backup-configs: $(BACKUP_DIR)
	@echo "Backing up configurations..."
	@timestamp=$$(date +%Y%m%d_%H%M%S); \
	mkdir -p $(BACKUP_DIR)/$$timestamp; \
	if [ -f devices/wintermute/config.yml ]; then \
		cp devices/wintermute/config.yml $(BACKUP_DIR)/$$timestamp/wintermute_config.yml; \
	fi; \
	if [ -f devices/armitage/config.yml ]; then \
		cp devices/armitage/config.yml $(BACKUP_DIR)/$$timestamp/armitage_config.yml; \
	fi; \
	if [ -f ansible/roles/litellm_proxy/templates/litellm.config.yaml.j2 ]; then \
		cp ansible/roles/litellm_proxy/templates/litellm.config.yaml.j2 $(BACKUP_DIR)/$$timestamp/litellm_config.yaml.j2; \
	fi; \
	if [ -f devices/wintermute/scripts/Start-VLLM.ps1 ]; then \
		cp devices/wintermute/scripts/Start-VLLM.ps1 $(BACKUP_DIR)/$$timestamp/wintermute_Start-VLLM.ps1; \
	fi; \
	if [ -f devices/armitage/scripts/Start-VLLM.ps1 ]; then \
		cp devices/armitage/scripts/Start-VLLM.ps1 $(BACKUP_DIR)/$$timestamp/armitage_Start-VLLM.ps1; \
	fi; \
	echo "Backups saved to $(BACKUP_DIR)/$$timestamp"

# Deploy Wintermute vLLM
deploy-wintermute: backup-configs $(LOGS_DIR)
	@echo "Deploying vLLM to Wintermute..."
	@echo "Note: This requires SSH access to Wintermute or manual execution of Start-VLLM.ps1"
	@echo "To deploy manually:"
	@echo "  1. SSH to Wintermute or use RDP"
	@echo "  2. Run: cd devices/wintermute/scripts && ./Start-VLLM.ps1 Restart"
	@echo "  3. Check logs: docker logs vllm-wintermute"
	@echo ""
	@echo "Or use WSL2:"
	@echo "  ssh wintermute 'cd /mnt/c/path/to/repo/devices/wintermute/scripts && bash vllm.sh restart'"
	@echo ""
	@echo "Waiting for service to be ready..."
	@sleep 5
	@$(MAKE) health-check-wintermute

# Deploy Armitage vLLM
deploy-armitage: backup-configs $(LOGS_DIR)
	@echo "Deploying vLLM to Armitage..."
	@echo "Note: This requires SSH access to Armitage or manual execution of Start-VLLM.ps1"
	@echo "To deploy manually:"
	@echo "  1. SSH to Armitage or use RDP"
	@echo "  2. Run: cd devices/armitage/scripts && ./Start-VLLM.ps1 Restart"
	@echo "  3. Check logs: docker logs vllm-armitage"
	@echo ""
	@echo "Waiting for service to be ready..."
	@sleep 5
	@$(MAKE) health-check-armitage

# Deploy LiteLLM proxy (requires Ansible)
deploy-proxy: backup-configs $(LOGS_DIR)
	@echo "Deploying LiteLLM proxy to Motoko..."
	@if command -v ansible-playbook >/dev/null 2>&1; then \
		echo "Running Ansible playbook..."; \
cd ansible && ansible-playbook -i inventory/hosts.yml playbooks/motoko/deploy-litellm.yml -v; \
	else \
		echo "Ansible not found. Manual deployment required:"; \
		echo "  1. SSH to Motoko"; \
		echo "  2. Restart LiteLLM service: sudo systemctl restart litellm"; \
		echo "  3. Check logs: sudo journalctl -u litellm -f"; \
	fi
	@sleep 5
	@$(MAKE) health-check-proxy

# Rollback Wintermute
rollback-wintermute: $(BACKUP_DIR)
	@echo "Available backups:"
	@ls -1t $(BACKUP_DIR) | head -5
	@echo ""
	@read -p "Enter backup timestamp to restore (YYYYMMDD_HHMMSS): " timestamp; \
	if [ -f $(BACKUP_DIR)/$$timestamp/wintermute_config.yml ]; then \
		cp $(BACKUP_DIR)/$$timestamp/wintermute_config.yml devices/wintermute/config.yml; \
		echo "Restored config.yml"; \
	fi; \
	if [ -f $(BACKUP_DIR)/$$timestamp/wintermute_Start-VLLM.ps1 ]; then \
		cp $(BACKUP_DIR)/$$timestamp/wintermute_Start-VLLM.ps1 devices/wintermute/scripts/Start-VLLM.ps1; \
		echo "Restored Start-VLLM.ps1"; \
	fi; \
	echo "Rollback complete. Restart vLLM manually."

# Rollback Armitage
rollback-armitage: $(BACKUP_DIR)
	@echo "Available backups:"
	@ls -1t $(BACKUP_DIR) | head -5
	@echo ""
	@read -p "Enter backup timestamp to restore (YYYYMMDD_HHMMSS): " timestamp; \
	if [ -f $(BACKUP_DIR)/$$timestamp/armitage_config.yml ]; then \
		cp $(BACKUP_DIR)/$$timestamp/armitage_config.yml devices/armitage/config.yml; \
		echo "Restored config.yml"; \
	fi; \
	if [ -f $(BACKUP_DIR)/$$timestamp/armitage_Start-VLLM.ps1 ]; then \
		cp $(BACKUP_DIR)/$$timestamp/armitage_Start-VLLM.ps1 devices/armitage/scripts/Start-VLLM.ps1; \
		echo "Restored Start-VLLM.ps1"; \
	fi; \
	echo "Rollback complete. Restart vLLM manually."

# Rollback LiteLLM proxy
rollback-proxy: $(BACKUP_DIR)
	@echo "Available backups:"
	@ls -1t $(BACKUP_DIR) | head -5
	@echo ""
	@read -p "Enter backup timestamp to restore (YYYYMMDD_HHMMSS): " timestamp; \
	if [ -f $(BACKUP_DIR)/$$timestamp/litellm_config.yaml.j2 ]; then \
		cp $(BACKUP_DIR)/$$timestamp/litellm_config.yaml.j2 ansible/roles/litellm_proxy/templates/litellm.config.yaml.j2; \
		echo "Restored litellm.config.yaml.j2"; \
		echo "Re-run Ansible playbook to deploy: make deploy-proxy"; \
	fi

# Health checks
health-check-wintermute:
	@echo "Checking Wintermute vLLM health..."
	@curl -s -f http://$(WINTERMUTE_HOST):$(VLLM_PORT)/v1/models > /dev/null && \
		echo "✅ Wintermute vLLM is healthy" || \
		echo "❌ Wintermute vLLM health check failed"

health-check-armitage:
	@echo "Checking Armitage vLLM health..."
	@curl -s -f http://$(ARMITAGE_HOST):$(VLLM_PORT)/v1/models > /dev/null && \
		echo "✅ Armitage vLLM is healthy" || \
		echo "❌ Armitage vLLM health check failed"

health-check-proxy:
	@echo "Checking LiteLLM proxy health..."
	@curl -s -f http://$(MOTOKO_HOST):$(LITELLM_PORT)/health > /dev/null && \
		echo "✅ LiteLLM proxy is healthy" || \
		echo "❌ LiteLLM proxy health check failed"

health-check: health-check-wintermute health-check-armitage health-check-proxy
	@echo ""
	@echo "All health checks complete"

# Test targets
test-context: $(ARTIFACTS_DIR)
	@echo "Running context window smoke tests..."
	@python3 $(TESTS_DIR)/context_smoke.py || echo "Tests failed - check $(ARTIFACTS_DIR)/context_test_results.csv"

test-burst: $(ARTIFACTS_DIR)
	@echo "Running burst load tests..."
	@python3 $(TESTS_DIR)/burst_test.py || echo "Burst tests failed - check $(ARTIFACTS_DIR)/burst_test_results.csv"

