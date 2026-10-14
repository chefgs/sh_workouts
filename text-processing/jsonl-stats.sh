#!/usr/bin/env bash
#
# jsonl-stats.sh - size and validity report for a JSONL dataset.
#
# Run this before paying to embed or fine-tune on a file. It catches the two
# problems that matter: records that are not valid JSON, and a length
# distribution whose tail will be silently truncated by a context window.
#
#   ./jsonl-stats.sh records.jsonl
#   ./jsonl-stats.sh --field prompt --json records.jsonl

set -euo pipefail
# shellcheck source=lib/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib/common.sh"

usage() {
    cat <<'USAGE'
Usage: jsonl-stats.sh [OPTIONS] [FILE]

Summarise a JSONL file. Reads FILE, or stdin when FILE is omitted or "-".

Options:
  --field NAME   text field to measure (default "text")
  --json         emit JSON instead of a table
  --strict       exit 1 if any line is invalid JSON or missing the field
  -h, --help     show this help

Reported: record count, invalid lines, missing-field count, and the
characters and estimated tokens (characters / 4) as total, min, max and mean.

Requires jq.
USAGE
}

field=text
json=0
strict=0

while [ $# -gt 0 ]; do
    case "$1" in
        --field)
            [ $# -ge 2 ] || die 'option --field needs a value'
            field="$2"
            shift 2
            ;;
        --json) json=1; shift ;;
        --strict) strict=1; shift ;;
        -h | --help) usage; exit 0 ;;
        --) shift; break ;;
        -*) die "unknown option: $1 (try --help)" ;;
        *) break ;;
    esac
done
[ $# -le 1 ] || die 'expected at most one FILE argument'
need_cmd jq

tp_input "${1:-}"

# Read every line raw and attempt fromjson, so one malformed record is
# counted rather than aborting the whole run.
report="$(
    jq -R -s --arg field "$field" '
        split("\n")
        | map(select(length > 0))
        | map(. as $line | try (fromjson) catch "__INVALID__")
        | {
            records: length,
            invalid: map(select(. == "__INVALID__")) | length,
            missing: map(select(type == "object" and (has($field) | not))) | length,
            lengths: (
                map(select(type == "object" and has($field)) | .[$field] | tostring | length)
            )
          }
        | . + (
            if (.lengths | length) > 0 then {
                chars_total: (.lengths | add),
                chars_min: (.lengths | min),
                chars_max: (.lengths | max),
                chars_mean: ((.lengths | add) / (.lengths | length) * 100 | round / 100)
            } else {
                chars_total: 0, chars_min: 0, chars_max: 0, chars_mean: 0
            } end
          )
        | . + {
            est_tokens_total: (.chars_total / 4 | floor),
            est_tokens_max: (.chars_max / 4 | floor)
          }
        | del(.lengths)
    ' <"$TP_INPUT"
)" || die 'failed to parse input as JSONL'

if [ "$json" -eq 1 ]; then
    printf '%s\n' "$report"
else
    printf '%s\n' "$report" |
        jq -r 'to_entries[] | "\(.key)\t\(.value)"' |
        awk -F'\t' '{ printf "%-18s %12s\n", $1, $2 }'
fi

if [ "$strict" -eq 1 ]; then
    bad="$(printf '%s\n' "$report" | jq -r '.invalid + .missing')"
    if [ "$bad" -gt 0 ]; then
        printf 'strict: %s invalid or incomplete record(s)\n' "$bad" >&2
        exit 1
    fi
fi
