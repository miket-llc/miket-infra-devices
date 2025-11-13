#!/bin/bash
# Shared NVIDIA Container Toolkit Installation Script
# Works for any Linux/WSL2 system
# Usage: Run from WSL2 Ubuntu or any Debian-based Linux distribution

set -e

echo "[$(date +%H:%M:%S)] Starting NVIDIA Container Toolkit installation..."

# Check if already installed
if dpkg -l | grep -q nvidia-container-toolkit; then
  echo "[$(date +%H:%M:%S)] NVIDIA Container Toolkit already installed"
  exit 0
fi

echo "[$(date +%H:%M:%S)] Adding NVIDIA Container Toolkit repository (modern method)..."

# Install prerequisites
sudo apt-get update -qq
sudo apt-get install -y -qq curl ca-certificates gnupg lsb-release

# Add GPG key
echo "[$(date +%H:%M:%S)] Adding NVIDIA GPG key..."
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

# Detect architecture
ARCH=$(dpkg --print-architecture)

# Configure repository with proper error checking
echo "[$(date +%H:%M:%S)] Configuring NVIDIA Container Toolkit repository..."
REPO_URL="https://nvidia.github.io/libnvidia-container/stable/deb/${ARCH}"
REPO_LINE="deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] ${REPO_URL} /"

# Verify the repository URL is accessible before writing
if curl -fsSL --head "${REPO_URL}/Packages" > /dev/null 2>&1; then
    echo "${REPO_LINE}" | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list > /dev/null
    echo "[$(date +%H:%M:%S)] Repository configured successfully"
else
    echo "[$(date +%H:%M:%S)] ERROR: Repository URL not accessible: ${REPO_URL}"
    echo "[$(date +%H:%M:%S)] Falling back to generic repository..."
    # Fallback to generic repository
    REPO_URL="https://nvidia.github.io/libnvidia-container/stable/deb"
    REPO_LINE="deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] ${REPO_URL}/${ARCH} /"
    echo "${REPO_LINE}" | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list > /dev/null
fi

# Verify the file doesn't contain HTML (404 error page)
if grep -q "<!doctype\|<html\|404" /etc/apt/sources.list.d/nvidia-container-toolkit.list 2>/dev/null; then
    echo "[$(date +%H:%M:%S)] ERROR: Repository file contains HTML (404 error page)"
    echo "[$(date +%H:%M:%S)] Removing invalid file..."
    sudo rm -f /etc/apt/sources.list.d/nvidia-container-toolkit.list
    exit 1
fi

echo "[$(date +%H:%M:%S)] Updating package lists..."
sudo apt-get update -y

echo "[$(date +%H:%M:%S)] Installing nvidia-container-toolkit..."
sudo apt-get install -y nvidia-container-toolkit

echo "[$(date +%H:%M:%S)] Configuring Docker to use NVIDIA runtime..."
sudo nvidia-ctk runtime configure --runtime=docker

echo "[$(date +%H:%M:%S)] Restarting Docker service..."
sudo systemctl restart docker

echo "[$(date +%H:%M:%S)] NVIDIA Container Toolkit installation complete!"

