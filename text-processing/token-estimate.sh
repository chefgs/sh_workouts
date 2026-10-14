#!/usr/bin/env bash
#
# token-estimate.sh - approximate LLM token counts, cost and context budget.
#
# Uses the chars/4 rule of thumb. That is an APPROXIMATION: real byte-pair
# encoders vary by 20% or more on source code, JSON and non-English text, and
# every provider tokenizes differently. Use it for sizing and for CI guards,
# never for billing reconciliation or for a hard context-window limit where
# being wrong by 20% matters.
#
#   ./token-estimate.sh corpus/*.txt
#   ./token-estimate.sh --budget 8000 prompt.txt || echo "too big for the window"
#   ./token-estimate.sh --price-per-mtok 3.00 --json corpus/*.txt

set -euo pipefail
# shellcheck source=lib/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib/common.sh"

CHARS_PER_TOKEN=4

usage() {
    cat <<'USAGE'
Usage: token-estimate.sh [OPTIONS] [FILE...]

Estimate tokens as characters / 4. Reads the named FILEs, or stdin when none
are given.

Options:
  --budget N            exit 1 if the total estimate exceeds N tokens
  --price-per-mtok P    also estimate cost at P units per million tokens
  --chars-per-token N   override the divisor (default 4)
  --json                emit JSON instead of a table
  -h, --help            show this help

Exit status: 0 ok, 1 over budget, 2 usage or runtime error.

The chars/4 heuristic is approximate; see the comment block in this script.
USAGE
}

budget=''
price=''
json=0

while [ $# -gt 0 ]; do
    case "$1" in
        --budget)
            [ $# -ge 2 ] || die 'option --budget needs a value'
            tp_require_int "$2" '--budget'
            budget="$2"
            shift 2
            ;;
        --price-per-mtok)
            [ $# -ge 2 ] || die 'option --price-per-mtok needs a value'
            case "$2" in
                '' | *[!0-9.]*) die "--price-per-mtok must be a number, got: $2" ;;
            esac
            price="$2"
            shift 2
            ;;
        --chars-per-token)
            [ $# -ge 2 ] || die 'option --chars-per-token needs a value'
            tp_require_int "$2" '--chars-per-token'
            [ "$2" -gt 0 ] || die '--chars-per-token must be greater than zero'
            CHARS_PER_TOKEN="$2"
            shift 2
            ;;
        --json) json=1; shift ;;
        -h | --help) usage; exit 0 ;;
        --) shift; break ;;
        -*) die "unknown option: $1 (try --help)" ;;
        *) break ;;
    esac
done

# Build the file list, spooling stdin when nothing was named.
files=()
if [ $# -eq 0 ]; then
    tp_input '-'
    files=("$TP_INPUT")
    labels=('(stdin)')
else
    labels=()
    for f in "$@"; do
        tp_input "$f"
        files+=("$TP_INPUT")
        labels+=("$f")
    done
fi

# wc gives lines/words/chars in one pass; awk turns that into the estimate.
rows="$(
    for i in "${!files[@]}"; do
        read -r lines words chars _ < <(wc -lwc <"${files[$i]}")
        printf '%s\t%s\t%s\t%s\n' "${labels[$i]}" "$lines" "$words" "$chars"
    done
)"

printf '%s\n' "$rows" | awk -F'\t' \
    -v cpt="$CHARS_PER_TOKEN" -v price="$price" -v json="$json" '
# Escape a value for inclusion in a JSON string. A filename may legally
# contain a quote or a backslash, and emitting one raw would produce invalid
# JSON -- the same failure mode that makes hand-rolled JSON unsafe in general.
function jesc(s) {
    gsub(/\\/, "\\\\", s)
    gsub(/"/, "\\\"", s)
    return s
}
{
    name[NR] = $1; l[NR] = $2; w[NR] = $3; c[NR] = $4
    tl += $2; tw += $3; tc += $4
}
END {
    if (NR == 0) exit
    if (json) {
        printf "{\n  \"chars_per_token\": %d,\n  \"files\": [\n", cpt
        for (i = 1; i <= NR; i++) {
            printf "    {\"file\": \"%s\", \"lines\": %d, \"words\": %d, \"chars\": %d, \"est_tokens\": %d",
                jesc(name[i]), l[i], w[i], c[i], int(c[i] / cpt)
            if (price != "") printf ", \"est_cost\": %.6f", int(c[i] / cpt) / 1000000 * price
            printf "}%s\n", (i < NR ? "," : "")
        }
        printf "  ],\n  \"total\": {\"lines\": %d, \"words\": %d, \"chars\": %d, \"est_tokens\": %d",
            tl, tw, tc, int(tc / cpt)
        if (price != "") printf ", \"est_cost\": %.6f", int(tc / cpt) / 1000000 * price
        printf "}\n}\n"
    } else {
        fmt = "%-30s %8s %8s %9s %11s"
        printf fmt, "FILE", "LINES", "WORDS", "CHARS", "EST_TOKENS"
        if (price != "") printf " %11s", "EST_COST"
        printf "\n"
        fmt = "%-30s %8d %8d %9d %11d"
        for (i = 1; i <= NR; i++) {
            printf fmt, name[i], l[i], w[i], c[i], int(c[i] / cpt)
            if (price != "") printf " %11.6f", int(c[i] / cpt) / 1000000 * price
            printf "\n"
        }
        if (NR > 1) {
            printf fmt, "TOTAL", tl, tw, tc, int(tc / cpt)
            if (price != "") printf " %11.6f", int(tc / cpt) / 1000000 * price
            printf "\n"
        }
    }
}'

if [ -n "$budget" ]; then
    total_chars="$(printf '%s\n' "$rows" | awk -F'\t' '{ s += $4 } END { print s + 0 }')"
    total_tokens=$((total_chars / CHARS_PER_TOKEN))
    if [ "$total_tokens" -gt "$budget" ]; then
        printf 'over budget: %d est_tokens > %d\n' "$total_tokens" "$budget" >&2
        exit 1
    fi
    printf 'within budget: %d est_tokens <= %d\n' "$total_tokens" "$budget" >&2
fi
