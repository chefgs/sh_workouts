# Docker Installation Script

## Overview

The `install_docker.sh` script automates the installation of Docker Engine on Ubuntu systems using Docker's official repository. This ensures you get the latest stable version with proper security verification.

## Purpose

This script simplifies Docker installation on Ubuntu by:
- Removing any conflicting Docker packages
- Adding Docker's official GPG key for package verification
- Setting up the official Docker repository
- Installing Docker Engine, Docker CLI, and containerd
- Verifying the installation

## Use Cases

- Setting up Docker on a new Ubuntu machine
- Provisioning Docker for development environments
- Infrastructure automation and server setup
- DevOps engineers configuring containerization

## Prerequisites

- Ubuntu Linux distribution (tested and compatible)
- Root or sudo access required
- Internet connectivity
- Approximately 1-2 GB of disk space for Docker installation

## Installation

1. Navigate to the repository directory:
```bash
cd /path/to/sh_workouts
```

2. Make the script executable:
```bash
chmod +x install_docker.sh
```

## Usage

Run the script with sudo privileges:

```bash
sudo ./install_docker.sh
```

The script will:
1. Update the package index
2. Remove any conflicting Docker installations
3. Install required dependencies
4. Add Docker's GPG key
5. Verify the GPG key fingerprint
6. Add Docker's official repository
7. Update package index
8. Install Docker Engine and related packages
9. Verify the installation by running hello-world container

## Script Steps Breakdown

### 1. Update Repository
```bash
sudo apt-get update -y
```
Updates the package index to get the latest package information.

### 2. Remove Conflicting Packages
```bash
sudo apt-get remove -y docker docker-engine docker.io containerd runc
```
Removes any previously installed Docker packages to avoid conflicts.

### 3. Install Dependencies
```bash
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg-agent software-properties-common
```
Installs packages needed to use HTTPS repositories and add GPG keys.

### 4. Add Docker's GPG Key
```bash
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
```
Downloads and adds Docker's official GPG public key.

### 5. Verify GPG Key
```bash
sudo apt-key fingerprint 0EBFCD88
```
Verifies that the correct GPG key was added. Expected fingerprint:
```
9DC8 5822 9FC7 DD38 854A E2D8 8D81 803C 0EBF CD88
```

### 6. Add Docker Repository
```bash
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
```
Adds Docker's official repository to your system. The script automatically detects your Ubuntu version using `lsb_release -cs`.

### 7. Install Docker
```bash
sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io
```
Installs Docker Engine (docker-ce), Docker CLI, and containerd runtime.

### 8. Verify Installation
```bash
sudo docker run hello-world
```
Tests Docker installation by running the official hello-world image.

## Expected Output

```
Hello from Docker!
This message shows that your installation appears to be working correctly.

To generate this message, Docker took the following steps:
 1. The Docker client contacted the Docker daemon
 2. The Docker daemon pulled the "hello-world" image from the Docker Hub
 3. The Docker daemon created a new container from that image
 4. The Docker daemon streamed that output to the Docker client
...
```

## Post-Installation Configuration

After successful installation, you may want to:

### 1. Manage Docker as Non-Root User

```bash
# Create docker group
sudo groupadd docker

# Add your user to the docker group
sudo usermod -aG docker $USER

# Apply group changes
newgrp docker

# Verify (should work without sudo)
docker run hello-world
```

### 2. Configure Docker to Start on Boot

```bash
sudo systemctl enable docker
```

### 3. Check Docker Version

```bash
docker --version
docker run hello-world
```

## Notes

- **Security**: This script uses Docker's official GPG key verification. Always verify the fingerprint matches before proceeding.
- **Architecture**: The script is configured for `amd64` architecture. For ARM or other architectures, modify the repository URL.
- **Ubuntu Versions**: The script automatically detects your Ubuntu version. Supported versions include Focal (20.04), Jammy (22.04), and newer.
- **Root Access**: Requires sudo access for all apt and Docker commands.
- **Network**: Requires internet connectivity to download packages and verify GPG keys.

## Troubleshooting

**GPG key verification fails:**
- Ensure your internet connection is stable
- Check that you can access `download.docker.com`
- Try downloading the key again

**Repository addition fails:**
- Verify your Ubuntu version is supported
- Check that `software-properties-common` is installed
- Try updating: `sudo apt-get update`

**Docker installation fails:**
- Ensure previous Docker versions are completely removed
- Try updating and upgrading: `sudo apt-get update && sudo apt-get upgrade -y`
- Check available disk space: `df -h`

**hello-world test fails:**
- Check Docker daemon is running: `sudo systemctl status docker`
- Check internet connectivity to download the image
- Verify Docker installation: `docker --version`

**Permission denied errors after installation:**
- Add your user to docker group: `sudo usermod -aG docker $USER`
- Log out and back in for changes to take effect

## Alternative Installation Methods

For other Linux distributions or installation methods, see:
- [Docker Official Documentation](https://docs.docker.com/install/)
- [Install Docker Engine](https://docs.docker.com/engine/install/)

## Related Scripts

- [alias.sh](./alias.md) - Useful Docker and docker-compose aliases

## Author

Shell Workouts Repository
