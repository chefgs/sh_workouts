# Shell Script Workouts and Utility Scripts

<!-- Badges -->
<div align="center">

[![GitHub License](https://img.shields.io/github/license/chefgs/sh_workouts?style=flat-square)](./LICENSE)
[![Bash Version](https://img.shields.io/badge/bash-5.0%2B-green?style=flat-square&logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Shell Script](https://img.shields.io/badge/shell_script-%23121011.svg?style=flat-square&logo=gnu-bash&logoColor=white)](https://www.shellcheck.net/)
[![GitHub Stars](https://img.shields.io/github/stars/chefgs/sh_workouts?style=flat-square&logo=github)](https://github.com/chefgs/sh_workouts/stargazers)
[![GitHub Forks](https://img.shields.io/github/forks/chefgs/sh_workouts?style=flat-square&logo=github)](https://github.com/chefgs/sh_workouts/network)
[![GitHub Issues](https://img.shields.io/github/issues/chefgs/sh_workouts?style=flat-square&logo=github)](https://github.com/chefgs/sh_workouts/issues)
[![GitHub Contributors](https://img.shields.io/github/contributors/chefgs/sh_workouts?style=flat-square&logo=github)](https://github.com/chefgs/sh_workouts/graphs/contributors)

</div>

---

## Overview

A comprehensive collection of shell script utilities and educational examples for developers and system administrators. This repository contains practical, well-documented bash scripts for common system administration tasks, text processing, and DevOps workflows.

**Key Features:**
- ✅ Well-documented scripts with detailed usage instructions
- ✅ Educational examples demonstrating shell scripting techniques
- ✅ Practical utilities for developers and DevOps engineers
- ✅ Easy-to-follow installation and usage guides
- ✅ Examples of Unix pipe operations and text processing

## Table of Contents

- [Quick Start](#quick-start)
- [Scripts Documentation](#scripts-documentation)
- [Installation](#installation)
- [Usage Examples](#usage-examples)
- [Contributing](#contributing)
- [Code of Conduct](#code-of-conduct)
- [License](#license)

## Quick Start

```bash
# Clone the repository
git clone https://github.com/chefgs/sh_workouts.git
cd sh_workouts

# Make a script executable
chmod +x script_name.sh

# Run the script
./script_name.sh
```

## Scripts Documentation

### DevOps & Infrastructure

#### 1. **Docker Installation** - `install_docker.sh`
Automates Docker Engine installation on Ubuntu systems with official GPG verification.

- **Purpose:** Simplifies Docker setup with security best practices
- **Use Case:** Quick Docker installation on Ubuntu servers
- **Features:** Automated dependency installation, GPG key verification, installation validation
- 📖 [Read Full Documentation](./docs/install_docker.md)

**Quick Usage:**
```bash
chmod +x install_docker.sh
sudo ./install_docker.sh
```

---

#### 2. **Useful Aliases** - `alias.sh`
Creates convenient bash aliases for Kubernetes, Git, Docker, Ansible, and other DevOps tools.

- **Purpose:** Reduce typing and boost productivity with command shortcuts
- **Tools Covered:** kubectl, git, docker-compose, ansible-playbook, kubectx, argocd
- **Features:** Comprehensive alias collection, easy setup
- 📖 [Read Full Documentation](./docs/alias.md)

**Quick Usage:**
```bash
source alias.sh
# or
./alias.sh && source ~/.bashrc
```

**Example Aliases:**
| Alias | Command |
|-------|---------|
| `k` | `kubectl` |
| `kg` | `kubectl get` |
| `gc` | `git checkout` |
| `dc` | `docker-compose` |

---

### Text Processing & Documentation

#### 3. **Word Frequency Analysis** - `singleline.sh`
Demonstrates powerful Unix pipeline techniques for text analysis and word frequency counting.

- **Purpose:** Educational tool showing text processing with pipes
- **Techniques:** Character translation, sorting, counting, filtering
- **Features:** Multiple examples, well-commented code
- 📖 [Read Full Documentation](./docs/singleline.md)

**Quick Usage:**
```bash
./singleline.sh
```

**Example:**
```bash
# Count word frequencies in a file
cat file.txt | tr -c '[:alnum:]' '\n' | tr '[:upper:]' '[:lower:]' | sort | uniq -c | sort -nr
```

---

#### 4. **TOC from Markdown** - `toc-from-markdown.sh`
Automatically extracts markdown headings and generates a Table of Contents.

- **Purpose:** Create TOC directly from existing markdown files
- **Features:** Auto-detects all heading levels, generates clickable links
- **Output:** Markdown-formatted table of contents
- 📖 [Read Full Documentation](./docs/toc-from-markdown.md)

**Quick Usage:**
```bash
./toc-from-markdown.sh README.md
```

**Example Output:**
```
- [Introduction](#introduction)
- [Installation](#installation)
- [Usage](#usage)
```

---

#### 5. **TOC from Headings** - `toc-from-headings.sh`
Converts a file of headings into markdown-formatted TOC with anchor links.

- **Purpose:** Generate TOC from a pre-prepared list of headings
- **Features:** Converts heading text to proper anchor format
- **Use Case:** Creating TOC for documentation and blog posts
- 📖 [Read Full Documentation](./docs/toc-from-headings.md)

**Quick Usage:**
```bash
./toc-from-headings.sh headings.txt
```

---

#### 6. **TOC Format Converter** - `toc.sh`
Processes TOC entries and converts them to markdown anchor format.

- **Purpose:** Format conversion for TOC entries
- **Features:** Handles uppercase to lowercase, spaces to hyphens
- **Input Format:** `DisplayText(AnchorText)`
- 📖 [Read Full Documentation](./docs/toc.md)

**Quick Usage:**
```bash
./toc.sh toc_input.txt
```

---

### System Administration & Configuration

#### 7. **System Information Display** - `display-date-time-username-curentworkingdirectory.sh`
Quick diagnostic script showing current date, time, users, and working directory.

- **Purpose:** Display essential system information
- **Information Shown:** Date/time, logged-in users, current directory
- **Use Cases:** System diagnostics, shell scripting, logging
- 📖 [Read Full Documentation](./docs/display-date-time.md)

**Quick Usage:**
```bash
./display-date-time-username-curentworkingdirectory.sh
```

**Example Output:**
```
Date and Time is
Wed Oct 13 20:46:28 UTC 2026
user details is
 20:46:28 up 45 min,  2 users,  load average: 0.10, 0.12, 0.09
USER     TTY      FROM             LOGIN@   IDLE   JCPU   PCPU WHAT
runner   pts/0    192.168.1.100    20:15    5.00s  0.30s  0.05s bash
current directory is
/home/runner/work/sh_workouts/sh_workouts
```

---

#### 8. **Check User Login Status** - `user-loggedin-or-not.sh`
Determines whether a specific user is currently logged into the system.

- **Purpose:** Check active user sessions
- **Features:** Interactive user input, clear yes/no status output
- **Use Cases:** Access control, monitoring, automated tasks
- 📖 [Read Full Documentation](./docs/user-loggedin.md)

**Quick Usage:**
```bash
./user-loggedin-or-not.sh
# Enter username when prompted
```

**Example:**
```
$ ./user-loggedin-or-not.sh
Enter name of the user: admin
User is logged in to the system
```

---

#### 9. **Vim Configuration** - `setup_vim.sh`
Automatically enables line numbers in vim configuration.

- **Purpose:** Quick vim setup for enhanced readability
- **Features:** Adds `set number` to vim configuration
- **Compatibility:** Ubuntu and macOS tested
- 📖 [Read Full Documentation](./docs/setup_vim.md)

**Quick Usage:**
```bash
source setup_vim.sh
# or
./setup_vim.sh
```

After running, vim will display line numbers by default.

---

## Installation

### Clone the Repository

```bash
git clone https://github.com/chefgs/sh_workouts.git
cd sh_workouts
```

### Make Scripts Executable

```bash
# Make a single script executable
chmod +x script_name.sh

# Make all scripts executable
chmod +x *.sh
```

### System Requirements

- Bash 4.0 or higher
- Standard Unix/Linux utilities (tr, sed, sort, grep, etc.)
- For specific scripts:
  - `install_docker.sh`: Ubuntu system with sudo access
  - `install_docker.sh`: Internet connectivity
  - Kubernetes aliases: kubectl, kubectx, kubens installed
  - Docker aliases: Docker and Docker Compose installed

## Usage Examples

### Example 1: Setup Your Development Environment

```bash
#!/bin/bash
# Setup script using multiple utilities

cd ~/sh_workouts

# Add useful aliases
source alias.sh

# Setup vim
source setup_vim.sh

# Display system info
./display-date-time-username-curentworkingdirectory.sh

echo "Setup complete!"
```

### Example 2: Generate Documentation TOC

```bash
#!/bin/bash
# Generate table of contents for README

cd ~/sh_workouts

# Extract headings and generate TOC
./toc-from-markdown.sh GUIDE.md > toc.txt

# Display the generated TOC
cat toc.txt
```

### Example 3: Analyze Text Data

```bash
#!/bin/bash
# Use single-line commands for data analysis

# Count word frequencies in a file
cat data.txt | tr -c '[:alnum:]' '\n' | tr '[:upper:]' '[:lower:]' | \
sed '/^$/d' | sort | uniq -c | sort -nr | head -20
```

### Example 4: Install Docker

```bash
#!/bin/bash
# Complete Docker installation

chmod +x install_docker.sh
sudo ./install_docker.sh

# Verify installation
docker run hello-world
```

## Contributing

We welcome contributions! Please review our [Contribution Guidelines](./CONTRIBUTING.md) before submitting pull requests.

**How to Contribute:**
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Commit your changes (`git commit -m 'Add amazing feature'`)
5. Push to the branch (`git push origin feature/amazing-feature`)
6. Open a Pull Request

## Code of Conduct

Please read our [Code of Conduct](./CODE_OF_CONDUCT.md) to understand our community standards and expectations.

## Important Notice

📋 Read [Contribution Guidelines](./CONTRIBUTING.md) before contributing to this repository!

📋 Read GitHub [Code of Conduct guidelines](./CODE_OF_CONDUCT.md) before contributing to this repository!

## License

This project is licensed under the MIT License - see the [LICENSE](./LICENSE) file for details.

## Support

If you encounter issues or have questions:

1. Check the individual script documentation in the `docs/` directory
2. Review the [Contribution Guidelines](./CONTRIBUTING.md)
3. Open an issue on [GitHub Issues](https://github.com/chefgs/sh_workouts/issues)

## Additional Resources

- 📚 [Bash Manual](https://www.gnu.org/software/bash/manual/)
- 📚 [Linux Command Line](https://www.tldp.org/LDP/intro-linux/html/)
- 🔗 [Shell Parameter Expansion](https://www.gnu.org/software/bash/manual/html_node/Shell-Parameter-Expansion.html)
- 🔗 [Regular Expressions](https://www.regular-expressions.info/)

## Acknowledgments

Thanks to all contributors and users who help improve this project!

---

<div align="center">

**[⬆ back to top](#shell-script-workouts-and-utility-scripts)**

Made with ❤️ by the Shell Workouts Community

</div>
