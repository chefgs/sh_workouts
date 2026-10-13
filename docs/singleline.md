# Single Line Text Processing Commands

## Overview

The `singleline.sh` script demonstrates powerful text processing techniques using Unix pipes and tools. It shows how to count word frequencies, analyze text patterns, and process command output efficiently using a single pipeline.

## Purpose

This script:
- Demonstrates word frequency analysis using pipes
- Shows text transformation techniques (tr, sed, sort, uniq)
- Provides examples of file processing with command tools
- Educational reference for shell scripting and data processing

## Use Cases

- Text analysis and word frequency counting
- Learning Unix pipeline techniques
- Data processing demonstrations
- Finding most common words in documents
- Analyzing command output patterns

## Prerequisites

- Bash or POSIX-compatible shell
- Standard UNIX/Linux utilities:
  - `tr` - Translate/transform characters
  - `sed` - Stream editor
  - `sort` - Sort lines
  - `uniq` - Report or filter repeated lines
  - `awk` - Pattern scanning and processing
  - `ls` - List directory contents

## Installation

1. Navigate to the repository directory:
```bash
cd /path/to/sh_workouts
```

2. Make the script executable:
```bash
chmod +x singleline.sh
```

## Usage

Simply execute the script:

```bash
./singleline.sh
```

The script runs several examples and displays their output.

## Script Breakdown

The script demonstrates multiple text processing techniques:

### Example 1: Word Frequency Analysis

```bash
string="This is a sample string that should contain repeated sample string sentence..."
echo $string | tr -c '[:alnum:]' '\n' | tr '[:upper:]' '[:lower:]' | sed '/^$/d' | sort | uniq -c | sort -nr
```

**Step by step:**

1. **`tr -c '[:alnum:]' '\n'`** - Translate non-alphanumeric to newlines
   - Converts the string to one word per line
   - `-c` means complement (non-alphanumeric characters)
   - Output:
   ```
   This
   is
   a
   sample
   string
   ...
   ```

2. **`tr '[:upper:]' '[:lower:]'`** - Convert uppercase to lowercase
   - Normalizes all words to lowercase
   - Output:
   ```
   this
   is
   a
   sample
   string
   ...
   ```

3. **`sed '/^$/d'`** - Remove empty lines
   - Deletes lines that only contain whitespace
   - `-e` flag: use script for processing
   - `/^$/` - matches empty lines
   - `d` - delete action

4. **`sort`** - Sort lines alphabetically
   - Arranges words in alphabetical order
   - Output:
   ```
   a
   a
   a
   ...
   ```

5. **`uniq -c`** - Count unique lines with prefix count
   - Counts consecutive identical lines
   - `-c` flag shows count before each line
   - Output:
   ```
   3 a
   1 and
   2 be
   ...
   ```

6. **`sort -nr`** - Sort numerically in reverse order
   - `-n` - numeric sort
   - `-r` - reverse order (descending)
   - Final output (most frequent words first):
   ```
   5 sample
   4 string
   3 that
   2 sentence
   1 is
   ...
   ```

### Example 2: Formatted Word Frequency with AWK

```bash
echo $string | tr -c '[:alnum:]' '\n' | tr '[:upper:]' '[:lower:]' | sed '/^$/d' | sort | uniq -c | sort -nr | awk '{ print $1 " -> " $2}'
```

Same as above, but the final `awk` command formats output:

```bash
awk '{ print $1 " -> " $2}'
```

- Prints count and word separated by ` -> `
- Output:
```
5 -> sample
4 -> string
3 -> that
2 -> sentence
1 -> is
```

### Example 3: File Listing Analysis

```bash
ls -l | tr -c '[:graph:]' '\n' | sed '/^$/d' | sort | uniq -c | sort -n
```

Analyzes `ls -l` output:

1. **`ls -l`** - Long format file listing
2. **`tr -c '[:graph:]' '\n'`** - Convert non-printable to newlines
   - Splits each printable element onto a line
3. **`sed '/^$/d'`** - Remove empty lines
4. **`sort`** - Sort elements
5. **`uniq -c`** - Count occurrences
6. **`sort -n`** - Sort numerically

Useful for finding:
- Most common file permissions
- Most common owners
- File size patterns
- Date/time formats

### Example 4: File Permission Analysis

Commented-out advanced examples:

```bash
# ll | tr -c '[:graph:]' '\n' | sed '/^$/d' | sort | uniq -c | sort -n | grep -w '\-rw'
```

Shows only regular files and their occurrence in `ls` output.

## Usage Examples

### Example 1: Basic Word Frequency

```bash
#!/bin/bash
# Analyze word frequency in a text file

cat myfile.txt | tr -c '[:alnum:]' '\n' | tr '[:upper:]' '[:lower:]' | \
sed '/^$/d' | sort | uniq -c | sort -nr | head -20
```

Finds 20 most common words in myfile.txt

### Example 2: Analyze Log Files

```bash
#!/bin/bash
# Find most common log messages

cat /var/log/syslog | cut -d':' -f4 | sort | uniq -c | sort -nr | head -10
```

Shows 10 most common syslog entries.

### Example 3: Process Output Analysis

```bash
#!/bin/bash
# Analyze ps output for running commands

ps aux | awk '{print $11}' | tr -c '[:alnum:]' '\n' | tr '[:upper:]' '[:lower:]' | \
sed '/^$/d' | sort | uniq -c | sort -nr
```

Shows most common running processes.

### Example 4: File Statistics

```bash
#!/bin/bash
# Analyze file extensions in directory

ls -la | awk '{print $9}' | grep '\.' | awk -F'.' '{print $NF}' | \
sort | uniq -c | sort -nr
```

Shows file type distribution by extension.

### Example 5: Custom Text Pipeline

```bash
#!/bin/bash
# Count specific patterns in file

grep "ERROR" logfile.txt | tr -c '[:alnum:]' '\n' | sort | uniq -c | sort -nr
```

Analyzes only error log entries.

## Command Reference

### `tr` - Translate Characters

```bash
# Translate uppercase to lowercase
echo "HELLO" | tr '[:upper:]' '[:lower:]'
# Output: hello

# Replace spaces with newlines
echo "one two three" | tr ' ' '\n'
# Output:
# one
# two
# three

# Remove characters (complement set)
echo "Hello123" | tr -d '[:digit:]'
# Output: Hello
```

Character classes:
- `[:alnum:]` - Alphanumeric [a-zA-Z0-9]
- `[:alpha:]` - Alphabetic [a-zA-Z]
- `[:digit:]` - Digits [0-9]
- `[:lower:]` - Lowercase [a-z]
- `[:upper:]` - Uppercase [A-Z]
- `[:space:]` - Whitespace
- `[:graph:]` - Printable non-space

### `sed` - Stream Editor

```bash
# Delete empty lines
sed '/^$/d' file.txt

# Replace text (s = substitute)
sed 's/old/new/' file.txt

# Replace all occurrences on a line
sed 's/old/new/g' file.txt

# Delete lines matching pattern
sed '/pattern/d' file.txt
```

### `sort` - Sort Lines

```bash
# Sort alphabetically
sort file.txt

# Sort numerically
sort -n file.txt

# Sort in reverse order
sort -r file.txt

# Sort numerically descending
sort -nr file.txt
```

### `uniq` - Remove Duplicates

```bash
# Count occurrences
uniq -c file.txt

# Show only duplicates
uniq -d file.txt

# Skip repeated lines
uniq file.txt
```

### `awk` - Text Processing

```bash
# Print specific field
awk '{print $1}' file.txt

# Print multiple fields with formatting
awk '{print $1 " -> " $2}' file.txt

# Process based on condition
awk '$1 > 100' file.txt
```

## Expected Output

When running the script:

```
Word Frequency Analysis:
     5 sample
     4 string
     3 that
     2 sentence
     2 that
     1 is

Formatted Output:
5 -> sample
4 -> string
3 -> that

File Analysis:
      1 -rw-r--r--
      2 drwxr-xr-x
      3 total
...
```

## Notes

- **Performance**: Pipe processing is efficient for text transformation
- **Educational value**: Demonstrates core Unix philosophy: small tools combined via pipes
- **Flexibility**: These techniques work with any text input
- **Sorting**: Always sort before `uniq` for accurate counts
- **Memory usage**: Pipes process data stream-by-stream, minimizing memory

## Common Patterns

### Pattern 1: Word Frequency
```bash
cat file.txt | tr -c '[:alnum:]' '\n' | tr '[:upper:]' '[:lower:]' | sed '/^$/d' | sort | uniq -c | sort -nr
```

### Pattern 2: Remove Empty Lines
```bash
cat file.txt | sed '/^$/d'
```

### Pattern 3: Convert to Lowercase
```bash
cat file.txt | tr '[:upper:]' '[:lower:]'
```

### Pattern 4: Extract and Count
```bash
grep "pattern" file.txt | cut -d',' -f2 | sort | uniq -c | sort -nr
```

## Troubleshooting

**Script doesn't run:**
- Ensure execute permissions: `chmod +x singleline.sh`
- Verify utilities are installed: `which tr sed sort uniq awk`

**Unexpected output:**
- Verify input data format
- Check character classes are correct
- Use `set -x` for debugging: `bash -x singleline.sh`

**Performance issues with large files:**
- Use `grep` to filter before processing
- Consider using `mawk` or `gawk` instead of `awk` for speed
- Test on smaller subset first

## Related Scripts

- [display-date-time.md](./display-date-time.md) - System information script
- [toc-from-markdown.md](./toc-from-markdown.md) - Text extraction script

## Further Reading

- `man tr` - Character translation
- `man sed` - Stream editor documentation
- `man awk` - Pattern scanning and processing
- [The Unix Philosophy](https://en.wikipedia.org/wiki/Unix_philosophy)

## Author

Shell Workouts Repository
