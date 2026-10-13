# Setup Vim Configuration Script

## Overview

The `setup_vim.sh` script automates the configuration of vim by enabling line numbers in the vim editor. It's a simple utility that modifies your vim configuration file to enhance readability during editing.

## Purpose

This script:
- Adds line number configuration to vim
- Modifies or creates `~/.vimrc` configuration file
- Works on both Ubuntu and macOS systems
- Provides persistent vim configuration changes

## Use Cases

- Setting up vim for new users
- Automating developer environment configuration
- Including in setup scripts or dotfiles
- Improving vim readability with line numbers

## Prerequisites

- Vim editor installed on the system
- Write access to home directory (for `~/.vimrc`)
- Bash shell
- Tested on Ubuntu and macOS (POSIX-compatible systems)

## Installation

1. Navigate to the repository directory:
```bash
cd /path/to/sh_workouts
```

2. Make the script executable:
```bash
chmod +x setup_vim.sh
```

## Usage

The script should be sourced in your current shell or executed directly:

### Method 1: Source the Script (Recommended)

```bash
source setup_vim.sh
```

Sourcing ensures the environment is properly updated within your current shell session.

### Method 2: Execute Directly

```bash
./setup_vim.sh
```

Executes the script in a subshell. Changes are still applied to `~/.vimrc`.

## Script Breakdown

The script performs the following operations:

```bash
#!/bin/bash
#
# Set up line number in vim. Tested in Ubuntu and Mac. 
#
# Method of use:
# source setup_vim.sh
#

echo "
set number
" >> ~/.vimrc

echo ".vimrc updated"
```

### Step 1: Comments and Documentation

```bash
#!/bin/bash
# Set up line number in vim. Tested in Ubuntu and Mac. 
# Method of use:
# source setup_vim.sh
```

- Specifies bash as the interpreter
- Documents the purpose and usage method

### Step 2: Add Line Number Configuration

```bash
echo "
set number
" >> ~/.vimrc
```

- `echo` - Outputs the configuration command
- `"......"` - Multi-line string with the vim command
- `>>` - Appends to file (creates if doesn't exist)
- `~/.vimrc` - Vim configuration file in home directory

The `set number` command in vim:
- Displays line numbers in the left margin
- Useful for navigation and debugging
- Improves readability of code

### Step 3: Confirmation Message

```bash
echo ".vimrc updated"
```

Displays a confirmation message indicating the configuration was applied.

## Expected Output

When you run the script:

```
.vimrc updated
```

This confirms that `~/.vimrc` has been modified.

## Vim Line Numbers

After running this script, when you open vim, you'll see line numbers on the left:

```vim
  1 #!/bin/bash
  2 # This is line 2
  3 # This is line 3
  4 echo "Hello World"
  5 
```

## Practical Examples

### Example 1: Basic Usage

```bash
# Run the script to enable line numbers
./setup_vim.sh

# Verify by opening vim
vim ~/.vimrc

# You'll see line numbers in vim now
```

### Example 2: Using in a Setup Script

```bash
#!/bin/bash
# Developer environment setup script

echo "Setting up vim configuration..."
./setup_vim.sh

echo "Setting up aliases..."
./alias.sh

echo "Setup complete!"
```

### Example 3: Automated Configuration

```bash
#!/bin/bash
# Automated server provisioning

# Set up vim
source setup_vim.sh

# Set up other tools
source setup_other_tools.sh

# Verify configuration
vim --version
```

### Example 4: Checking Configuration

```bash
# Verify line numbers are set in vim
grep "set number" ~/.vimrc

# Open vim to verify
vim /tmp/test.txt
```

## Vim Configuration Details

### What is `.vimrc`?

The `.vimrc` file is vim's configuration file located in your home directory:
- Path: `~/.vimrc`
- Created if doesn't exist
- Contains vim settings and customizations
- Loaded when vim starts

### The `set number` Command

In vim, `set number` enables line numbering:

```vim
set number        " Show line numbers
set nonumber      " Disable line numbers (inverse)
set relativenumber " Show relative line numbers
set numberwidth=4 " Width of line number column
```

## Additional Vim Customization

After running this script, you can enhance your vim configuration further:

### Example: Enhanced Vim Configuration

```bash
cat >> ~/.vimrc << EOF

" Enhanced Vim Configuration
set number           " Show line numbers
set ruler           " Show position in file
set tabstop=4       " Tab width
set shiftwidth=4    " Indent width
set expandtab       " Use spaces instead of tabs
set syntax=on       " Enable syntax highlighting
set background=dark " Dark background
EOF
```

### Useful Vim Settings

Add to `~/.vimrc`:

```vim
" Line numbers
set number

" Highlighting
set background=dark
syntax on

" Indentation
set autoindent
set smartindent
set expandtab
set tabstop=4
set shiftwidth=4

" Search
set ignorecase
set smartcase
set hlsearch
set incsearch

" Display
set ruler
set statusline=%F%m%r%h%w\ [%l,%c]
set cmdheight=2

" Navigation
set mouse=a
set scrolloff=5
```

## Verifying the Configuration

### Check if Configuration Applied

```bash
# View the vim configuration file
cat ~/.vimrc

# Should contain "set number" somewhere in the file
grep "set number" ~/.vimrc
```

### Test in Vim

```bash
# Open a file in vim
vim test.txt

# Inside vim:
# Line numbers should appear on the left
# Press :set number to toggle
# Type :wq to save and exit
```

### Common Vim Commands for Line Numbers

Inside vim:

```vim
:set number        " Enable line numbers
:set nonumber      " Disable line numbers
:set relativenumber " Toggle relative numbers
:set numberwidth=6 " Set column width to 6
:set number!       " Toggle line numbers
```

## Notes

- **File Creation**: If `~/.vimrc` doesn't exist, it will be created
- **Appending**: The script appends to the file, so existing settings are preserved
- **Multiple Runs**: Running the script multiple times will add duplicate entries. Consider cleaning up or checking for duplicates
- **Portability**: Works on Ubuntu, macOS, and other Unix-like systems
- **No Root Required**: Only requires write access to home directory

## Troubleshooting

**Script doesn't run:**
- Ensure execute permissions: `chmod +x setup_vim.sh`
- Verify bash is available: `which bash`
- Check script format: `head -1 setup_vim.sh` (should show `#!/bin/bash`)

**Changes not appearing in vim:**
- Verify vim read the config: `vim --version | grep -i vimrc`
- Check `.vimrc` was modified: `cat ~/.vimrc | grep "set number"`
- Restart vim or run `:source ~/.vimrc` inside vim

**Line numbers still not showing:**
- Ensure you're using vim (not vi): `which vim`
- Check vim configuration for conflicting settings
- Try manually in vim: `:set number`

**Duplicate entries in `.vimrc`:**
- View the file: `cat ~/.vimrc`
- Edit to remove duplicates: `vim ~/.vimrc`
- Or recreate the file with unique entries

**Permission denied:**
- Check home directory permissions: `ls -ld ~`
- Ensure write access to home: `touch ~/.test_write`
- Remove test file: `rm ~/.test_write`

## Customization

### Auto-apply Additional Settings

```bash
#!/bin/bash
# Enhanced setup_vim.sh with additional settings

cat >> ~/.vimrc << 'EOF'
set number
set ruler
set tabstop=4
set expandtab
syntax on
EOF

echo ".vimrc updated with enhanced settings"
```

### Backup Before Modifying

```bash
#!/bin/bash
# Backup existing vimrc before modification

if [ -f ~/.vimrc ]; then
    cp ~/.vimrc ~/.vimrc.backup
    echo "Backed up existing .vimrc to .vimrc.backup"
fi

# Now run the setup
source setup_vim.sh
```

## Related Scripts

- [alias.sh](./alias.md) - Adds useful command aliases
- [install_docker.sh](./install_docker.md) - Development environment setup

## Integration with Dotfiles

Include this script in your dotfiles repository:

```bash
# ~/.dotfiles/install.sh
echo "Setting up vim..."
source ./setup_vim.sh

echo "Setting up bash aliases..."
source ./alias.sh
```

## Learning More About Vim

Resources for vim configuration:

```bash
# Open vim help
vim
:help set
:help number
:help vimrc

# External resources
# - Vim official documentation: https://www.vim.org/docs.php
# - Vim tips and tricks
# - Vim plugins for enhanced functionality
```

## Author

Shell Workouts Repository
