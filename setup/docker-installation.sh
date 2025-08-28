#!/bin/bash

# Docker 28.3.3 Installation Script (Fixed)
set -e

echo "🐳 Docker 28.3.3 Installation Script"
echo "====================================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_status() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   print_error "Run as regular user with sudo privileges, not root."
   exit 1
fi

print_status "Starting Docker installation..."

# Install prerequisites
print_status "Installing prerequisites..."
sudo apt-get update > /dev/null
sudo apt-get install -y ca-certificates curl gnupg lsb-release apt-transport-https software-properties-common

# Add Docker repository
print_status "Adding Docker repository..."
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update > /dev/null

# Check available versions and get the correct one
print_status "Checking for Docker 28.3.3..."
AVAILABLE_28_3_3=$(apt-cache madison docker-ce | grep "28.3.3" | head -1)

if [ ! -z "$AVAILABLE_28_3_3" ]; then
    # Extract the exact version string
    VERSION_STRING=$(echo "$AVAILABLE_28_3_3" | awk '{print $3}')
    print_status "✅ Found Docker 28.3.3: $VERSION_STRING"
    print_status "Installing Docker 28.3.3..."
    
    sudo apt install -y \
        docker-ce=$VERSION_STRING \
        docker-ce-cli=$VERSION_STRING \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin \
        docker-compose
    
    INSTALLED_VERSION="28.3.3"
else
    print_warning "Docker 28.3.3 not found. Installing latest version..."
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-compose
    INSTALLED_VERSION=$(docker --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' || echo "unknown")
fi

# Configure Docker
print_status "Configuring Docker..."
sudo usermod -aG docker $USER
sudo systemctl enable docker
sudo systemctl start docker

# Configure daemon
sudo mkdir -p /etc/docker
cat << EOF | sudo tee /etc/docker/daemon.json > /dev/null
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2"
}
EOF

sudo systemctl restart docker

# Verify installation
print_status "Verifying installation..."
DOCKER_VERSION=$(docker --version)
print_status "Installed: $DOCKER_VERSION"

if sudo docker run --rm hello-world > /dev/null 2>&1; then
    print_status "✅ Docker test successful!"
else
    print_warning "Docker test had issues"
fi

echo ""
if [[ "$INSTALLED_VERSION" == "28.3.3" ]]; then
    print_status "🎉 SUCCESS! Docker 28.3.3 installed!"
else
    print_warning "Installed Docker $INSTALLED_VERSION (28.3.3 not available)"
fi

echo ""
print_warning "IMPORTANT: Log out and back in for group changes to take effect"
print_status "Then test: docker run hello-world"
print_status "OpenVPN test: cd /home/ubuntu/ovpn-admin && ./start.sh"

# Optional: Apply group changes
read -p "Apply group changes now? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    exec newgrp docker
fi

print_status "🚀 Installation completed!"
