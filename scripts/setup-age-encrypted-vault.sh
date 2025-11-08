#!/bin/bash
# Setup script for age-encrypted Ansible vault password
# Uses age encryption with SSH keys - fully automation-friendly, no external services

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}Age-Encrypted Ansible Vault Password Setup${NC}"
echo ""
echo "This creates a local encrypted file using your SSH key."
echo "No external services or logins required - perfect for automation!"
echo ""

# Check if age is installed
if ! command -v age >/dev/null 2>&1; then
    echo -e "${YELLOW}age not found. Installing...${NC}"
    
    # Try apt first (Ubuntu/Debian)
    if command -v apt >/dev/null 2>&1; then
        sudo apt update && sudo apt install -y age
    # Try with go if available
    elif command -v go >/dev/null 2>&1; then
        echo "Installing age via go..."
        go install -a github.com/FiloSottile/age/cmd/age@latest
        export PATH="$PATH:$(go env GOPATH)/bin"
    else
        echo -e "${RED}Error: Cannot install age automatically${NC}"
        echo "Install manually:"
        echo "  Ubuntu/Debian: sudo apt install age"
        echo "  Or: go install -a github.com/FiloSottile/age/cmd/age@latest"
        exit 1
    fi
fi

# Find SSH public key
SSH_KEY_PATH="${ANSIBLE_VAULT_SSH_KEY:-$HOME/.ssh/id_ed25519.pub}"

# Try common SSH key locations
if [ ! -f "$SSH_KEY_PATH" ]; then
    for key in "$HOME/.ssh/id_ed25519.pub" "$HOME/.ssh/id_rsa.pub" "$HOME/.ssh/id_ecdsa.pub"; do
        if [ -f "$key" ]; then
            SSH_KEY_PATH="$key"
            break
        fi
    done
fi

if [ ! -f "$SSH_KEY_PATH" ]; then
    echo -e "${RED}Error: No SSH public key found${NC}"
    echo "Generate one with: ssh-keygen -t ed25519 -C 'ansible-vault'"
    exit 1
fi

echo -e "${GREEN}✓ Using SSH key: $SSH_KEY_PATH${NC}"

# Get vault password
echo ""
echo -e "${YELLOW}Enter the Ansible vault password:${NC}"
echo "You can get it from 1Password, Azure Key Vault, or enter it manually."
read -sp "Vault password: " VAULT_PASSWORD
echo ""

# Create directory for encrypted file
ENCRYPTED_FILE="$HOME/.ansible/vault_pass.age"
mkdir -p "$(dirname "$ENCRYPTED_FILE")"

# Encrypt password with SSH key
echo -e "${GREEN}Encrypting password with SSH key...${NC}"
echo -n "$VAULT_PASSWORD" | age --encrypt --recipients-file "$SSH_KEY_PATH" > "$ENCRYPTED_FILE"
chmod 600 "$ENCRYPTED_FILE"

echo -e "${GREEN}✓ Password encrypted and stored: $ENCRYPTED_FILE${NC}"

# Test decryption
echo -e "${GREEN}Testing decryption...${NC}"
if ./scripts/ansible-vault-password-age.sh >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Decryption successful${NC}"
else
    echo -e "${RED}✗ Decryption failed${NC}"
    echo "Check that the SSH private key matches the public key used for encryption"
    exit 1
fi

echo ""
echo -e "${GREEN}Setup complete!${NC}"
echo ""
echo "The encrypted password file is stored at: $ENCRYPTED_FILE"
echo "It can only be decrypted with the matching SSH private key."
echo ""
echo "To use with Ansible, update ansible.cfg:"
echo "  vault_password_file = $REPO_ROOT/scripts/ansible-vault-password-age.sh"

