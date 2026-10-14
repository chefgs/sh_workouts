#!/usr/bin/env bash
#
# zipf.sh - check a corpus against Zipf's law.
#
# In natural language the n-th most common word appears about 1/n as often as
# the most common one. Real prose tracks that closely. A corpus that does not
# is usually a sign of a problem: boilerplate repeated thousands of times,
# a broken tokenizer, or machine-generated filler.
#
#   ./zipf.sh --top 15 notes.txt

set -euo pipefail
# shellcheck source=lib/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib/common.sh"

usage() {
    cat <<'USAGE'
Usage: zipf.sh [OPTIONS] [FILE]

Compare observed word frequencies with the Zipf prediction. Reads FILE, or
stdin when FILE is omitted or "-".

Options:
  --top N       show the N most frequent words (default 20)
  --keep-case   do not case-fold the tokens
  -h, --help    show this help

Columns:
  RANK      frequency rank, 1 = most common
  WORD      the token
  COUNT     observed occurrences
  EXPECTED  count of the top word divided by RANK
  RATIO     COUNT / EXPECTED; close to 1.00 means Zipf-like
USAGE
}

top=20
keep_case=0

while [ $# -gt 0 ]; do
    case "$1" in
        --top)
            [ $# -ge 2 ] || die 'option --top needs a value'
            tp_require_int "$2" '--top'
            [ "$2" -ge 1 ] || die '--top must be at least 1'
            top="$2"
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

{
    tp_words "$TP_INPUT" |
        if [ "$keep_case" -eq 1 ]; then cat; else tp_lower; fi
} |
    sort | uniq -c | sort -k1,1nr -k2 |
    awk -v top="$top" '
    NR == 1 { f1 = $1; printf "%4s %-20s %8s %9s %7s\n", "RANK", "WORD", "COUNT", "EXPECTED", "RATIO" }
    NR <= top {
        expected = f1 / NR
        printf "%4d %-20s %8d %9.1f %7.2f\n", NR, $2, $1, expected, $1 / expected
    }'
