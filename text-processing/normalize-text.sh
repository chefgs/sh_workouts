#!/usr/bin/env bash
#
# normalize-text.sh - fold messy real-world text into a canonical form.
#
# Embedding and retrieval quality depends on this step: "don't" and "don’t"
# are two different tokens to a tokenizer, and a word hyphenated across a PDF
# line break ("toke-\nnizer") is two useless ones.
#
#   ./normalize-text.sh extracted.txt
#   pdftotext report.pdf - | ./normalize-text.sh --squeeze-blank

set -euo pipefail
# shellcheck source=lib/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib/common.sh"

usage() {
    cat <<'USAGE'
Usage: normalize-text.sh [OPTIONS] [FILE]

Normalize whitespace, Unicode punctuation and line-broken words. Reads FILE,
or stdin when FILE is omitted or "-".

Options:
  --no-dehyphenate   keep "word-\nbreak" as written instead of joining it
  --no-unicode       keep smart quotes, dashes and ellipses as written
  --squeeze-blank    collapse runs of blank lines into a single blank line
  --lower            case-fold the result as well
  -h, --help         show this help

Steps, in order:
  1. delete control characters except tab and newline
  2. map Unicode punctuation and spaces to ASCII equivalents
  3. join words broken by a hyphen at end of line
  4. strip trailing whitespace, collapse runs of spaces and tabs

Note: step 3 reads the whole input into memory, which is fine for documents
but not for multi-gigabyte corpora. Pass --no-dehyphenate to stream instead.
USAGE
}

dehyphenate=1
unicode=1
squeeze=0
lower=0

while [ $# -gt 0 ]; do
    case "$1" in
        --no-dehyphenate) dehyphenate=0; shift ;;
        --no-unicode) unicode=0; shift ;;
        --squeeze-blank) squeeze=1; shift ;;
        --lower) lower=1; shift ;;
        -h | --help) usage; exit 0 ;;
        --) shift; break ;;
        -*) die "unknown option: $1 (try --help)" ;;
        *) break ;;
    esac
done
[ $# -le 1 ] || die 'expected at most one FILE argument'

tp_input "${1:-}"

# 1. Drop control characters that break downstream tools, keeping \t and \n.
tr -d '\000-\010\013\014\016-\037\177' <"$TP_INPUT" |
    {
        if [ "$unicode" -eq 1 ]; then
            # 2. Smart punctuation and exotic spaces to ASCII. The literal
            # UTF-8 characters are spelled out so the intent stays readable.
            # 2. Smart punctuation and exotic spaces to ASCII.
            #
            # These use alternation (a|b), not bracket expressions [ab]: a
            # bracket expression is matched byte by byte unless the locale is
            # UTF-8, which would split these multi-byte characters and emit
            # one replacement per byte. Alternation matches whole sequences
            # and is therefore locale-independent.
            sed -E \
                -e 's/(“|”|„|‟)/"/g' \
                -e "s/(‘|’|‚|‛)/'/g" \
                -e 's/(–|—|―)/-/g' \
                -e 's/…/.../g' \
                -e 's/( | | | | | )/ /g' \
                -e 's/(​|‌|‍|﻿)//g'
        else
            cat
        fi
    } |
    {
        if [ "$dehyphenate" -eq 1 ]; then
            # 3. Slurp the whole input (:a;N;$!ba) so a hyphen at end of line
            # can be joined with the first word of the next line.
            sed -E ':a;N;$!ba;s/([[:alpha:]])-\n[[:space:]]*([[:alpha:]])/\1\2/g'
        else
            cat
        fi
    } |
    # 4. Trailing whitespace and repeated blanks carry no information.
    sed -E -e 's/[[:space:]]+$//' -e 's/[ \t]+/ /g' |
    {
        if [ "$squeeze" -eq 1 ]; then
            cat -s
        else
            cat
        fi
    } |
    {
        if [ "$lower" -eq 1 ]; then
            tp_lower
        else
            cat
        fi
    }
