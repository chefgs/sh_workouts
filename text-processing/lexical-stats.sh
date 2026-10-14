#!/usr/bin/env bash
#
# lexical-stats.sh - vocabulary statistics for a document.
#
# The type/token ratio and the hapax share are cheap, useful signals. A low
# TTR on generated text means the model is looping; a very high hapax share
# on scraped text usually means tokenization is broken (every URL counted as
# a fresh word).
#
#   ./lexical-stats.sh notes.txt
#   ./lexical-stats.sh --json notes.txt | jq .ttr

set -euo pipefail
# shellcheck source=lib/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib/common.sh"

usage() {
    cat <<'USAGE'
Usage: lexical-stats.sh [OPTIONS] [FILE]

Report vocabulary statistics. Reads FILE, or stdin when FILE is omitted
or "-".

Options:
  --keep-case   count "The" and "the" as different types
  --json        emit JSON instead of a table
  -h, --help    show this help

Reported:
  tokens            total word occurrences
  types             distinct words
  ttr               types / tokens (lexical diversity, 0..1)
  hapax             words occurring exactly once
  hapax_pct         hapax / types
  avg_word_len      mean characters per token
  sentences         count of . ! ? terminated segments
  avg_sentence_len  mean tokens per sentence
USAGE
}

keep_case=0
json=0

while [ $# -gt 0 ]; do
    case "$1" in
        --keep-case) keep_case=1; shift ;;
        --json) json=1; shift ;;
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

sentences=$(tp_sentences "$TP_INPUT" | grep -c '' || true)

sort -- "$tokens" | uniq -c |
    awk -v sentences="$sentences" -v json="$json" '
{
    types++
    tokens += $1
    chars += length($2) * $1
    if ($1 == 1) hapax++
}
END {
    if (tokens == 0) {
        print "no tokens found" > "/dev/stderr"
        exit 2
    }
    ttr = types / tokens
    hpct = (types ? hapax / types : 0)
    awl = chars / tokens
    asl = (sentences ? tokens / sentences : 0)
    if (json) {
        printf "{\n"
        printf "  \"tokens\": %d,\n", tokens
        printf "  \"types\": %d,\n", types
        printf "  \"ttr\": %.4f,\n", ttr
        printf "  \"hapax\": %d,\n", hapax
        printf "  \"hapax_pct\": %.4f,\n", hpct
        printf "  \"avg_word_len\": %.2f,\n", awl
        printf "  \"sentences\": %d,\n", sentences
        printf "  \"avg_sentence_len\": %.2f\n", asl
        printf "}\n"
    } else {
        printf "%-18s %10d\n", "tokens", tokens
        printf "%-18s %10d\n", "types", types
        printf "%-18s %10.4f\n", "ttr", ttr
        printf "%-18s %10d\n", "hapax", hapax
        printf "%-18s %10.4f\n", "hapax_pct", hpct
        printf "%-18s %10.2f\n", "avg_word_len", awl
        printf "%-18s %10d\n", "sentences", sentences
        printf "%-18s %10.2f\n", "avg_sentence_len", asl
    }
}'
