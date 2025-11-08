# Manual Installation Instructions for NVIDIA Container Toolkit

Since the automated script requires interactive sudo password input, here's how to install manually:

## Option 1: Run the script manually in WSL2

1. **Open WSL2 Ubuntu 24.04:**
   ```powershell
   wsl -d Ubuntu-24.04
   ```

2. **The script should already be copied to your home directory. Run it:**
   ```bash
   bash ~/install-nvidia-container-toolkit.sh
   ```

3. **Enter your sudo password when prompted**

## Option 2: Install step-by-step manually

1. **Open WSL2:**
   ```powershell
   wsl -d Ubuntu-24.04
   ```

2. **Update packages:**
   ```bash
   sudo apt-get update
   ```

3. **Install prerequisites:**
   ```bash
   sudo apt-get install -y curl ca-certificates gnupg lsb-release
   ```

4. **Add NVIDIA repository (use generic deb repository for Ubuntu 24.04):**
   ```bash
   curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
   curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
       sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
       sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
   ```

5. **Install NVIDIA Container Toolkit:**
   ```bash
   sudo apt-get update
   sudo apt-get install -y nvidia-container-toolkit
   ```

6. **Configure Docker:**
   ```bash
   sudo nvidia-ctk runtime configure --runtime=docker
   sudo systemctl restart docker
   ```

7. **Verify installation:**
   ```bash
   docker run --rm --gpus all nvidia/cuda:12.0.0-base-ubuntu24.04 nvidia-smi
   ```

If you see NVIDIA GPU information, the installation is successful!

