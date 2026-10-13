# Display Date, Time, Username, and Working Directory Script

## Overview

The `display-date-time-username-curentworkingdirectory.sh` script displays essential system information in a single execution, including the current date and time, logged-in user details, and the current working directory.

## Purpose

This script is a quick diagnostic tool that provides:
- Current date and time
- Information about logged-in users
- Current working directory path

Useful for shell scripting, system administration, and understanding the current shell environment.

## Use Cases

- System administration and diagnostics
- Debugging shell scripts
- Logging system information
- Educational demonstrations of shell commands
- Monitoring user sessions and system state

## Prerequisites

- Bash or POSIX-compatible shell
- Standard UNIX/Linux utilities (`date`, `w`, `pwd`)

## Installation

1. Navigate to the repository directory:
```bash
cd /path/to/sh_workouts
```

2. Make the script executable:
```bash
chmod +x display-date-time-username-curentworkingdirectory.sh
```

## Usage

Simply execute the script:

```bash
./display-date-time-username-curentworkingdirectory.sh
```

Or source it in another script:

```bash
source display-date-time-username-curentworkingdirectory.sh
```

## Script Components

### 1. Display Date and Time

```bash
echo Date and Time is
date
```

Outputs the current system date and time in the format: `Day Month Date HH:MM:SS Timezone Year`

**Example output:**
```
Date and Time is
Wed Oct 13 20:46:28 UTC 2026
```

### 2. Display User Details

```bash
echo user details is
w
```

Shows information about all currently logged-in users using the `w` command. Displays:
- Username
- Terminal/TTY
- Remote IP address (if connected remotely)
- Login time
- Idle time
- CPU usage
- Current command being executed

**Example output:**
```
user details is
 20:46:28 up 45 min,  2 users,  load average: 0.10, 0.12, 0.09
USER     TTY      FROM             LOGIN@   IDLE   JCPU   PCPU WHAT
runner   pts/0    192.168.1.100    20:15    5.00s  0.30s  0.05s bash
admin    pts/1    192.168.1.101    20:30    0s     0.10s  0.02s sudo su
```

### 3. Display Current Working Directory

```bash
echo current directory is
pwd
```

Outputs the absolute path of the current working directory.

**Example output:**
```
current directory is
/home/runner/work/sh_workouts/sh_workouts
```

## Expected Output

A typical execution produces:

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

## Practical Examples

### Example 1: Basic Usage

```bash
$ ./display-date-time-username-curentworkingdirectory.sh
Date and Time is
Wed Oct 13 20:46:28 UTC 2026
user details is
...
current directory is
/home/runner
```

### Example 2: Capturing Output in a Script

```bash
#!/bin/bash
# Capture system information
./display-date-time-username-curentworkingdirectory.sh > system_info.txt
echo "System information saved to system_info.txt"
```

### Example 3: Using in a Log File

```bash
#!/bin/bash
# Log system state with timestamp
{
    echo "=== System State Log ==="
    ./display-date-time-username-curentworkingdirectory.sh
    echo "=== End Log ==="
} >> /var/log/system_state.log
```

### Example 4: Conditional Script Logic

```bash
#!/bin/bash
# Check current directory before proceeding
./display-date-time-username-curentworkingdirectory.sh
read -p "Is this the correct directory? (y/n): " answer
if [[ "$answer" != "y" ]]; then
    exit 1
fi
```

## Command Reference

### `date` Command

Displays the current system date and time. For custom formatting:

```bash
# Date only (YYYY-MM-DD)
date +%Y-%m-%d

# Time only (HH:MM:SS)
date +%H:%M:%S

# Custom format
date +"%A, %B %d, %Y at %I:%M %p"
```

### `w` Command

Shows logged-in users with detailed information.

Options:
- `w -h` - Omit header line
- `w -s` - Short format (omit JCPU and PCPU)
- `w <username>` - Show only specific user

```bash
# Short format
w -s

# Show specific user
w root
```

### `pwd` Command

Prints the current working directory. Options:
- `pwd -L` - Logical path (with symlinks)
- `pwd -P` - Physical path (resolved symlinks)

```bash
# Logical path (default)
pwd

# Physical path
pwd -P
```

## Notes

- The script uses standard UNIX/Linux commands available on most systems.
- The `w` command shows all currently logged-in users. In a container or single-user system, output may show only one user.
- Directory paths shown are the absolute paths from the root filesystem.
- The script can be easily modified to capture individual components into variables for scripting purposes.
- Load average in the `w` output shows 1-minute, 5-minute, and 15-minute averages.

## Customization Examples

### Capture Components Separately

```bash
#!/bin/bash
# Modify to capture individual components
current_date=$(date)
current_user=$(whoami)
current_dir=$(pwd)

echo "Date: $current_date"
echo "User: $current_user"
echo "Directory: $current_dir"
```

### Add to Shell Initialization Files

Add to your `.bashrc` or `.zshrc` to run automatically on login:

```bash
# ~/.bashrc
echo "=== System Information ==="
/path/to/display-date-time-username-curentworkingdirectory.sh
```

## Related Scripts

- [user-loggedin-or-not.sh](./user-loggedin.md) - Check if specific user is logged in
- [alias.sh](./alias.md) - Contains aliases for common commands

## Troubleshooting

**Script not executing:**
- Ensure execute permissions: `chmod +x display-date-time-username-curentworkingdirectory.sh`
- Verify bash is available: `which bash`

**Permission denied for `w` command:**
- The `w` command is available to all users and doesn't require special permissions
- If no output, try: `w -h`

**Different output than expected:**
- Output format may vary by system. This is normal.
- Run `man date` and `man w` to see system-specific formats

## Author

Shell Workouts Repository
