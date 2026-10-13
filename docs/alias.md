# Alias Script

## Overview

The `alias.sh` script adds convenient bash aliases for commonly used command-line tools, particularly for developers and DevOps engineers working with Kubernetes, Git, Docker, and Ansible.

## Purpose

This script streamlines your shell workflow by creating short aliases for frequently typed commands, reducing typing overhead and improving command-line productivity.

## Use Cases

- Developers working with Kubernetes clusters
- DevOps engineers managing infrastructure
- Git power users performing frequent version control operations
- Docker/Docker Compose users
- Ansible users managing infrastructure as code

## Prerequisites

- Bash shell (≥ 4.0)
- Tools installed (depends on which aliases you use):
  - `kubectl` - for Kubernetes aliases
  - `git` - for Git aliases
  - `kubectx` - for context switching aliases
  - `kubens` - for namespace switching aliases
  - `ansible-playbook` - for Ansible aliases
  - `docker` and `docker-compose` - for Docker aliases
  - `argocd` - for ArgoCD aliases

## Installation

1. Navigate to the repository directory:
```bash
cd /path/to/sh_workouts
```

2. Execute the script:
```bash
source alias.sh
```

Or alternatively, add the aliases manually to your `.bashrc`:
```bash
cat alias.sh >> ~/.bashrc
source ~/.bashrc
```

## Usage

Simply run the script once to add all aliases to your current shell session:

```bash
./alias.sh
```

To make the aliases persistent across shell sessions, add the script to your `.bashrc` or `.bash_profile`.

## Available Aliases

### Kubernetes Aliases

| Alias | Command | Purpose |
|-------|---------|---------|
| `k` | `kubectl` | Execute kubectl commands |
| `kg` | `kubectl get` | Get Kubernetes resources |
| `kgp` | `kubectl get pod` | List all pods |
| `kd` | `kubectl describe` | Describe Kubernetes resources |
| `kpf` | `kubectl port-forward` | Forward ports to pods |
| `ktx` | `kubectx` | Switch Kubernetes context |
| `kns` | `kubens` | Switch Kubernetes namespace |

### Git Aliases

| Alias | Command | Purpose |
|-------|---------|---------|
| `gc` | `git checkout` | Switch branches or restore files |
| `gpo` | `git push origin` | Push commits to origin |
| `gb` | `git branch` | List or manage branches |
| `gs` | `git status` | Show repository status |

### Infrastructure Tools

| Alias | Command | Purpose |
|-------|---------|---------|
| `ap` | `ansible-playbook` | Run Ansible playbooks |
| `ad` | `argocd` | Manage ArgoCD deployments |
| `dc` | `docker-compose` | Manage multi-container Docker apps |
| `dcdangling` | `docker rmi $(docker images -f "dangling=true" -q)` | Remove unused Docker images |

### System Utilities

| Alias | Command | Purpose |
|-------|---------|---------|
| `c` | `clear` | Clear terminal screen |

## Examples

### Using Kubernetes Aliases

```bash
# Get all pods in current namespace
kg pods

# Describe a specific pod
kd pod my-pod-name

# Switch to a different context
ktx my-context

# Switch to a different namespace
kns my-namespace

# Port forward a pod
kpf pod/my-pod 8080:8080
```

### Using Git Aliases

```bash
# Check current status
gs

# Create and checkout a new branch
gc -b feature/new-feature

# Push to origin
gpo

# List branches
gb
```

### Using Docker Aliases

```bash
# Start services defined in docker-compose.yml
dc up

# Remove dangling images
dcdangling
```

## Expected Output

When you run the script, aliases are added to your current shell session. No output is displayed if the script runs successfully. To verify the aliases were added:

```bash
alias
```

This will display all currently defined aliases.

## Notes

- This script appends to `~/.bashrc`, so running it multiple times will create duplicate entries. It's best to run it once and keep it in your dotfiles.
- The aliases assume standard command names. If any tools are not installed, the aliases will still be created but will fail when used.
- For zsh shells, modify the script to append to `~/.zshrc` instead of `~/.bashrc`.
- Consider adding this script to your dotfiles management system (e.g., Oh My Zsh, dotfiles repo) for better maintainability.
- The Docker dangling image removal command is particularly useful for cleaning up space after building many images.

## Related Scripts

- [setup_vim.sh](./setup_vim.md) - Another configuration script for developer tools

## Troubleshooting

**Aliases not working after running the script:**
- Ensure you source the script: `source alias.sh` or run `source ~/.bashrc`
- Check that the required tools are installed and in your PATH

**Duplicate aliases:**
- Edit `~/.bashrc` and remove duplicate lines manually, or re-create the file

## Author

Shell Workouts Repository
