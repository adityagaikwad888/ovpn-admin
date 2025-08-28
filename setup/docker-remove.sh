#!/bin/bash

# Docker Complete Removal Script
set -e

echo "🗑️ Docker Complete Removal Script"
echo "=================================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_progress() { echo -e "${BLUE}[PROGRESS]${NC} $1"; }

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   print_error "Run as regular user with sudo privileges, not root."
   exit 1
fi

print_warning "This script will completely remove Docker from your system!"
print_warning "All Docker containers, images, volumes, and networks will be deleted!"
echo ""
read -p "Are you sure you want to continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_status "Operation cancelled."
    exit 0
fi

print_status "Starting Docker removal process..."

# Step 1: Stop all running containers
print_progress "Stopping all running Docker containers..."
if command -v docker &> /dev/null; then
    RUNNING_CONTAINERS=$(sudo docker ps -q 2>/dev/null || true)
    if [ ! -z "$RUNNING_CONTAINERS" ]; then
        sudo docker stop $RUNNING_CONTAINERS 2>/dev/null || true
        print_status "Stopped running containers"
    else
        print_status "No running containers found"
    fi
else
    print_status "Docker command not found"
fi

# Step 2: Remove all containers
print_progress "Removing all Docker containers..."
if command -v docker &> /dev/null; then
    ALL_CONTAINERS=$(sudo docker ps -aq 2>/dev/null || true)
    if [ ! -z "$ALL_CONTAINERS" ]; then
        sudo docker rm -f $ALL_CONTAINERS 2>/dev/null || true
        print_status "Removed all containers"
    else
        print_status "No containers to remove"
    fi
fi

# Step 3: Remove all images
print_progress "Removing all Docker images..."
if command -v docker &> /dev/null; then
    ALL_IMAGES=$(sudo docker images -q 2>/dev/null || true)
    if [ ! -z "$ALL_IMAGES" ]; then
        sudo docker rmi -f $ALL_IMAGES 2>/dev/null || true
        print_status "Removed all images"
    else
        print_status "No images to remove"
    fi
fi

# Step 4: Remove all volumes
print_progress "Removing all Docker volumes..."
if command -v docker &> /dev/null; then
    ALL_VOLUMES=$(sudo docker volume ls -q 2>/dev/null || true)
    if [ ! -z "$ALL_VOLUMES" ]; then
        sudo docker volume rm $ALL_VOLUMES 2>/dev/null || true
        print_status "Removed all volumes"
    else
        print_status "No volumes to remove"
    fi
fi

# Step 5: Remove all networks
print_progress "Removing all Docker networks..."
if command -v docker &> /dev/null; then
    sudo docker network prune -f 2>/dev/null || true
    print_status "Removed Docker networks"
fi

# Step 6: Stop Docker services
print_progress "Stopping Docker services..."
sudo systemctl stop docker 2>/dev/null || true
sudo systemctl stop docker.socket 2>/dev/null || true
sudo systemctl stop containerd 2>/dev/null || true
print_status "Docker services stopped"

# Step 7: Disable Docker services
print_progress "Disabling Docker services..."
sudo systemctl disable docker 2>/dev/null || true
sudo systemctl disable docker.socket 2>/dev/null || true
sudo systemctl disable containerd 2>/dev/null || true
print_status "Docker services disabled"

# Step 8: Remove Docker packages
print_progress "Removing Docker packages..."
sudo apt-get purge -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin \
    docker.io \
    docker-doc \
    docker-compose \
    docker-compose-v2 \
    podman-docker \
    containerd \
    runc 2>/dev/null || true

print_status "Docker packages removed"

# Step 9: Remove Docker repository
print_progress "Removing Docker repository..."
sudo rm -f /etc/apt/sources.list.d/docker.list
sudo rm -f /etc/apt/keyrings/docker.gpg
print_status "Docker repository removed"

# Step 10: Remove Docker directories and files
print_progress "Removing Docker directories and files..."
sudo rm -rf /var/lib/docker
sudo rm -rf /var/lib/containerd
sudo rm -rf /etc/docker
sudo rm -rf /var/run/docker.sock
sudo rm -rf /var/run/docker
sudo rm -rf /usr/local/bin/docker*
sudo rm -rf /etc/systemd/system/docker.service
sudo rm -rf /etc/systemd/system/docker.socket
sudo rm -rf ~/.docker
print_status "Docker directories removed"

# Step 11: Remove user from docker group
print_progress "Removing user from docker group..."
sudo deluser $USER docker 2>/dev/null || true
print_status "User removed from docker group"

# Step 12: Remove docker group
print_progress "Removing docker group..."
sudo groupdel docker 2>/dev/null || true
print_status "Docker group removed"

# Step 13: Clean up packages
print_progress "Cleaning up unused packages..."
sudo apt-get autoremove -y 2>/dev/null || true
sudo apt-get autoclean 2>/dev/null || true
print_status "Package cleanup completed"

# Step 14: Update package index
print_progress "Updating package index..."
sudo apt-get update > /dev/null
print_status "Package index updated"

# Step 15: Reload systemd
print_progress "Reloading systemd..."
sudo systemctl daemon-reload
print_status "Systemd reloaded"

# Step 16: Verify removal
print_progress "Verifying Docker removal..."
if command -v docker &> /dev/null; then
    print_warning "Docker command still exists (might be from different installation)"
    which docker
else
    print_status "✅ Docker command removed successfully"
fi

if systemctl is-active docker &> /dev/null; then
    print_warning "Docker service still active"
else
    print_status "✅ Docker service removed successfully"
fi

if [ -d "/var/lib/docker" ]; then
    print_warning "Docker data directory still exists"
else
    print_status "✅ Docker data directory removed successfully"
fi

echo ""
print_status "🎉 Docker removal completed!"
echo ""
print_status "Summary of actions taken:"
print_status "  ✅ Stopped and removed all containers"
print_status "  ✅ Removed all images and volumes"
print_status "  ✅ Removed Docker packages"
print_status "  ✅ Removed Docker repository"
print_status "  ✅ Removed Docker directories"
print_status "  ✅ Removed user from docker group"
print_status "  ✅ Cleaned up system"
echo ""
print_warning "IMPORTANT: You may need to log out and back in for group changes to take effect"
print_status "System is now clean of Docker installations"

# Optional: Reboot recommendation
echo ""
read -p "Reboot system now to ensure complete cleanup? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_status "Rebooting system..."
    sudo reboot
fi

print_status "🚀 Docker removal script completed!"
