#!/usr/bin/env bash
#
# kwic.sh - keyword in context (a concordance).
#
# Show every occurrence of a term with the words around it. This is the
# lexical ancestor of semantic search, and the quickest way to see why
# keyword matching is not enough: it finds "bank" in both senses and cannot
# tell them apart.
#
#   ./kwic.sh data notes.txt
#   ./kwic.sh --window 8 --ignore-case 'machine' notes.txt
#   ./kwic.sh --regex 'colou?r' notes.txt

set -euo pipefail
# shellcheck source=lib/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib/common.sh"

usage() {
    cat <<'USAGE'
Usage: kwic.sh [OPTIONS] PATTERN [FILE]

Print each occurrence of PATTERN with surrounding words. Reads FILE, or stdin
when FILE is omitted or "-".

Options:
  --window N      words of context on each side (default 5)
  --ignore-case   match case-insensitively
  --regex         treat PATTERN as an extended regex (default: literal text)
  --slurp         join all lines first, so context can cross line breaks
  --max N         stop after N matches
  -h, --help      show this help

By default context does not cross line breaks, and each hit is prefixed with
its line number. With --slurp the whole input becomes one line, giving better
context for hard-wrapped prose but no line numbers.
USAGE
}

window=5
ignore_case=0
is_regex=0
slurp=0
max=0

while [ $# -gt 0 ]; do
    case "$1" in
        --window)
            [ $# -ge 2 ] || die 'option --window needs a value'
            tp_require_int "$2" '--window'
            window="$2"
            shift 2
            ;;
        --max)
            [ $# -ge 2 ] || die 'option --max needs a value'
            tp_require_int "$2" '--max'
            max="$2"
            shift 2
            ;;
        --ignore-case | -i) ignore_case=1; shift ;;
        --regex) is_regex=1; shift ;;
        --slurp) slurp=1; shift ;;
        -h | --help) usage; exit 0 ;;
        --) shift; break ;;
        -*) die "unknown option: $1 (try --help)" ;;
        *) break ;;
    esac
done

[ $# -ge 1 ] || die 'a PATTERN argument is required (try --help)'
pattern="$1"
shift
[ $# -le 1 ] || die 'expected at most one FILE argument'
[ -n "$pattern" ] || die 'PATTERN must not be empty'

tp_input "${1:-}"

# A literal pattern must have its regex metacharacters escaped, or a search
# for "a.b" would also match "axb".
# SC2016: the backslashes below are literal sed syntax, not expansions.
# shellcheck disable=SC2016
if [ "$is_regex" -eq 0 ]; then
    pattern="$(printf '%s' "$pattern" | sed 's/[][\.*^$(){}?+|\\\/]/\\&/g')"
fi

grep_args=(-o -E)
if [ "$ignore_case" -eq 1 ]; then
    grep_args+=(-i)
fi
if [ "$slurp" -eq 0 ]; then
    grep_args+=(-n)
fi

# ([^ ]+ ){0,N} is N words of left context, ( [^ ]+){0,N} the right.
context="([^ ]+ ){0,$window}(${pattern})( [^ ]+){0,$window}"

{
    if [ "$slurp" -eq 1 ]; then
        tr '\n' ' ' <"$TP_INPUT"
        printf '\n'
    else
        cat -- "$TP_INPUT"
    fi
} |
    sed -E 's/[[:space:]]+/ /g' |
    grep "${grep_args[@]}" -- "$context" |
    awk -v max="$max" 'max == 0 || NR <= max' || true
