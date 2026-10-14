#!/usr/bin/env bash
#
# dedup.sh - remove duplicate lines (records) from a stream.
#
# Deduplicating training and retrieval corpora is one of the highest-value
# preprocessing steps there is: duplicates waste context, skew term
# statistics and teach a model to over-weight whatever was repeated.
#
#   ./dedup.sh records.txt
#   ./dedup.sh --ignore-case --normalize-space --count records.txt

set -euo pipefail
# shellcheck source=lib/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib/common.sh"

usage() {
    cat <<'USAGE'
Usage: dedup.sh [OPTIONS] [FILE]

Keep the first occurrence of each line. Reads FILE, or stdin when FILE is
omitted or "-".

Options:
  --sort              sort the output and dedupe with sort -u (loses order,
                      but needs no memory for the seen-set)
  --ignore-case       treat lines differing only in case as duplicates
  --normalize-space   ignore leading/trailing space and runs of whitespace
                      when comparing (the original line is still printed)
  --count             report kept and removed counts on stderr
  --only-duplicates   print the lines that occur more than once, with counts
  -h, --help          show this help

The default mode is order-preserving: `awk '!seen[$0]++'` keeps the first
copy of each line and holds the distinct keys in memory. For inputs too
large for that, use --sort.
USAGE
}

use_sort=0
ignore_case=0
normalize=0
show_count=0
only_dupes=0

while [ $# -gt 0 ]; do
    case "$1" in
        --sort) use_sort=1; shift ;;
        --ignore-case | -i) ignore_case=1; shift ;;
        --normalize-space) normalize=1; shift ;;
        --count) show_count=1; shift ;;
        --only-duplicates) only_dupes=1; shift ;;
        -h | --help) usage; exit 0 ;;
        --) shift; break ;;
        -*) die "unknown option: $1 (try --help)" ;;
        *) break ;;
    esac
done
[ $# -le 1 ] || die 'expected at most one FILE argument'

tp_input "${1:-}"

total=$(grep -c '' <"$TP_INPUT" || true)

run_dedup() {
    if [ "$only_dupes" -eq 1 ]; then
        awk -v ic="$ignore_case" -v ns="$normalize" '
        {
            key = $0
            if (ns) { gsub(/[[:space:]]+/, " ", key); sub(/^ /, "", key); sub(/ $/, "", key) }
            if (ic) key = tolower(key)
            count[key]++
            if (!(key in first)) first[key] = $0
            order[++n] = key
        }
        END {
            for (i = 1; i <= n; i++) {
                k = order[i]
                if (count[k] > 1 && !(printed[k]++)) printf "%7d %s\n", count[k], first[k]
            }
        }' "$TP_INPUT"
        return
    fi

    if [ "$use_sort" -eq 1 ]; then
        # sort -u compares whole lines, so the comparison options have to be
        # applied by building a key, sorting on it, then dropping it.
        if [ "$ignore_case" -eq 1 ] || [ "$normalize" -eq 1 ]; then
            awk -v ic="$ignore_case" -v ns="$normalize" '
            {
                key = $0
                if (ns) { gsub(/[[:space:]]+/, " ", key); sub(/^ /, "", key); sub(/ $/, "", key) }
                if (ic) key = tolower(key)
                printf "%s\t%s\n", key, $0
            }' "$TP_INPUT" |
                sort -t"$(printf '\t')" -k1,1 -u |
                cut -f2-
        else
            sort -u -- "$TP_INPUT"
        fi
        return
    fi

    awk -v ic="$ignore_case" -v ns="$normalize" '
    {
        key = $0
        if (ns) { gsub(/[[:space:]]+/, " ", key); sub(/^ /, "", key); sub(/ $/, "", key) }
        if (ic) key = tolower(key)
        if (!(seen[key]++)) print
    }' "$TP_INPUT"
}

if [ "$show_count" -eq 1 ]; then
    kept=$(run_dedup | grep -c '' || true)
    printf 'lines in: %d  kept: %d  removed: %d\n' \
        "$total" "$kept" "$((total - kept))" >&2
fi

run_dedup
