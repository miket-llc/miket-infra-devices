#!/usr/bin/env bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.
#
# Cleanup Ubuntu/KDE Configuration After Fedora Installation
# Removes old desktop environment configs while preserving data
#
# Usage: ~/miket-infra-devices/scripts/cleanup-ubuntu-config.sh

set -euo pipefail

echo "=========================================="
echo "Ubuntu/KDE Config Cleanup"
echo "=========================================="
echo ""
echo "This will remove old desktop environment configs from /home/mdt"
echo "while preserving SSH keys, code, docs, and application data."
echo ""
read -p "Continue? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
  echo "Aborted"
  exit 0
fi

cd "${HOME}"

echo ""
echo "[1/4] Removing desktop caches..."
if [ -d ".cache" ]; then
  rm -rf .cache/*
  echo "  ✅ Cache cleared"
else
  echo "  ℹ️  No cache directory"
fi

echo ""
echo "[2/4] Removing old desktop configs..."

# KDE/Plasma configs
for dir in .config/kde* .config/plasma* .config/kwin* .config/sddm*; do
  if [ -d "$dir" ]; then
    echo "  Removing: $dir"
    rm -rf "$dir"
  fi
done

# GNOME configs (from old Ubuntu if they exist)
for dir in .config/gnome* .config/dconf; do
  if [ -d "$dir" ]; then
    echo "  Removing: $dir"
    rm -rf "$dir"
  fi
done

# Desktop-specific data
for dir in .local/share/gnome* .local/share/konsole* .local/share/kwin* .local/share/plasma*; do
  if [ -d "$dir" ]; then
    echo "  Removing: $dir"
    rm -rf "$dir"
  fi
done

# Runtime state
if [ -d ".local/state" ]; then
  rm -rf .local/state/*
  echo "  ✅ Runtime state cleared"
fi

echo "  ✅ Desktop configs removed"

echo ""
echo "[3/4] Preserving application data..."

# These should NOT be removed
PRESERVED=(
  ".ssh"
  ".config/obsidian"
  ".local/share/obsidian"
  ".gitconfig"
  ".git-credentials"
  "code"
  "projects"
  "Documents"
  "miket-infra-devices"
)

echo "  ✅ Preserved directories:"
for item in "${PRESERVED[@]}"; do
  if [ -e "${HOME}/${item}" ]; then
    echo "    - ${item}"
  fi
done

echo ""
echo "[4/4] Fixing SSH permissions..."
if [ -d ".ssh" ]; then
  chmod 700 .ssh
  chmod 600 .ssh/id_* 2>/dev/null || true
  chmod 644 .ssh/*.pub 2>/dev/null || true
  echo "  ✅ SSH permissions fixed"
else
  echo "  ℹ️  No .ssh directory"
fi

# Summary
echo ""
echo "=========================================="
echo "Cleanup Complete!"
echo "=========================================="
echo ""
echo "Removed:"
echo "  - Desktop caches (.cache/)"
echo "  - KDE/Plasma configs"
echo "  - GNOME configs"
echo "  - Desktop runtime state"
echo ""
echo "Preserved:"
echo "  - SSH keys (.ssh/)"
echo "  - Application data (Obsidian, etc.)"
echo "  - Code and documents"
echo "  - Git configuration"
echo ""
echo "You can now log out and log back in to start fresh with GNOME/Fedora."
echo ""


