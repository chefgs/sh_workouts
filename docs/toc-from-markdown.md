# Table of Contents Generator from Markdown

## Overview

The `toc-from-markdown.sh` script extracts markdown headings from a document and generates a Table of Contents with clickable anchor links. This is useful for automatically creating TOC from existing markdown files.

## Purpose

This script:
- Extracts all markdown headings (lines starting with #) from a file
- Converts heading text to markdown anchor format
- Generates markdown-formatted TOC entries
- Automates TOC creation directly from markdown source

## Use Cases

- Creating TOC from existing markdown documents
- Generating navigation for blog posts
- Creating index for documentation
- Markdown-based static site generators
- README file enrichment

## Prerequisites

- Bash or POSIX-compatible shell
- Standard UNIX/Linux utilities (`grep`, `tr`, `sed`, `echo`)
- A markdown file with headings (lines starting with #)

## Installation

1. Navigate to the repository directory:
```bash
cd /path/to/sh_workouts
```

2. Make the script executable:
```bash
chmod +x toc-from-markdown.sh
```

## Usage

1. Run the script with a markdown file as argument:

```bash
./toc-from-markdown.sh README.md
```

2. The script extracts headings and outputs TOC format:

```markdown
- [Introduction](#introduction)
- [Installation](#installation)
- [Usage](#usage)
- [Examples](#examples)
- [Troubleshooting](#troubleshooting)
```

3. Copy the output into your markdown file's Table of Contents section.

## Script Breakdown

The script operates in the following sequence:

```bash
#!/bin/sh
blog_filename=$1
grep "#" $blog_filename | tr -d '^#' | sed 's/^ //' | while read line
do
    field2=`echo $line | tr [:upper:] [:lower:] | tr " " "-"`
    echo "- ["$line"]""(#"$field2")"
done
```

### Step 1: Accept Filename

```bash
blog_filename=$1
```

Takes the markdown file as the first command-line argument.

### Step 2: Extract Headings

```bash
grep "#" $blog_filename
```

Searches for all lines containing `#` (markdown heading marker).

### Step 3: Clean Heading Text

```bash
tr -d '^#'
```

Removes the `#` characters (the caret `^` means "not").

Actually this removes the `#` character itself, leaving just the heading text.

### Step 4: Remove Leading Spaces

```bash
sed 's/^ //'
```

Removes leading space after the `#` marker.

### Step 5: Convert to Anchor

```bash
field2=`echo $line | tr [:upper:] [:lower:] | tr " " "-"`
```

- Converts uppercase to lowercase
- Replaces spaces with hyphens
- Example: "Getting Started" becomes "getting-started"

### Step 6: Generate TOC Entry

```bash
echo "- ["$line"]""(#"$field2")"
```

Creates markdown TOC entry: `- [Heading](#anchor)`

## Usage Examples

### Example 1: Simple Markdown File

Create a markdown file:

```bash
cat > guide.md << EOF
# Getting Started

Introduction content here.

## Installation

Installation steps here.

## Configuration

Configuration details here.

## Usage Examples

Example usage here.

## FAQ

Frequently asked questions here.
EOF
```

Run the script:

```bash
./toc-from-markdown.sh guide.md
```

Output:

```
- [Getting Started](#getting-started)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage Examples](#usage-examples)
- [FAQ](#faq)
```

### Example 2: Nested Headings

Markdown file with multiple heading levels:

```bash
cat > docs.md << EOF
# Main Title

## Chapter 1

### Section 1.1

Content here.

### Section 1.2

More content.

## Chapter 2

Content here.
EOF
```

Run the script:

```bash
./toc-from-markdown.sh docs.md
```

Output:

```
- [Main Title](#main-title)
- [Chapter 1](#chapter-1)
- [Section 1.1](#section-11)
- [Section 1.2](#section-12)
- [Chapter 2](#chapter-2)
```

### Example 3: Save Output to File

```bash
# Generate TOC and save to file
./toc-from-markdown.sh README.md > toc_output.txt

# View the output
cat toc_output.txt
```

### Example 4: Automatic README Update

```bash
#!/bin/bash
# Generate TOC and insert into README after a marker

# Generate TOC
TOC=$(./toc-from-markdown.sh README.md)

# Create new README with TOC
{
    echo "# Project Name"
    echo ""
    echo "## Table of Contents"
    echo ""
    echo "$TOC"
    echo ""
    echo "## Content"
    tail -n +3 README.md
} > README_new.md

mv README_new.md README.md
```

### Example 5: Pipeline Usage

```bash
# Generate TOC and pipe to another command
./toc-from-markdown.sh GUIDE.md | head -5

# Combine TOC from multiple files
./toc-from-markdown.sh docs/part1.md > combined_toc.md
./toc-from-markdown.sh docs/part2.md >> combined_toc.md
```

## Expected Output

**Markdown file contains:**
```markdown
# Main Title
## Section 1
## Section 2
### Subsection 2.1
```

**Script output:**
```
- [Main Title](#main-title)
- [Section 1](#section-1)
- [Section 2](#section-2)
- [Subsection 2.1](#subsection-21)
```

## Markdown Heading Levels

The script processes all markdown heading levels:

| Symbol | Level | Example |
|--------|-------|---------|
| `#` | H1 | # Main Title |
| `##` | H2 | ## Section |
| `###` | H3 | ### Subsection |
| `####` | H4 | #### Sub-subsection |
| `#####` | H5 | ##### Level 5 |
| `######` | H6 | ###### Level 6 |

All levels are extracted and included in the generated TOC.

## Anchor Link Format

Generated anchors follow markdown conventions:

| Heading | Generated Anchor |
|---------|------------------|
| `# Main Title` | `#main-title` |
| `## Getting Started` | `#getting-started` |
| `### Best Practices` | `#best-practices` |
| `#### Advanced Usage` | `#advanced-usage` |

Rules:
- Uppercase letters converted to lowercase
- Spaces replaced with hyphens
- Anchor placed after `#` symbol

## Using Generated TOC

1. Place TOC near the beginning of your markdown file:

```markdown
# Documentation

## Table of Contents

- [Introduction](#introduction)
- [Installation](#installation)
- [Usage](#usage)

## Introduction

Content here...

## Installation

Content here...

## Usage

Content here...
```

2. When rendered, clicking a TOC entry jumps to that section
3. Works in GitHub, GitLab, and most markdown renderers

## Advanced Examples

### Example 1: TOC with Descriptions

Combine generated TOC with manual descriptions:

```bash
#!/bin/bash
# Generate TOC and add descriptions

echo "## Table of Contents"
echo ""
./toc-from-markdown.sh README.md | while read line; do
    echo "$line"
done
echo ""
echo "Each section contains detailed information about that topic."
```

### Example 2: Filter Specific Heading Levels

```bash
#!/bin/bash
# Only extract H2 headings (## heading)
grep "^## " "$1" | sed 's/^## //' | while read line; do
    anchor=`echo $line | tr '[:upper:]' '[:lower:]' | tr ' ' '-'`
    echo "- [$line](#$anchor)"
done
```

## Notes

- **Automatic extraction**: Unlike `toc-from-headings.sh`, this script directly reads markdown files
- **All heading levels**: Extracts and includes all heading levels (H1-H6)
- **Preserves order**: TOC entries appear in document order
- **Dynamic**: Regenerating TOC is quick and can be automated
- **Markdown compatibility**: Works with GitHub, GitLab, standard Markdown, and most renderers

## Common Issues and Solutions

**Empty output:**
- Verify file contains markdown headings (lines starting with #)
- Check file has read permissions: `ls -la filename.md`
- Try: `grep "#" filename.md` to see if headings exist

**Incorrect anchor format:**
- Anchors should be lowercase with hyphens
- Special characters may need manual adjustment
- Check markdown processor documentation for anchor rules

**Links not working:**
- Ensure heading text exactly matches TOC entry text
- Verify anchor format (lowercase, hyphens)
- Test in your markdown renderer

**Script permission denied:**
- Make executable: `chmod +x toc-from-markdown.sh`
- Run with full path: `/full/path/to/toc-from-markdown.sh file.md`

## Related Scripts

- [toc-from-headings.sh](./toc-from-headings.md) - Generate TOC from heading file
- [toc.sh](./toc.md) - Another TOC transformation script

## Integration with CI/CD

```bash
#!/bin/bash
# GitHub Actions or CI/CD integration
# Automatically regenerate TOC on every commit

if [ -f "README.md" ]; then
    ./toc-from-markdown.sh README.md > toc_temp.txt
    # Insert TOC into README
    # Commit changes
fi
```

## Author

Shell Workouts Repository
