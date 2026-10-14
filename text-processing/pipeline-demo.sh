#!/usr/bin/env bash
#
# pipeline-demo.sh - show the whole collection working as one pipeline.
#
# Each script reads stdin or a file and writes to stdout, so they compose.
# That composability is the actual lesson of this directory: no single script
# here is clever, but chained together they are a working document-ingestion
# pipeline in a few hundred lines of shell.
#
#   ./pipeline-demo.sh              # run against the bundled sample
#   ./pipeline-demo.sh mydoc.md     # run against your own document

set -euo pipefail
# shellcheck source=lib/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib/common.sh"

TP_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    cat <<'USAGE'
Usage: pipeline-demo.sh [FILE]

Walk a document through the collection: inspect, redact, normalize, chunk,
convert to JSONL, and report corpus statistics. Uses a bundled sample when
no FILE is given.

Calls no network service and needs no API key.
USAGE
}

case "${1:-}" in
    -h | --help) usage; exit 0 ;;
esac

need_cmd jq
tp_tmpdir
work="$TP_TMPDIR"

step() {
    printf '\n\033[1m== %s ==\033[0m\n' "$*"
}

if [ $# -ge 1 ]; then
    tp_input "$1"
    cp -- "$TP_INPUT" "$work/source.md"
else
    cat >"$work/source.md" <<'SAMPLE'
# Quarterly Notes

Our “smart quotes” and em—dashes came out of a PDF, with a hyphen-
ated word split across the line break.

## Contacts

Reach Dana at dana.reed@example.com or on 555-123-4567. The staging
box is 10.0.0.42 and the runbook is at https://example.com/runbook.

## Findings

Clean data beats clever models. Clean data beats clever models. Teams
that invest in preprocessing ship faster than teams that do not.

```bash
# not prose: this block should not pollute the term statistics
export AWS_KEY=AKIAIOSFODNN7EXAMPLE
```
SAMPLE
fi

step "1. Input"
printf '%s\n' "$(wc -l <"$work/source.md") lines, $(wc -c <"$work/source.md") bytes"
"$TP_DIR/token-estimate.sh" "$work/source.md"

step "2. Scan for anything sensitive (pii-redact.sh --check)"
if "$TP_DIR/pii-redact.sh" --check "$work/source.md" >/dev/null; then
    printf 'nothing sensitive found\n'
else
    printf '^ findings above: this document must be redacted before it is sent anywhere\n'
fi

step "3. Redact, then normalize (pii-redact.sh | normalize-text.sh)"
"$TP_DIR/pii-redact.sh" "$work/source.md" |
    "$TP_DIR/normalize-text.sh" --squeeze-blank >"$work/clean.md"
sed -n '1,12p' "$work/clean.md"

step "4. Strip markup and measure the vocabulary (strip-markup.sh | lexical-stats.sh)"
"$TP_DIR/strip-markup.sh" --markdown "$work/clean.md" >"$work/plain.txt"
"$TP_DIR/lexical-stats.sh" "$work/plain.txt"

step "5. Most frequent two-word phrases (ngrams.sh --stopwords)"
"$TP_DIR/ngrams.sh" -n 2 --stopwords --top 5 "$work/plain.txt"

step "6. Chunk along the heading structure (chunk-markdown.sh)"
"$TP_DIR/chunk-markdown.sh" --max-words 40 --format tsv "$work/clean.md" |
    awk -F'\t' '{ printf "%-28s %3s words  %.50s...\n", $1, $2, $3 }'

step "7. Emit RAG-ready records (chunk-text.sh --format jsonl)"
"$TP_DIR/chunk-text.sh" --max-words 40 --format jsonl "$work/plain.txt" >"$work/chunks.jsonl"
head -2 "$work/chunks.jsonl"

step "8. Validate and size the dataset (jsonl-stats.sh)"
"$TP_DIR/jsonl-stats.sh" "$work/chunks.jsonl"

step "9. What a model call would look like (llm-call.sh --dry-run)"
printf 'no API key is read and no request is sent:\n'
"$TP_DIR/llm-call.sh" --dry-run --system 'Summarise in one sentence.' \
    --file "$work/plain.txt" 2>/dev/null |
    jq -c '{model, max_tokens, effort: .output_config.effort, prompt_chars: (.messages[0].content | length)}'

step "Done"
cat <<'CLOSING'
The same chain as a one-liner:

  ./pii-redact.sh doc.md \
    | ./normalize-text.sh --squeeze-blank \
    | ./strip-markup.sh --markdown \
    | ./chunk-text.sh --max-words 200 --format jsonl \
    > chunks.jsonl

Run `<script> --help` for any stage, or read ../docs/text-processing.md.
CLOSING
