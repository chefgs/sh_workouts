#!/usr/bin/env bash
#
# extract-codeblocks.sh - pull fenced code blocks out of Markdown or LLM output.
#
# Anyone piping model output into a shell needs this: the answer arrives as
# prose wrapped around fenced code, and only the code is wanted.
#
# SAFETY: extracting code is not vetting it. Never pipe the output of this
# script straight into a shell or an interpreter. Read it first.
#
#   ./extract-codeblocks.sh answer.md
#   ./extract-codeblocks.sh --lang bash --list answer.md
#   ./extract-codeblocks.sh --out ./blocks answer.md

set -euo pipefail
# shellcheck source=lib/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib/common.sh"

usage() {
    cat <<'USAGE'
Usage: extract-codeblocks.sh [OPTIONS] [FILE]

Print the contents of fenced code blocks. Reads FILE, or stdin when FILE is
omitted or "-".

Options:
  --lang LANG   only blocks whose info string starts with LANG
  --index N     only the Nth block (1-based, counted after --lang filtering)
  --list        list blocks as "INDEX LANG LINES" instead of printing them
  --out DIR     write each block to DIR/block-NNN.LANG instead of stdout
  --fences      keep the ``` fence lines in the output
  -h, --help    show this help

Both ``` and ~~~ fences are recognised. A fence inside an indented block is
treated as a fence, which matches how most Markdown renderers behave for the
LLM output this is aimed at.

Remember: extracted code is untrusted input. Review before running it.
USAGE
}

lang=''
index=0
do_list=0
out_dir=''
keep_fences=0

while [ $# -gt 0 ]; do
    case "$1" in
        --lang)
            [ $# -ge 2 ] || die 'option --lang needs a value'
            lang="$2"
            shift 2
            ;;
        --index)
            [ $# -ge 2 ] || die 'option --index needs a value'
            tp_require_int "$2" '--index'
            [ "$2" -ge 1 ] || die '--index must be at least 1'
            index="$2"
            shift 2
            ;;
        --list) do_list=1; shift ;;
        --out)
            [ $# -ge 2 ] || die 'option --out needs a value'
            out_dir="$2"
            shift 2
            ;;
        --fences) keep_fences=1; shift ;;
        -h | --help) usage; exit 0 ;;
        --) shift; break ;;
        -*) die "unknown option: $1 (try --help)" ;;
        *) break ;;
    esac
done
[ $# -le 1 ] || die 'expected at most one FILE argument'

tp_input "${1:-}"

# Emit INDEX \t LANG \t LINENO \t TEXT for every line inside a matching block.
scan() {
    awk -v want="$lang" -v keep_fences="$keep_fences" '
    function fence_lang(line) {
        sub(/^[ \t]*(```+|~~~+)[ \t]*/, "", line)
        sub(/[ \t].*$/, "", line)
        return line
    }
    /^[ \t]*(```|~~~)/ {
        if (!inblock) {
            inblock = 1
            cur_lang = fence_lang($0)
            if (cur_lang == "") cur_lang = "txt"
            matched = (want == "" || index(cur_lang, want) == 1)
            if (matched) { idx++; n = 0 }
            if (matched && keep_fences) printf "%d\t%s\t%d\t%s\n", idx, cur_lang, ++n, $0
            next
        }
        if (matched && keep_fences) printf "%d\t%s\t%d\t%s\n", idx, cur_lang, ++n, $0
        inblock = 0
        next
    }
    inblock && matched { printf "%d\t%s\t%d\t%s\n", idx, cur_lang, ++n, $0 }
    ' "$TP_INPUT"
}

selected() {
    if [ "$index" -gt 0 ]; then
        scan | awk -F'\t' -v want="$index" '$1 == want'
    else
        scan
    fi
}

if [ "$do_list" -eq 1 ]; then
    selected | awk -F'\t' '
        { lang[$1] = $2; lines[$1]++ }
        END { for (i = 1; i <= 100000; i++) if (i in lines) printf "%5d %-12s %5d\n", i, lang[i], lines[i] }'
    exit 0
fi

if [ -n "$out_dir" ]; then
    mkdir -p -- "$out_dir" || die "cannot create directory: $out_dir"
    # Writing one file per block keeps each block's language in its extension.
    selected | awk -F'\t' -v dir="$out_dir" '
        {
            file = sprintf("%s/block-%03d.%s", dir, $1, $2)
            print $4 > file
        }
        END { if (NR == 0) print "no matching code blocks" > "/dev/stderr" }'
    find "$out_dir" -maxdepth 1 -name 'block-*' -type f | sort
    exit 0
fi

selected | cut -f4-
