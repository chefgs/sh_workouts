# TOC Format Converter

## Overview

The `toc.sh` script processes lines containing table of contents entries and converts them to properly formatted markdown anchor links. It transforms parenthesized content into clickable anchor format.

## Purpose

This script:
- Reads TOC entries from a file
- Converts TOC format to markdown anchor format
- Handles uppercase to lowercase conversion
- Replaces spaces with hyphens in anchors
- Generates properly formatted markdown links

## Use Cases

- Converting existing TOC format to markdown
- Reformatting TOC entries
- Batch processing TOC entries from documents
- Converting documentation from other formats to markdown

## Prerequisites

- Bash or POSIX-compatible shell
- Standard UNIX/Linux utilities (`cat`, `cut`, `tr`, `echo`)
- Input file with TOC entries

## Installation

1. Navigate to the repository directory:
```bash
cd /path/to/sh_workouts
```

2. Make the script executable:
```bash
chmod +x toc.sh
```

## Usage

1. Create a file with TOC entries (with text in parentheses):

```bash
cat > toc.txt << EOF
Getting Started(Getting Started)
Installation Instructions(Installation Instructions)
Usage Examples(Usage Examples)
Troubleshooting Guide(Troubleshooting Guide)
EOF
```

2. Run the script with the file as argument:

```bash
./toc.sh toc.txt
```

3. Output appears with converted anchor format

## Script Breakdown

The script processes input in the following way:

```bash
#!/bin/sh
toc_filename=$1
cat $toc_filename  | while read line
do
    field1=`echo $line | cut -f1 -d"("`
    field2=`echo $line | cut -f2 -d"(" | tr [:upper:] [:lower:] | tr " " "-"`
    echo $field1"("$field2
done
```

### Step 1: Accept Filename

```bash
toc_filename=$1
```

Takes the filename as the first command-line argument.

### Step 2: Read Each Line

```bash
cat $toc_filename  | while read line
do
```

Reads the file line by line.

### Step 3: Extract Display Text

```bash
field1=`echo $line | cut -f1 -d"("`
```

- `cut -f1 -d"("` - Extracts everything before the opening parenthesis
- Example: "Getting Started(" from "Getting Started(Getting Started)"
- This is the displayed link text

### Step 4: Extract Anchor Text

```bash
field2=`echo $line | cut -f2 -d"(" | tr [:upper:] [:lower:] | tr " " "-"`
```

- `cut -f2 -d"("` - Extracts everything after the opening parenthesis
- `tr [:upper:] [:lower:]` - Converts to lowercase
- `tr " " "-"` - Replaces spaces with hyphens
- Removes closing parenthesis if present
- Example: "getting-started" from "Getting Started)"

### Step 5: Generate Output

```bash
echo $field1"("$field2
done
```

Outputs the formatted entry with converted anchor.

## Usage Examples

### Example 1: Basic TOC Conversion

Input file (toc_input.txt):
```
Getting Started(Getting Started)
Installation(Installation)
Configuration(Configuration)
Usage(Usage)
```

Command:
```bash
./toc.sh toc_input.txt
```

Output:
```
Getting Started(getting-started)
Installation(installation)
Configuration(configuration)
Usage(usage)
```

### Example 2: Complex TOC Entries

Input file with longer text:

```
Quick Start Guide(Quick Start Guide)
Advanced Configuration Options(Advanced Configuration Options)
Performance Tuning Best Practices(Performance Tuning Best Practices)
Troubleshooting Common Issues(Troubleshooting Common Issues)
```

Run:
```bash
./toc.sh toc_input.txt
```

Output:
```
Quick Start Guide(quick-start-guide)
Advanced Configuration Options(advanced-configuration-options)
Performance Tuning Best Practices(performance-tuning-best-practices)
Troubleshooting Common Issues(troubleshooting-common-issues)
```

### Example 3: Converting to Markdown Link Format

Process the output for markdown links:

```bash
#!/bin/bash
# Convert TOC entries to markdown links

./toc.sh toc_input.txt | while read line; do
    display=$(echo $line | cut -d'(' -f1)
    anchor=$(echo $line | cut -d'(' -f2 | tr -d ')')
    echo "- [$display](#$anchor)"
done
```

### Example 4: Batch Processing Multiple Files

```bash
#!/bin/bash
# Process multiple TOC files

for file in toc_*.txt; do
    echo "Processing $file..."
    ./toc.sh "$file" > "${file%.txt}_converted.txt"
done
```

### Example 5: Saving and Appending Output

```bash
# Process and save to new file
./toc.sh input_toc.txt > output_toc.txt

# Append to existing document
echo "## Table of Contents" >> README.md
./toc.sh toc_entries.txt >> README.md
```

## Expected Output

For each input line in format: `DisplayText(AnchorText)`

**Output format:** `DisplayText(converted-anchor-text)`

Where:
- `DisplayText` - remains unchanged
- `AnchorText` - converted to lowercase with hyphens

### Example Transformation

| Input | Output |
|-------|--------|
| `Getting Started(Getting Started)` | `Getting Started(getting-started)` |
| `API Reference(API Reference)` | `API Reference(api-reference)` |
| `Best Practices(Best Practices)` | `Best Practices(best-practices)` |

## Input Format

The script expects input lines with the following format:

```
DisplayText(AnchorText)
```

Where:
- `DisplayText` - Text to display (not modified)
- `(` - Opening parenthesis delimiter
- `AnchorText` - Text to convert to anchor (converted to lowercase, spaces to hyphens)
- `)` - Closing parenthesis (optional, handled gracefully)

## Notes

- **Display text preserved**: The text before the parenthesis is kept as-is
- **Anchor conversion**: Text inside parentheses is converted to lowercase and spaces become hyphens
- **Closing parenthesis**: Script handles input with or without closing parenthesis
- **Single-line processing**: Each line is processed independently

## Real-World Workflow

Typical workflow with other scripts:

```bash
#!/bin/bash
# Complete TOC generation workflow

# Step 1: Extract headings from markdown
./toc-from-markdown.sh README.md > extracted_headings.txt

# Step 2: If headings are in a special format, convert them
./toc.sh extracted_headings.txt > converted_toc.txt

# Step 3: Manual review and insert into README
# Edit README.md and add converted_toc.txt content
```

## Customization Examples

### Add Markdown Formatting

```bash
#!/bin/bash
# Generate markdown TOC from toc.sh output

./toc.sh "$1" | while read line; do
    display=$(echo "$line" | cut -d'(' -f1)
    anchor=$(echo "$line" | cut -d'(' -f2 | tr -d ')')
    echo "- [$display](#$anchor)"
done
```

### Filter by Length

```bash
#!/bin/bash
# Only process lines with certain characteristics

./toc.sh "$1" | while read line; do
    if [ ${#line} -gt 20 ]; then
        echo "$line"
    fi
done
```

## Troubleshooting

**Script doesn't run:**
- Ensure execute permissions: `chmod +x toc.sh`
- Check file exists: `ls -la toc.sh`

**No output generated:**
- Verify input file format: `cat input_file`
- Check file has lines with `(` character
- Verify file permissions: `ls -la input_file`

**Incorrect anchor conversion:**
- Verify text inside parentheses is what should be converted
- Check that text is fully enclosed in parentheses
- Special characters may not convert properly (manual edit needed)

**File not found:**
- Use absolute path: `/full/path/to/toc.sh input_file`
- Verify input file exists in current directory
- Check working directory: `pwd`

## Related Scripts

- [toc-from-headings.sh](./toc-from-headings.md) - Generate TOC from heading file
- [toc-from-markdown.sh](./toc-from-markdown.md) - Extract headings from markdown

## Author

Shell Workouts Repository
