#!/bin/bash
# NVIDIA Container Toolkit installation script for WSL2 Ubuntu 24.04
# Run this inside WSL2 Ubuntu 24.04: wsl -d Ubuntu-24.04 < install-nvidia-container-toolkit.sh
# Or copy into WSL2 and run: bash install-nvidia-container-toolkit.sh

set -e

echo "==============================================================="
echo "   NVIDIA Container Toolkit Setup for WSL2"
echo "==============================================================="
echo ""

# Check if running in WSL
if [ -z "$WSL_DISTRO_NAME" ]; then
    echo "WARNING: This script is designed for WSL2. Continuing anyway..."
fi

echo "[1/5] Updating package lists..."
sudo apt-get update

echo ""
echo "[2/5] Installing prerequisites..."
sudo apt-get install -y curl ca-certificates gnupg lsb-release

echo ""
echo "[3/5] Adding NVIDIA Container Toolkit repository..."
# Use the generic deb repository (works for Ubuntu 24.04)
echo "Using generic deb repository for Ubuntu 24.04..."

# Add GPG key
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

# Detect architecture
ARCH=$(dpkg --print-architecture)

# Configure repository with proper error checking
REPO_URL="https://nvidia.github.io/libnvidia-container/stable/deb/${ARCH}"
REPO_LINE="deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] ${REPO_URL} /"

# Verify the repository URL is accessible before writing
if curl -fsSL --head "${REPO_URL}/Packages" > /dev/null 2>&1; then
    echo "${REPO_LINE}" | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list > /dev/null
    echo "Repository configured successfully for architecture: ${ARCH}"
else
    echo "WARNING: Repository URL not accessible: ${REPO_URL}"
    echo "Falling back to generic repository..."
    # Fallback to generic repository
    REPO_URL="https://nvidia.github.io/libnvidia-container/stable/deb"
    REPO_LINE="deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] ${REPO_URL}/${ARCH} /"
    echo "${REPO_LINE}" | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list > /dev/null
fi

# Verify the file doesn't contain HTML (404 error page)
if grep -q "<!doctype\|<html\|404" /etc/apt/sources.list.d/nvidia-container-toolkit.list 2>/dev/null; then
    echo "ERROR: Repository file contains HTML (404 error page)"
    echo "Removing invalid file..."
    sudo rm -f /etc/apt/sources.list.d/nvidia-container-toolkit.list
    exit 1
fi

echo ""
echo "[4/5] Installing NVIDIA Container Toolkit..."
sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit

echo ""
echo "[5/5] Configuring Docker to use NVIDIA runtime..."
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker

echo ""
echo "==============================================================="
echo "   ✅ NVIDIA Container Toolkit Setup Complete!"
echo "==============================================================="
echo ""
echo "Verification:"
echo "  Run: docker run --rm --gpus all nvidia/cuda:12.0.0-base-ubuntu24.04 nvidia-smi"
echo ""

