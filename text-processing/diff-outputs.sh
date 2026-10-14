#!/usr/bin/env bash
#
# diff-outputs.sh - compare two model outputs (or any two texts).
#
# Regression testing a prompt change means diffing yesterday's answer against
# today's. A line diff is close to useless for prose, because rewrapping one
# paragraph marks every line as changed; a word diff shows what actually moved.
#
#   ./diff-outputs.sh before.txt after.txt
#   ./diff-outputs.sh --similarity before.txt after.txt
#   ./diff-outputs.sh --sentences before.txt after.txt

set -euo pipefail
# shellcheck source=lib/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib/common.sh"

TP_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    cat <<'USAGE'
Usage: diff-outputs.sh [OPTIONS] FILE_A FILE_B

Diff two texts at word granularity using git's word-diff.

Options:
  --lines         plain unified line diff instead of a word diff
  --sentences     put one sentence per line first, so the diff is per sentence
  --similarity    also print a jaccard/containment summary (similarity.sh)
  --color         force colour output
  -h, --help      show this help

Exit status: 0 identical, 1 differences found, 2 usage or runtime error.
This mirrors diff(1), so it can gate a regression test directly.
USAGE
}

style=word
similarity=0
color=never

while [ $# -gt 0 ]; do
    case "$1" in
        --lines) style=lines; shift ;;
        --sentences) style=sentences; shift ;;
        --similarity) similarity=1; shift ;;
        --color | --colour) color=always; shift ;;
        -h | --help) usage; exit 0 ;;
        --) shift; break ;;
        -*) die "unknown option: $1 (try --help)" ;;
        *) break ;;
    esac
done
[ $# -eq 2 ] || die 'exactly two FILE arguments are required (try --help)'
need_cmd git

tp_tmpdir
tp_input "$1"
a="$TP_TMPDIR/a"
cp -- "$TP_INPUT" "$a"
tp_input "$2"
b="$TP_TMPDIR/b"
cp -- "$TP_INPUT" "$b"

if [ "$style" = sentences ]; then
    tp_sentences "$a" >"$a.s" && mv -- "$a.s" "$a"
    tp_sentences "$b" >"$b.s" && mv -- "$b.s" "$b"
fi

diff_args=(--no-index "--color=$color")
if [ "$style" = word ]; then
    diff_args+=(--word-diff=plain)
fi

# git diff --no-index exits 1 when the files differ, which is not an error
# here; anything above 1 is.
status=0
git --no-pager diff "${diff_args[@]}" -- "$a" "$b" || status=$?
if [ "$status" -gt 1 ]; then
    die "git diff failed with status $status"
fi

if [ "$similarity" -eq 1 ]; then
    printf '\n--- similarity ---\n'
    "$TP_DIR/similarity.sh" "$1" "$2"
fi

exit "$status"
