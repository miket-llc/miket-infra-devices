#!/bin/bash
# Install NVIDIA Container Toolkit in WSL2 Ubuntu
set -e

# Check if already installed
if dpkg -l | grep -q nvidia-container-toolkit; then
  echo "[$(date +%H:%M:%S)] NVIDIA Container Toolkit already installed"
  exit 0
fi

echo "[$(date +%H:%M:%S)] Adding NVIDIA Container Toolkit repository (modern method)..."

# Use the official installation script from NVIDIA
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

# Use stable repository for Ubuntu
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

echo "[$(date +%H:%M:%S)] Updating package lists..."
sudo apt-get update -y

echo "[$(date +%H:%M:%S)] Installing nvidia-container-toolkit..."
sudo apt-get install -y nvidia-container-toolkit

echo "[$(date +%H:%M:%S)] Configuring Docker to use NVIDIA runtime..."
sudo nvidia-ctk runtime configure --runtime=docker

echo "[$(date +%H:%M:%S)] NVIDIA Container Toolkit installed successfully"

