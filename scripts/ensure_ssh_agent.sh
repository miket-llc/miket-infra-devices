#!/bin/bash
# Ensure SSH Agent is Running and Key is Loaded
# Starts ssh-agent if not running and adds the SSH key for Ansible connections
# Key location: ~/.ssh/id_ed25519 (or id_rsa as fallback)

set -euo pipefail

# SSH key locations (in order of preference)
SSH_KEYS=(
    "$HOME/.ssh/id_ed25519"
    "$HOME/.ssh/id_rsa"
    "$HOME/.ssh/id_ecdsa"
)

# Find the first available SSH key
SSH_KEY=""
for key in "${SSH_KEYS[@]}"; do
    if [ -f "$key" ]; then
        SSH_KEY="$key"
        break
    fi
done

if [ -z "$SSH_KEY" ]; then
    echo "Error: No SSH private key found in standard locations:" >&2
    printf "  - %s\n" "${SSH_KEYS[@]}" >&2
    exit 1
fi

echo "Using SSH key: $SSH_KEY"

# Check if ssh-agent is running
if [ -z "${SSH_AUTH_SOCK:-}" ]; then
    echo "Starting ssh-agent..."
    eval "$(ssh-agent -s)"
    
    # Add to shell profile for persistence (optional)
    # Uncomment if you want ssh-agent to start automatically
    # echo 'eval "$(ssh-agent -s)"' >> ~/.bashrc
fi

# Check if key is already loaded
if ssh-add -l 2>/dev/null | grep -q "$(ssh-keygen -lf "$SSH_KEY" 2>/dev/null | awk '{print $2}')"; then
    echo "SSH key already loaded in ssh-agent"
else
    echo "Adding SSH key to ssh-agent..."
    # Use SSH_ASKPASS to avoid passphrase prompt if key has one
    # If key has passphrase, ensure it's unlocked via 1Password SSH agent or keychain
    DISPLAY=:0 SSH_ASKPASS_REQUIRE=never ssh-add "$SSH_KEY" 2>/dev/null || {
        echo "Warning: Failed to add key automatically (may require passphrase)" >&2
        echo "If key has passphrase, ensure 1Password SSH agent is configured or unlock manually:" >&2
        echo "  ssh-add $SSH_KEY" >&2
        exit 1
    }
fi

echo "✅ SSH agent is running and key is loaded"
echo "SSH_AUTH_SOCK=$SSH_AUTH_SOCK"
ssh-add -l

