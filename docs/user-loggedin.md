# Check User Logged-In Status Script

## Overview

The `user-loggedin-or-not.sh` script checks whether a specific user is currently logged into the system. It provides a simple yes/no answer to user session queries.

## Purpose

This script:
- Determines if a specified user has an active session on the system
- Outputs clear status messages
- Can be used in conditional logic and shell scripts
- Useful for access control and monitoring

## Use Cases

- System administration and user session monitoring
- Access control verification
- Conditional script execution based on user status
- Automated alerts when specific users log in/out
- Server management and auditing

## Prerequisites

- Bash or POSIX-compatible shell
- Standard UNIX/Linux utilities (`who`, `grep`)
- Local or remote user access to the system

## Installation

1. Navigate to the repository directory:
```bash
cd /path/to/sh_workouts
```

2. Make the script executable:
```bash
chmod +x user-loggedin-or-not.sh
```

## Usage

Simply execute the script and enter the username when prompted:

```bash
./user-loggedin-or-not.sh
```

You'll be prompted to enter a username:

```
Enter name of the user: <type username here>
```

The script will output:

```
User is logged in to the system
```

or

```
User is not logged in to the system
```

## Script Breakdown

The script performs the following steps:

```bash
#!/bin/bash
echo -n "Enter name of the user: "
read user
c=$(who | grep -ci $user)
if [ $c -gt 0 ]
then
    echo "User is logged in to the system"
else
    echo "User is not logged in to the system"
fi
```

### Step 1: Prompt for Input

```bash
echo -n "Enter name of the user: "
read user
```

Displays a prompt and reads the username from user input. The `-n` flag suppresses the newline, keeping the prompt on the same line.

### Step 2: Check User Status

```bash
c=$(who | grep -ci $user)
```

- `who` - Lists all currently logged-in users
- `grep -ci $user` - Searches for the username (case-insensitive, `-i` flag)
- `-c` - Returns count of matching lines
- `$c` - Stores the count in variable `c`

### Step 3: Conditional Output

```bash
if [ $c -gt 0 ]
then
    echo "User is logged in to the system"
else
    echo "User is not logged in to the system"
fi
```

If the count is greater than 0, the user is logged in. Otherwise, the user is not logged in.

## Usage Examples

### Example 1: Check if root is logged in

```bash
$ ./user-loggedin-or-not.sh
Enter name of the user: root
User is logged in to the system
```

### Example 2: Check for non-existent user

```bash
$ ./user-loggedin-or-not.sh
Enter name of the user: nonexistentuser
User is not logged in to the system
```

### Example 3: Multiple sessions for same user

If a user has multiple login sessions, the script will detect at least one:

```bash
$ ./user-loggedin-or-not.sh
Enter name of the user: admin
User is logged in to the system
```

Even if `admin` has 3 concurrent sessions, the result is the same (user is logged in).

## Advanced Usage in Scripts

### Example 1: Automated Script Execution

```bash
#!/bin/bash
# Check if admin user is logged in before proceeding
if [ "$(echo 'admin' | ./user-loggedin-or-not.sh 2>&1)" == *"logged in"* ]; then
    echo "Admin is available, proceeding with updates"
    # Run admin tasks
else
    echo "Admin not logged in, aborting"
    exit 1
fi
```

### Example 2: Using with Non-Interactive Input

```bash
#!/bin/bash
# Create a modified version that accepts username as argument
username="$1"
c=$(who | grep -ci $username)
if [ $c -gt 0 ]; then
    echo "User is logged in to the system"
else
    echo "User is not logged in to the system"
fi
```

Then use:
```bash
./user-loggedin-or-not.sh admin
```

### Example 3: Monitoring Multiple Users

```bash
#!/bin/bash
# Check multiple users
for user in admin root apache nginx; do
    c=$(who | grep -ci $user)
    if [ $c -gt 0 ]; then
        echo "$user: logged in"
    else
        echo "$user: not logged in"
    fi
done
```

### Example 4: Send Alert if User Logs In

```bash
#!/bin/bash
# Monitor for specific user login
target_user="$1"
check_interval=60  # seconds

while true; do
    c=$(who | grep -ci $target_user)
    if [ $c -gt 0 ]; then
        echo "ALERT: $target_user has logged in at $(date)" | mail -s "Login Alert" admin@example.com
        exit 0
    fi
    sleep $check_interval
done
```

## Related Commands

### The `who` Command

Lists all logged-in users with details:

```bash
# Basic usage
who

# Show terminal types
who -a

# Count logged-in users
who | wc -l

# Show current user
who am i
```

**Output format:**
```
username  tty         date/time          [hostname]
runner    pts/0       Oct 13 20:15 (192.168.1.100)
admin     pts/1       Oct 13 20:30
```

### The `grep` Command

Searches for patterns:

```bash
# Case-insensitive search
grep -i "username" /var/log/auth.log

# Count matching lines
grep -c "username" /var/log/auth.log

# Case-insensitive count
grep -ic "username" /var/log/auth.log
```

## Expected Output

**User is logged in:**
```
User is logged in to the system
```

**User is not logged in:**
```
User is not logged in to the system
```

## Notes

- The `who` command shows only users with active login sessions (TTY or pseudo-terminal).
- Background processes running under a user's UID (e.g., cron jobs, daemons) won't be detected by this script. Use `ps aux` to check for running processes.
- The script is case-insensitive when searching for usernames (uses `-i` flag with grep).
- Multiple simultaneous sessions for the same user will be detected as one logged-in user.
- The script queries the system's session database, which may vary on different systems (local vs. remote systems).

## Differences: Logged-In User vs. Running Processes

### This Script (`who` command)
Shows users with active login **sessions**:
- SSH sessions
- Local terminal login
- GUI login sessions

### Alternative: Process Check (`ps` command)
Shows users with **running processes**:
```bash
ps aux | grep -i "^$user"
```

Includes background processes, cron jobs, and daemons.

## Troubleshooting

**Script doesn't run:**
- Ensure execute permissions: `chmod +x user-loggedin-or-not.sh`
- Verify bash is available: `which bash`

**Always shows "not logged in":**
- Verify the username is spelled correctly
- Check the user actually has a session: `who`
- On some systems, usernames are case-sensitive

**Unexpected behavior on remote systems:**
- If checking remote users, ensure you have appropriate SSH/access permissions
- The script only checks the local system's session database
- For remote checking, use: `ssh user@host 'who' | grep username`

## Variations and Customizations

### Version: Accept Username as Argument

```bash
#!/bin/bash
if [ -z "$1" ]; then
    echo -n "Enter name of the user: "
    read user
else
    user="$1"
fi
c=$(who | grep -ci $user)
if [ $c -gt 0 ]
then
    echo "User is logged in to the system"
else
    echo "User is not logged in to the system"
fi
```

### Version: Return Exit Code

```bash
#!/bin/bash
c=$(who | grep -ci "$1")
exit $([ $c -gt 0 ] && echo 0 || echo 1)
# Exit code 0 = user logged in, 1 = not logged in
```

## Related Scripts

- [display-date-time.md](./display-date-time.md) - Shows logged-in users with details
- [alias.sh](./alias.md) - Useful command aliases

## Author

Shell Workouts Repository
