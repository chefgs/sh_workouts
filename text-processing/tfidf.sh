#!/usr/bin/env bash
#
# tfidf.sh - document frequency, inverse document frequency and tf-idf.
#
# This is retrieval scoring, which is what a vector database replaces rather
# than invents. idf = log(N/df) says how much a term narrows the corpus; a
# term in every document carries no signal and scores zero.
#
#   ./tfidf.sh corpus/*.txt
#   ./tfidf.sh --per-doc --top 5 corpus/*.txt
#   ./tfidf.sh --dir corpus --stopwords

set -euo pipefail
# shellcheck source=lib/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib/common.sh"

TP_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    cat <<'USAGE'
Usage: tfidf.sh [OPTIONS] FILE...
       tfidf.sh [OPTIONS] --dir DIRECTORY

Compute corpus term statistics over two or more documents.

Options:
  --dir DIR       use every regular file directly inside DIR as a document
  --per-doc       report the top tf-idf terms for each document
  --top K         limit to K rows (per document with --per-doc)
  --stopwords     drop stopwords before counting
  --list FILE     stopword list to use with --stopwords
  --keep-case     do not case-fold the tokens
  -h, --help      show this help

Default output:  TERM  DF  IDF        (highest idf first: the rarest terms)
--per-doc output: DOC  TERM  TF  TFIDF

idf uses natural log, so a term present in every document has idf 0.
USAGE
}

per_doc=0
top=0
use_stopwords=0
list="$TP_DIR/data/stopwords-en.txt"
keep_case=0
dir=''

while [ $# -gt 0 ]; do
    case "$1" in
        --dir)
            [ $# -ge 2 ] || die 'option --dir needs a value'
            dir="$2"
            shift 2
            ;;
        --per-doc) per_doc=1; shift ;;
        --top)
            [ $# -ge 2 ] || die 'option --top needs a value'
            tp_require_int "$2" '--top'
            top="$2"
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

docs=()
if [ -n "$dir" ]; then
    [ $# -eq 0 ] || die 'pass either --dir or a list of files, not both'
    [ -d "$dir" ] || die "not a directory: $dir"
    # A glob that matches nothing stays literal, so test each candidate.
    for f in "$dir"/*; do
        if [ -f "$f" ]; then
            docs+=("$f")
        fi
    done
else
    docs=("$@")
fi

if [ ${#docs[@]} -lt 2 ]; then
    die 'need at least two documents for document frequency to mean anything'
fi
if [ "$use_stopwords" -eq 1 ]; then
    [ -r "$list" ] || die "stopword list not readable: $list"
fi

tp_tmpdir
postings="$TP_TMPDIR/postings.tsv"
: >"$postings"

# One "DOC<TAB>TERM" line per occurrence: term frequency comes from counting
# the lines, document frequency from counting the distinct documents.
for doc in "${docs[@]}"; do
    tp_input "$doc"
    {
        tp_words "$TP_INPUT" |
            if [ "$keep_case" -eq 1 ]; then cat; else tp_lower; fi
    } |
        {
            if [ "$use_stopwords" -eq 1 ]; then
                grep -v -x -F -f "$list" || true
            else
                cat
            fi
        } |
        awk -v d="$doc" '{ print d "\t" $0 }' >>"$postings"
done

n_docs=${#docs[@]}

awk -F'\t' -v n="$n_docs" -v per_doc="$per_doc" -v top="$top" '
{
    tf[$1 SUBSEP $2]++
    if (!(seen[$1 SUBSEP $2]++)) df[$2]++
}
END {
    if (per_doc) {
        for (key in tf) {
            split(key, parts, SUBSEP)
            doc = parts[1]; term = parts[2]
            printf "%s\t%s\t%d\t%.4f\n", doc, term, tf[key], tf[key] * log(n / df[term])
        }
    } else {
        for (term in df) {
            printf "%s\t%d\t%.4f\n", term, df[term], log(n / df[term])
        }
    }
}' "$postings" |
    if [ "$per_doc" -eq 1 ]; then
        # Group by document, then take the strongest terms within each group.
        sort -t"$(printf '\t')" -k1,1 -k4,4nr -k2,2 |
            awk -F'\t' -v top="$top" '
                $1 != last { last = $1; rank = 0 }
                { rank++ }
                top == 0 || rank <= top {
                    printf "%-24s %-18s %4d %9.4f\n", $1, $2, $3, $4
                }'
    else
        sort -t"$(printf '\t')" -k3,3nr -k1,1 |
            awk -F'\t' -v top="$top" '
                top == 0 || NR <= top { printf "%-24s %4d %9.4f\n", $1, $2, $3 }'
    fi
