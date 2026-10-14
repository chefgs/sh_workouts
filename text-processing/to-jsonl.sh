#!/usr/bin/env bash
#
# to-jsonl.sh - turn plain text into JSONL records.
#
# JSONL is the interchange format for fine-tuning sets, eval suites and
# embedding jobs. The escaping is delegated to `jq -R`, which is the whole
# point of this script: hand-built JSON breaks the moment the text contains a
# quote, a backslash, a tab or a control character, and that breakage is
# silent until something downstream rejects the file.
#
#   ./to-jsonl.sh --mode sentences notes.txt > records.jsonl
#   ./chunk-text.sh --format tsv notes.txt | cut -f4 | ./to-jsonl.sh --id

set -euo pipefail
# shellcheck source=lib/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib/common.sh"

usage() {
    cat <<'USAGE'
Usage: to-jsonl.sh [OPTIONS] [FILE]

Emit one JSON object per record. Reads FILE, or stdin when FILE is omitted
or "-".

Options:
  --mode MODE    lines (default), sentences, or paragraphs
  --field NAME   name of the text field (default "text")
  --id           add a 1-based "id" field
  --tokens       add an "est_tokens" field (characters / 4, approximate)
  --source       add a "source" field holding the input filename
  -h, --help     show this help

Requires jq. Empty records are skipped.
USAGE
}

mode=lines
field=text
add_id=0
add_tokens=0
add_source=0

while [ $# -gt 0 ]; do
    case "$1" in
        --mode)
            [ $# -ge 2 ] || die 'option --mode needs a value'
            case "$2" in
                lines | sentences | paragraphs) mode="$2" ;;
                *) die "unknown mode: $2 (expected lines, sentences or paragraphs)" ;;
            esac
            shift 2
            ;;
        --field)
            [ $# -ge 2 ] || die 'option --field needs a value'
            case "$2" in
                '' | *[!A-Za-z0-9_]*) die "--field must be alphanumeric/underscore, got: $2" ;;
            esac
            field="$2"
            shift 2
            ;;
        --id) add_id=1; shift ;;
        --tokens) add_tokens=1; shift ;;
        --source) add_source=1; shift ;;
        -h | --help) usage; exit 0 ;;
        --) shift; break ;;
        -*) die "unknown option: $1 (try --help)" ;;
        *) break ;;
    esac
done
[ $# -le 1 ] || die 'expected at most one FILE argument'
need_cmd jq

source_name="${1:-(stdin)}"
tp_input "${1:-}"

emit() {
    case "$mode" in
        lines) cat -- "$TP_INPUT" ;;
        sentences) tp_sentences "$TP_INPUT" ;;
        paragraphs) awk 'BEGIN { RS = "" } { gsub(/\n/, " "); print }' "$TP_INPUT" ;;
        *) die "internal: unknown mode $mode" ;;
    esac
}

# jq -R reads each line as a raw string and does the escaping; --arg passes
# the field name and source as data, so neither can inject structure.
emit |
    grep -v '^[[:space:]]*$' |
    jq -R -c \
        --arg field "$field" \
        --arg source "$source_name" \
        --argjson add_id "$add_id" \
        --argjson add_tokens "$add_tokens" \
        --argjson add_source "$add_source" '
        . as $text
        | {($field): $text}
        | (if $add_id == 1 then {id: input_line_number} + . else . end)
        | (if $add_tokens == 1 then . + {est_tokens: (($text | length) / 4 | floor)} else . end)
        | (if $add_source == 1 then . + {source: $source} else . end)
    ' || true
