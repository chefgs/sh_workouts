#!/usr/bin/env bash
#
# chunk-text.sh - split text into overlapping, sentence-aligned chunks.
#
# This is what a retrieval pipeline's text splitter does: cut a document into
# pieces small enough to embed, without cutting mid-sentence, and overlap
# consecutive pieces so a fact spanning a boundary survives in at least one
# of them.
#
#   ./chunk-text.sh --max-words 200 --overlap 1 report.txt
#   ./chunk-text.sh --format jsonl report.txt > chunks.jsonl

set -euo pipefail
# shellcheck source=lib/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib/common.sh"

usage() {
    cat <<'USAGE'
Usage: chunk-text.sh [OPTIONS] [FILE]

Split text into chunks on sentence boundaries. Reads FILE, or stdin when FILE
is omitted or "-".

Options:
  --max-words N   target maximum words per chunk (default 200)
  --overlap S     repeat the last S sentences at the start of the next chunk
                  (default 1; 0 disables overlap)
  --format FMT    text (default), tsv, or jsonl
  -h, --help      show this help

Formats:
  text   a "=== chunk N ===" header followed by the chunk
  tsv    CHUNK <tab> WORDS <tab> SENTENCES <tab> TEXT
  jsonl  one JSON object per line (requires jq)

A sentence longer than --max-words is emitted as its own oversized chunk
rather than being split mid-sentence; chunks are never dropped and the
splitter always advances, so no input can stall it.

Tabs inside the text are converted to spaces so that the tsv and jsonl forms
stay unambiguous.
USAGE
}

max_words=200
overlap=1
format=text

while [ $# -gt 0 ]; do
    case "$1" in
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

# Emit CHUNK \t WORDS \t SENTENCES \t TEXT, one chunk per line.
chunk_tsv() {
    tp_sentences "$TP_INPUT" |
        awk -v max="$max_words" -v ov="$overlap" '
    { gsub(/\t/, " "); s[NR] = $0; n[NR] = NF }
    END {
        i = 1
        c = 0
        while (i <= NR) {
            buf = ""
            words = 0
            count = 0
            j = i
            # Always take at least one sentence. Without this a sentence
            # longer than max would add nothing, j would never advance past
            # i, and the loop would spin forever.
            while (j <= NR) {
                if (count > 0 && words + n[j] > max) break
                buf = (buf == "" ? s[j] : buf " " s[j])
                words += n[j]
                count++
                j++
            }
            c++
            printf "%d\t%d\t%d\t%s\n", c, words, count, buf
            # Step back by the overlap, but never to where we already were:
            # progress has to be guaranteed for every input.
            next_i = j - ov
            if (next_i <= i) next_i = i + 1
            i = next_i
        }
    }'
}

case "$format" in
    tsv) chunk_tsv ;;
    jsonl)
        # jq -R builds the JSON string, so quotes and backslashes in the text
        # are escaped properly instead of corrupting the record.
        chunk_tsv | jq -R -c 'split("\t") | {
            chunk: (.[0] | tonumber),
            words: (.[1] | tonumber),
            sentences: (.[2] | tonumber),
            text: .[3]
        }'
        ;;
    text)
        chunk_tsv | awk -F'\t' '{
            printf "=== chunk %s (words=%s, sentences=%s) ===\n%s\n\n", $1, $2, $3, $4
        }'
        ;;
    *) die "internal: unknown format $format" ;;
esac
