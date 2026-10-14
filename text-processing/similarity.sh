#!/usr/bin/env bash
#
# similarity.sh - set-based similarity between two documents.
#
# Jaccard similarity over word sets is what a vector database approximates
# with embeddings, computed here with `comm` and arithmetic. Shingle mode
# (--shingles) compares overlapping word n-grams instead of bare words, which
# is the basis of near-duplicate detection: it is sensitive to word order,
# so two documents built from the same vocabulary in a different order score
# low rather than identical.
#
#   ./similarity.sh a.txt b.txt
#   ./similarity.sh --shingles 5 --json a.txt b.txt

set -euo pipefail
# shellcheck source=lib/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib/common.sh"

usage() {
    cat <<'USAGE'
Usage: similarity.sh [OPTIONS] FILE1 FILE2

Compare two documents as sets of terms.

Options:
  --shingles N   compare overlapping N-word shingles instead of single words
  --keep-case    do not case-fold
  --json         emit JSON instead of a table
  -h, --help     show this help

Reported:
  a_only / b_only   terms unique to each document
  shared            terms present in both
  union             distinct terms across both
  jaccard           shared / union          (0 = disjoint, 1 = identical sets)
  containment       shared / min(|A|, |B|)  (1 = one side is a subset)

Containment catches the case Jaccard understates: a short document fully
contained in a much longer one scores low on Jaccard but 1.00 here.
USAGE
}

shingles=0
keep_case=0
json=0

while [ $# -gt 0 ]; do
    case "$1" in
        --shingles)
            [ $# -ge 2 ] || die 'option --shingles needs a value'
            tp_require_int "$2" '--shingles'
            [ "$2" -ge 1 ] || die '--shingles must be at least 1'
            shingles="$2"
            shift 2
            ;;
        --keep-case) keep_case=1; shift ;;
        --json) json=1; shift ;;
        -h | --help) usage; exit 0 ;;
        --) shift; break ;;
        -*) die "unknown option: $1 (try --help)" ;;
        *) break ;;
    esac
done
[ $# -eq 2 ] || die 'exactly two FILE arguments are required (try --help)'

tp_tmpdir

# Build a sorted, unique term set per document.
build_set() {
    local src="$1" out="$2"
    tp_input "$src"
    local tokens="$TP_TMPDIR/tok.$$"
    {
        tp_words "$TP_INPUT" |
            if [ "$keep_case" -eq 1 ]; then cat; else tp_lower; fi
    } >"$tokens"

    if [ "$shingles" -gt 1 ]; then
        local shifted=() k
        for ((k = 1; k <= shingles; k++)); do
            tail -n "+$k" -- "$tokens" >"$TP_TMPDIR/sh.$k"
            shifted+=("$TP_TMPDIR/sh.$k")
        done
        paste -d' ' "${shifted[@]}" | awk -v n="$shingles" 'NF == n' |
            sort -u >"$out"
    else
        sort -u -- "$tokens" >"$out"
    fi
    rm -f -- "$tokens"
}

set_a="$TP_TMPDIR/a.set"
set_b="$TP_TMPDIR/b.set"
build_set "$1" "$set_a"
build_set "$2" "$set_b"

a_only=$(comm -23 "$set_a" "$set_b" | grep -c '' || true)
b_only=$(comm -13 "$set_a" "$set_b" | grep -c '' || true)
shared=$(comm -12 "$set_a" "$set_b" | grep -c '' || true)

awk -v a_only="$a_only" -v b_only="$b_only" -v shared="$shared" \
    -v fa="$1" -v fb="$2" -v json="$json" -v n="$shingles" '
function jesc(s) { gsub(/\\/, "\\\\", s); gsub(/"/, "\\\"", s); return s }
BEGIN {
    size_a = a_only + shared
    size_b = b_only + shared
    union = a_only + b_only + shared
    jaccard = (union ? shared / union : 0)
    smaller = (size_a < size_b ? size_a : size_b)
    containment = (smaller ? shared / smaller : 0)
    if (json) {
        printf "{\n"
        printf "  \"a\": \"%s\",\n  \"b\": \"%s\",\n", jesc(fa), jesc(fb)
        printf "  \"unit\": \"%s\",\n", (n > 1 ? n "-word shingles" : "words")
        printf "  \"a_terms\": %d,\n  \"b_terms\": %d,\n", size_a, size_b
        printf "  \"a_only\": %d,\n  \"b_only\": %d,\n  \"shared\": %d,\n", a_only, b_only, shared
        printf "  \"union\": %d,\n", union
        printf "  \"jaccard\": %.4f,\n  \"containment\": %.4f\n", jaccard, containment
        printf "}\n"
    } else {
        printf "%-14s %s\n", "unit", (n > 1 ? n "-word shingles" : "words")
        printf "%-14s %8d\n", "a_terms", size_a
        printf "%-14s %8d\n", "b_terms", size_b
        printf "%-14s %8d\n", "a_only", a_only
        printf "%-14s %8d\n", "b_only", b_only
        printf "%-14s %8d\n", "shared", shared
        printf "%-14s %8d\n", "union", union
        printf "%-14s %8.4f\n", "jaccard", jaccard
        printf "%-14s %8.4f\n", "containment", containment
    }
}'
