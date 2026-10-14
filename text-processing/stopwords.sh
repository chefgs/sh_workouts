#!/usr/bin/env bash
#
# stopwords.sh - drop high-frequency function words from a token stream.
#
# A line filter by design: it expects one token per line, so it composes with
# tokenize.sh rather than duplicating tokenization.
#
#   ./tokenize.sh --words --lower notes.txt | ./stopwords.sh | sort | uniq -c
#   ./tokenize.sh --words --lower notes.txt | ./stopwords.sh --invert

set -euo pipefail
# shellcheck source=lib/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib/common.sh"

TP_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_LIST="$TP_DIR/data/stopwords-en.txt"

usage() {
    cat <<'USAGE'
Usage: stopwords.sh [OPTIONS] [FILE]

Remove stopwords from a stream of one token per line. Reads FILE, or stdin
when FILE is omitted or "-".

Options:
  --list FILE   use FILE as the stopword list (default: data/stopwords-en.txt)
  --invert      keep ONLY stopwords (useful for inspecting what was removed)
  --count       show how many tokens were kept and removed, on stderr
  -h, --help    show this help

Matching is whole-line and literal (grep -x -F), never a substring: the
stopword "a" must not remove "apple".
USAGE
}

list="$DEFAULT_LIST"
invert=0
show_count=0

while [ $# -gt 0 ]; do
    case "$1" in
        --list)
            [ $# -ge 2 ] || die 'option --list needs a value'
            list="$2"
            shift 2
            ;;
        --invert) invert=1; shift ;;
        --count) show_count=1; shift ;;
        -h | --help) usage; exit 0 ;;
        --) shift; break ;;
        -*) die "unknown option: $1 (try --help)" ;;
        *) break ;;
    esac
done
[ $# -le 1 ] || die 'expected at most one FILE argument'

[ -r "$list" ] || die "stopword list not readable: $list"
tp_input "${1:-}"

# -x anchors to the whole line and -F disables regex, so a list entry such as
# "can't" is matched literally rather than as a pattern.
grep_args=(-x -F -f "$list")
if [ "$invert" -eq 0 ]; then
    grep_args=(-v "${grep_args[@]}")
fi

if [ "$show_count" -eq 1 ]; then
    total=$(grep -c '' <"$TP_INPUT" || true)
    kept=$(grep "${grep_args[@]}" -- "$TP_INPUT" | grep -c '' || true)
    printf 'tokens in: %d  kept: %d  removed: %d\n' \
        "$total" "$kept" "$((total - kept))" >&2
fi

grep "${grep_args[@]}" -- "$TP_INPUT" || true
