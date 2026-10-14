#!/usr/bin/env bash
#
# vocab-diff.sh - which terms appeared or disappeared between two documents.
#
# Useful for drift checks: run it over last week's and this week's corpus to
# see what is new, or over two model outputs to see which concepts one
# introduced that the other did not.
#
#   ./vocab-diff.sh v1.txt v2.txt
#   ./vocab-diff.sh --added v1.txt v2.txt | ./stopwords.sh

set -euo pipefail
# shellcheck source=lib/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib/common.sh"

usage() {
    cat <<'USAGE'
Usage: vocab-diff.sh [OPTIONS] OLD NEW

Compare the vocabularies of two documents using comm(1).

Options:
  --added      print only terms present in NEW but not OLD
  --removed    print only terms present in OLD but not NEW
  --common     print only terms present in both
  --summary    print counts only
  --keep-case  do not case-fold
  -h, --help   show this help

With no selection option, output is marked: "+ term" added, "- term" removed.
USAGE
}

mode=marked
keep_case=0

while [ $# -gt 0 ]; do
    case "$1" in
        --added) mode=added; shift ;;
        --removed) mode=removed; shift ;;
        --common) mode=common; shift ;;
        --summary) mode=summary; shift ;;
        --keep-case) keep_case=1; shift ;;
        -h | --help) usage; exit 0 ;;
        --) shift; break ;;
        -*) die "unknown option: $1 (try --help)" ;;
        *) break ;;
    esac
done
[ $# -eq 2 ] || die 'exactly two arguments are required: OLD NEW (try --help)'

tp_tmpdir

build_set() {
    tp_input "$1"
    {
        tp_words "$TP_INPUT" |
            if [ "$keep_case" -eq 1 ]; then cat; else tp_lower; fi
    } | sort -u >"$2"
}

old_set="$TP_TMPDIR/old.set"
new_set="$TP_TMPDIR/new.set"
build_set "$1" "$old_set"
build_set "$2" "$new_set"

case "$mode" in
    added) comm -13 "$old_set" "$new_set" ;;
    removed) comm -23 "$old_set" "$new_set" ;;
    common) comm -12 "$old_set" "$new_set" ;;
    summary)
        printf '%-10s %6d\n' \
            'old' "$(grep -c '' <"$old_set" || true)" \
            'new' "$(grep -c '' <"$new_set" || true)" \
            'added' "$(comm -13 "$old_set" "$new_set" | grep -c '' || true)" \
            'removed' "$(comm -23 "$old_set" "$new_set" | grep -c '' || true)" \
            'common' "$(comm -12 "$old_set" "$new_set" | grep -c '' || true)"
        ;;
    marked)
        {
            comm -13 "$old_set" "$new_set" | sed 's/^/+ /'
            comm -23 "$old_set" "$new_set" | sed 's/^/- /'
        } | sort -k2
        ;;
    *) die "internal: unknown mode $mode" ;;
esac
