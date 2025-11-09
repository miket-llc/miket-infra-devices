#!/bin/bash
# Ansible Vault Helper Script
# Provides convenient commands for managing Ansible Vault files

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ANSIBLE_DIR="$REPO_ROOT/ansible"
# Use file-based vault password (no 1Password dependency)
VAULT_PASSWORD_FILE="${ANSIBLE_VAULT_PASSWORD_FILE:-/etc/ansible/.vault-pass.txt}"
USE_FILE=true

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

usage() {
    cat << EOF
Ansible Vault Helper

Usage: $0 <command> [options]

Commands:
    init                    Initialize vault structure (create directories)
    create-all              Create all vault files interactively
    create <file>           Create a specific vault file
    edit <file>             Edit a vault file
    view <file>             View a vault file contents
    generate-hash           Generate password hash for Linux/macOS
    test                    Test vault access
    list                    List all vault files

Vault Files:
    all/vault.yml           Linux/macOS user passwords
    windows/vault.yml       Windows WinRM passwords
    linux/vault.yml         Linux-specific secrets

Examples:
    $0 init
    $0 create all/vault.yml
    $0 edit windows/vault.yml
    $0 generate-hash
    $0 test

Environment Variables:
    ANSIBLE_VAULT_PASSWORD_FILE    Path to vault password file (default: /etc/ansible/.vault-pass.txt)

EOF
}

check_vault_password() {
    if [ -f "$VAULT_PASSWORD_FILE" ]; then
        VAULT_OPTS="--vault-password-file $VAULT_PASSWORD_FILE"
    else
        echo -e "${YELLOW}Warning: Vault password file not found at $VAULT_PASSWORD_FILE${NC}"
        echo "Please ensure /etc/ansible/.vault-pass.txt exists with correct permissions (600 root:root)"
        echo "See documentation for setup instructions."
        # Use vault_identity_list from ansible.cfg (no flag needed)
        VAULT_OPTS=""
    fi
}

init_vault() {
    echo -e "${GREEN}Initializing Ansible Vault structure...${NC}"
    mkdir -p "$ANSIBLE_DIR/group_vars/{all,windows,linux}"
    echo -e "${GREEN}✓ Created vault directories${NC}"
    
    if [ ! -f "$VAULT_PASSWORD_FILE" ]; then
        echo ""
        echo -e "${YELLOW}Creating vault password file...${NC}"
        read -sp "Enter vault password: " VAULT_PASS
        echo ""
        mkdir -p "$(dirname "$VAULT_PASSWORD_FILE")"
        echo "$VAULT_PASS" > "$VAULT_PASSWORD_FILE"
        chmod 600 "$VAULT_PASSWORD_FILE"
        echo -e "${GREEN}✓ Created vault password file at $VAULT_PASSWORD_FILE${NC}"
    fi
}

create_vault() {
    local vault_file="$1"
    local full_path="$ANSIBLE_DIR/group_vars/$vault_file"
    
    if [ -z "$vault_file" ]; then
        echo -e "${RED}Error: Vault file path required${NC}"
        echo "Usage: $0 create <file>"
        echo "Example: $0 create all/vault.yml"
        exit 1
    fi
    
    if [ -f "$full_path" ]; then
        echo -e "${YELLOW}Warning: Vault file already exists: $full_path${NC}"
        read -p "Overwrite? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Aborted."
            exit 1
        fi
    fi
    
    check_vault_password
    ansible-vault create "$full_path" $VAULT_OPTS
    echo -e "${GREEN}✓ Created vault file: $full_path${NC}"
}

create_all_vaults() {
    echo -e "${GREEN}Creating all vault files...${NC}"
    
    check_vault_password
    
    # Create Linux/macOS user passwords vault
    if [ ! -f "$ANSIBLE_DIR/group_vars/all/vault.yml" ]; then
        echo "Creating all/vault.yml..."
        ansible-vault create "$ANSIBLE_DIR/group_vars/all/vault.yml" $VAULT_OPTS
    else
        echo -e "${YELLOW}Skipping all/vault.yml (already exists)${NC}"
    fi
    
    # Create Windows passwords vault
    if [ ! -f "$ANSIBLE_DIR/group_vars/windows/vault.yml" ]; then
        echo "Creating windows/vault.yml..."
        ansible-vault create "$ANSIBLE_DIR/group_vars/windows/vault.yml" $VAULT_OPTS
    else
        echo -e "${YELLOW}Skipping windows/vault.yml (already exists)${NC}"
    fi
    
    # Create Linux secrets vault
    if [ ! -f "$ANSIBLE_DIR/group_vars/linux/vault.yml" ]; then
        echo "Creating linux/vault.yml..."
        ansible-vault create "$ANSIBLE_DIR/group_vars/linux/vault.yml" $VAULT_OPTS
    else
        echo -e "${YELLOW}Skipping linux/vault.yml (already exists)${NC}"
    fi
    
    echo -e "${GREEN}✓ All vault files created${NC}"
}

edit_vault() {
    local vault_file="$1"
    local full_path="$ANSIBLE_DIR/group_vars/$vault_file"
    
    if [ -z "$vault_file" ]; then
        echo -e "${RED}Error: Vault file path required${NC}"
        exit 1
    fi
    
    if [ ! -f "$full_path" ]; then
        echo -e "${RED}Error: Vault file not found: $full_path${NC}"
        echo "Create it first with: $0 create $vault_file"
        exit 1
    fi
    
    check_vault_password
    ansible-vault edit "$full_path" $VAULT_OPTS
}

view_vault() {
    local vault_file="$1"
    local full_path="$ANSIBLE_DIR/group_vars/$vault_file"
    
    if [ -z "$vault_file" ]; then
        echo -e "${RED}Error: Vault file path required${NC}"
        exit 1
    fi
    
    if [ ! -f "$full_path" ]; then
        echo -e "${RED}Error: Vault file not found: $full_path${NC}"
        exit 1
    fi
    
    check_vault_password
    ansible-vault view "$full_path" $VAULT_OPTS
}

generate_hash() {
    echo -e "${GREEN}Password Hash Generator${NC}"
    echo ""
    read -sp "Enter password: " PASSWORD
    echo ""
    echo ""
    echo -e "${GREEN}Generated hash:${NC}"
    python3 -c "import crypt; print(crypt.crypt('$PASSWORD', crypt.mksalt(crypt.METHOD_SHA512)))"
    echo ""
    echo "Copy this hash and use it in vault_user_passwords in all/vault.yml"
}

test_vault() {
    echo -e "${GREEN}Testing vault access...${NC}"
    check_vault_password
    
    local failed=0
    
    for vault_file in all/vault.yml windows/vault.yml linux/vault.yml; do
        local full_path="$ANSIBLE_DIR/group_vars/$vault_file"
        if [ -f "$full_path" ]; then
            if ansible-vault view "$full_path" $VAULT_OPTS > /dev/null 2>&1; then
                echo -e "${GREEN}✓ $vault_file${NC}"
            else
                echo -e "${RED}✗ $vault_file (decryption failed)${NC}"
                failed=1
            fi
        else
            echo -e "${YELLOW}○ $vault_file (not found)${NC}"
        fi
    done
    
    if [ $failed -eq 0 ]; then
        echo -e "${GREEN}✓ All vault files accessible${NC}"
    else
        echo -e "${RED}✗ Some vault files failed decryption${NC}"
        exit 1
    fi
}

list_vaults() {
    echo -e "${GREEN}Ansible Vault Files:${NC}"
    echo ""
    
    for vault_file in all/vault.yml windows/vault.yml linux/vault.yml; do
        local full_path="$ANSIBLE_DIR/group_vars/$vault_file"
        if [ -f "$full_path" ]; then
            local size=$(stat -f%z "$full_path" 2>/dev/null || stat -c%s "$full_path" 2>/dev/null)
            echo -e "${GREEN}✓${NC} $vault_file ($size bytes)"
        else
            echo -e "${YELLOW}○${NC} $vault_file (not created)"
        fi
    done
}

# Main command handler
case "${1:-}" in
    init)
        init_vault
        ;;
    create)
        if [ "$2" = "all" ] || [ -z "$2" ]; then
            create_all_vaults
        else
            create_vault "$2"
        fi
        ;;
    create-all)
        create_all_vaults
        ;;
    edit)
        edit_vault "$2"
        ;;
    view)
        view_vault "$2"
        ;;
    generate-hash)
        generate_hash
        ;;
    test)
        test_vault
        ;;
    list)
        list_vaults
        ;;
    *)
        usage
        exit 1
        ;;
esac

