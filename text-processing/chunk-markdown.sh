#!/usr/bin/env bash
#
# chunk-markdown.sh - chunk Markdown along its heading structure.
#
# Structure-aware chunking beats blind splitting: a section stays whole, and
# each chunk carries the heading path it came from ("Guide > Setup > Docker"),
# which is exactly the metadata a retrieval answer needs in order to cite
# where it found something.
#
# This reuses the heading detection that ../toc-from-markdown.sh pioneered in
# this repository, and delegates any further size-based splitting to
# chunk-text.sh rather than reimplementing it.
#
#   ./chunk-markdown.sh README.md
#   ./chunk-markdown.sh --level 2 --max-words 150 --format jsonl README.md

set -euo pipefail
# shellcheck source=lib/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib/common.sh"

TP_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    cat <<'USAGE'
Usage: chunk-markdown.sh [OPTIONS] [FILE]

Split Markdown into one chunk per section, labelled with its heading path.
Reads FILE, or stdin when FILE is omitted or "-".

Options:
  --level N       only break at headings of level N or shallower (default 6);
                  deeper headings stay inside their parent's body
  --max-words N   additionally split long sections with chunk-text.sh
  --overlap S     sentence overlap passed to chunk-text.sh (default 1)
  --format FMT    text (default), tsv, or jsonl
  --keep-code     keep fenced code blocks (default: drop them)
  -h, --help      show this help

Formats:
  text   a "=== heading path ===" header followed by the section text
  tsv    PATH <tab> WORDS <tab> TEXT
  jsonl  one JSON object per line (requires jq)

Only ATX headings ("## Title") are recognised, anchored to the start of the
line, so a "#" inside prose or a code comment is not mistaken for a heading.
Content before the first heading is labelled "(no heading)".
USAGE
}

level=6
max_words=0
overlap=1
format=text
keep_code=0

while [ $# -gt 0 ]; do
    case "$1" in
        --level)
            [ $# -ge 2 ] || die 'option --level needs a value'
            tp_require_int "$2" '--level'
            { [ "$2" -ge 1 ] && [ "$2" -le 6 ]; } || die '--level must be between 1 and 6'
            level="$2"
            shift 2
            ;;
        --max-words)
            [ $# -ge 2 ] || die 'option --max-words needs a value'
            tp_require_int "$2" '--max-words'
            [ "$2" -ge 1 ] || die '--max-words must be at least 1'
            max_words="$2"
            shift 2
            ;;
        --overlap)
            [ $# -ge 2 ] || die 'option --overlap needs a value'
            tp_require_int "$2" '--overlap'
            overlap="$2"
            shift 2
            ;;
        --format)
            [ $# -ge 2 ] || die 'option --format needs a value'
            case "$2" in
                text | tsv | jsonl) format="$2" ;;
                *) die "unknown format: $2 (expected text, tsv or jsonl)" ;;
            esac
            shift 2
            ;;
        --keep-code) keep_code=1; shift ;;
        -h | --help) usage; exit 0 ;;
        --) shift; break ;;
        -*) die "unknown option: $1 (try --help)" ;;
        *) break ;;
    esac
done
[ $# -le 1 ] || die 'expected at most one FILE argument'
if [ "$format" = jsonl ]; then
    need_cmd jq
fi

tp_input "${1:-}"
tp_tmpdir

# Split into PATH \t BODY, one section per line.
sections="$TP_TMPDIR/sections.tsv"
awk -v maxlevel="$level" -v keep_code="$keep_code" '
function trim(s) {
    sub(/^[ \t]+/, "", s)
    sub(/[ \t]+$/, "", s)
    return s
}
function flush() {
    gsub(/[ \t]+/, " ", body)
    body = trim(body)
    if (body != "") printf "%s\t%s\n", (path == "" ? "(no heading)" : path), body
    body = ""
}
# Track fenced code so that a "#" comment inside a block is never read as a
# heading -- the bug that makes a bare grep "#" unreliable on real Markdown.
/^[ \t]*```/ {
    infence = !infence
    if (keep_code) body = body " " $0
    next
}
infence {
    if (keep_code) body = body " " $0
    next
}
/^#+[ \t]/ {
    match($0, /^#+/)
    lvl = RLENGTH
    if (lvl <= maxlevel) {
        flush()
        title = trim(substr($0, lvl + 1))
        heads[lvl] = title
        for (k = lvl + 1; k <= 6; k++) heads[k] = ""
        path = ""
        for (k = 1; k <= lvl; k++)
            if (heads[k] != "") path = (path == "" ? heads[k] : path " > " heads[k])
        next
    }
    # Deeper than --level: keep the title as part of the parent body.
    body = body " " trim(substr($0, lvl + 1))
    next
}
{
    gsub(/\t/, " ")
    body = body " " $0
}
END { flush() }
' "$TP_INPUT" >"$sections"

# Optionally split oversized sections, reusing chunk-text.sh for the sentence
# arithmetic instead of duplicating it here.
expanded="$TP_TMPDIR/expanded.tsv"
if [ "$max_words" -gt 0 ]; then
    : >"$expanded"
    body_file="$TP_TMPDIR/body"
    while IFS=$'\t' read -r path body; do
        printf '%s\n' "$body" >"$body_file"
        "$TP_DIR/chunk-text.sh" --max-words "$max_words" --overlap "$overlap" \
            --format tsv "$body_file" |
            awk -F'\t' -v path="$path" '{ printf "%s\t%s\t%s\n", path, $2, $4 }' \
                >>"$expanded"
    done <"$sections"
else
    awk -F'\t' '{ n = split($2, w, /[ ]+/); printf "%s\t%d\t%s\n", $1, n, $2 }' \
        "$sections" >"$expanded"
fi

case "$format" in
    tsv) cat -- "$expanded" ;;
    jsonl)
        jq -R -c 'split("\t") | {
            heading: .[0],
            words: (.[1] | tonumber),
            text: .[2]
        }' <"$expanded"
        ;;
    text)
        awk -F'\t' '{ printf "=== %s (words=%s) ===\n%s\n\n", $1, $2, $3 }' "$expanded"
        ;;
    *) die "internal: unknown format $format" ;;
esac
