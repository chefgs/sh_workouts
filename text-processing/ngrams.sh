#!/usr/bin/env bash
#
# ngrams.sh - count contiguous word n-grams.
#
# The implementation is the `paste` shift trick: paste the token stream
# against copies of itself offset by one line, and column k of the output
# holds the k-th word of each n-gram. This is collocation extraction, the
# same signal that drives phrase detection and byte-pair merge tables.
#
#   ./ngrams.sh -n 2 --top 20 notes.txt
#   ./ngrams.sh -n 3 --stopwords notes.txt

set -euo pipefail
# shellcheck source=lib/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib/common.sh"

TP_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    cat <<'USAGE'
Usage: ngrams.sh [OPTIONS] [FILE]

Count word n-grams in raw text. Reads FILE, or stdin when FILE is omitted
or "-".

Options:
  -n N            n-gram size (default 2; 1 gives a plain word frequency)
  --top K         show only the K most frequent n-grams
  --stopwords     drop stopwords before building n-grams
  --list FILE     stopword list to use with --stopwords
  --keep-case     do not case-fold the tokens
  --min-count C   show only n-grams occurring at least C times
  -h, --help      show this help

Output is "COUNT n-gram", most frequent first, ties broken alphabetically.
USAGE
}

n=2
top=0
use_stopwords=0
list="$TP_DIR/data/stopwords-en.txt"
keep_case=0
min_count=1

while [ $# -gt 0 ]; do
    case "$1" in
        -n)
            [ $# -ge 2 ] || die 'option -n needs a value'
            tp_require_int "$2" '-n'
            [ "$2" -ge 1 ] || die '-n must be at least 1'
            n="$2"
            shift 2
            ;;
        --top)
            [ $# -ge 2 ] || die 'option --top needs a value'
            tp_require_int "$2" '--top'
            top="$2"
            shift 2
            ;;
        --min-count)
            [ $# -ge 2 ] || die 'option --min-count needs a value'
            tp_require_int "$2" '--min-count'
            min_count="$2"
            shift 2
            ;;
        --stopwords) use_stopwords=1; shift ;;
        --list)
            [ $# -ge 2 ] || die 'option --list needs a value'
            list="$2"
            shift 2
            ;;
        --keep-case) keep_case=1; shift ;;
        -h | --help) usage; exit 0 ;;
        --) shift; break ;;
        -*) die "unknown option: $1 (try --help)" ;;
        *) break ;;
    esac
done
[ $# -le 1 ] || die 'expected at most one FILE argument'

tp_input "${1:-}"
tp_tmpdir
tokens="$TP_TMPDIR/tokens"

{
    tp_words "$TP_INPUT" |
        if [ "$keep_case" -eq 1 ]; then cat; else tp_lower; fi
} >"$tokens"

if [ "$use_stopwords" -eq 1 ]; then
    [ -r "$list" ] || die "stopword list not readable: $list"
    grep -v -x -F -f "$list" -- "$tokens" >"$tokens.filtered" || true
    mv -- "$tokens.filtered" "$tokens"
fi

# One process substitution per n-gram position, each skipping one more line
# than the last. paste joins them column-wise into candidate n-grams.
shifted=()
for ((k = 1; k <= n; k++)); do
    shifted+=("$TP_TMPDIR/shift.$k")
    tail -n "+$k" -- "$tokens" >"$TP_TMPDIR/shift.$k"
done

# The last n-1 rows are incomplete n-grams, so require exactly n fields.
paste -d' ' "${shifted[@]}" |
    awk -v n="$n" 'NF == n' |
    sort |
    uniq -c |
    awk -v min="$min_count" '$1 >= min' |
    sort -k1,1nr -k2 |
    awk -v top="$top" 'top == 0 || NR <= top'
