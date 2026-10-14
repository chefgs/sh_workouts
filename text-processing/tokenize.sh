#!/usr/bin/env bash
#
# tokenize.sh - split text into the units a model or an index works on.
#
# This is the generalisation of the pipeline in ../singleline.sh: every
# tokenizer in an NLP stack is some variation on "decide what a unit is, emit
# one per line". Having all four granularities behind one flag makes the
# choice explicit instead of buried in a one-off pipe.
#
#   ./tokenize.sh --words --lower --count notes.txt | head -20
#   ./tokenize.sh --sentences notes.txt | ./to-jsonl.sh

set -euo pipefail
# shellcheck source=lib/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib/common.sh"

usage() {
    cat <<'USAGE'
Usage: tokenize.sh [OPTIONS] [FILE]

Emit one token per line. Reads FILE, or stdin when FILE is omitted or "-".

Granularity (pick one, default --words):
  --words         runs of alphanumerics          (tr -cs '[:alnum:]')
  --sentences     split after . ! ? + whitespace
  --paragraphs    split on blank lines, one paragraph per line
  --chars         one character per line

Options:
  --lower         case-fold the tokens
  --count         prefix each distinct token with its frequency, descending
  -h, --help      show this help

Notes:
  --words uses `tr -cs`, where -s squeezes repeats so no empty-line cleanup
  pass is needed. --chars drops newline characters themselves.
USAGE
}

granularity=words
lower=0
count=0

while [ $# -gt 0 ]; do
    case "$1" in
        --words) granularity=words; shift ;;
        --sentences) granularity=sentences; shift ;;
        --paragraphs) granularity=paragraphs; shift ;;
        --chars) granularity=chars; shift ;;
        --lower) lower=1; shift ;;
        --count) count=1; shift ;;
        -h | --help) usage; exit 0 ;;
        --) shift; break ;;
        -*) die "unknown option: $1 (try --help)" ;;
        *) break ;;
    esac
done
[ $# -le 1 ] || die 'expected at most one FILE argument'

tp_input "${1:-}"

emit() {
    case "$granularity" in
        words) tp_words "$TP_INPUT" ;;
        sentences) tp_sentences "$TP_INPUT" ;;
        paragraphs)
            # RS="" is awk's paragraph mode; records keep their internal
            # newlines, so flatten each one onto a single output line.
            awk 'BEGIN { RS = "" } { gsub(/\n/, " "); print }' "$TP_INPUT"
            ;;
        chars) grep -o . "$TP_INPUT" || true ;;
        *) die "internal: unknown granularity $granularity" ;;
    esac
}

emit |
    {
        if [ "$lower" -eq 1 ]; then tp_lower; else cat; fi
    } |
    {
        if [ "$count" -eq 1 ]; then
            sort | uniq -c | sort -k1,1nr -k2
        else
            cat
        fi
    }
