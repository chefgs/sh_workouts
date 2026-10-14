#!/usr/bin/env bash
# shellcheck shell=bash
#
# common.sh - shared helpers for the text-processing collection.
#
# Source this file, do not execute it:
#     source "$(dirname -- "${BASH_SOURCE[0]}")/lib/common.sh"
#
# Provides:
#   die MSG            print to stderr and exit 2
#   warn MSG           print to stderr, keep going
#   need_cmd CMD...    verify external dependencies up front
#   tp_tmpdir          create (once) an auto-cleaned temp dir, set TP_TMPDIR
#   tp_input [FILE]    set TP_INPUT to a seekable file holding FILE or stdin
#   tp_words [FILE]    stream one lowercase-able word per line
#   tp_lower           case-fold stdin
#   tp_sentences FILE  one sentence per line
#   tp_require_int VAL NAME
#
# All helpers quote their arguments; filenames with spaces are supported.

if [ -n "${TP_COMMON_SOURCED:-}" ]; then
    return 0
fi
TP_COMMON_SOURCED=1

# Fail fast and loudly: unset variables and broken pipe stages are bugs.
set -euo pipefail

TP_SCRIPT_NAME="${0##*/}"

die() {
    printf '%s: error: %s\n' "$TP_SCRIPT_NAME" "$*" >&2
    exit 2
}

warn() {
    printf '%s: warning: %s\n' "$TP_SCRIPT_NAME" "$*" >&2
}

need_cmd() {
    local cmd
    for cmd in "$@"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            die "required command not found: $cmd"
        fi
    done
}

tp_require_int() {
    local value="$1" name="$2"
    case "$value" in
        '' | *[!0-9]*) die "$name must be a non-negative integer, got: $value" ;;
    esac
}

_tp_tmpdir=''

# Set by tp_tmpdir / tp_input for callers to read.
TP_TMPDIR=''
TP_INPUT=''

_tp_cleanup() {
    if [ -n "$_tp_tmpdir" ] && [ -d "$_tp_tmpdir" ]; then
        rm -rf -- "$_tp_tmpdir"
    fi
}

# Create the per-run temp directory once and register its cleanup.
#
# This sets TP_TMPDIR rather than printing it, and callers must NOT invoke it
# inside a command substitution: a subshell would create the directory, install
# the EXIT trap, then fire that trap on subshell exit and delete the directory
# out from under the caller.
tp_tmpdir() {
    if [ -z "$_tp_tmpdir" ]; then
        _tp_tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/tp.XXXXXX")" ||
            die 'cannot create temporary directory'
        TP_TMPDIR="$_tp_tmpdir"
        trap _tp_cleanup EXIT HUP INT TERM
    fi
}

# Resolve FILE (or stdin when FILE is empty or "-") to a seekable regular file
# and set TP_INPUT to its path. Multi-pass stages (sort, two-pass awk) cannot
# re-read a pipe, so stdin is spooled to the temp directory first.
#
# Call it directly -- `tp_input "$f"` -- never as `x="$(tp_input "$f")"`, for
# the subshell reason described on tp_tmpdir above.
tp_input() {
    local file="${1:--}"
    if [ -z "$file" ] || [ "$file" = '-' ]; then
        tp_tmpdir
        TP_INPUT="$TP_TMPDIR/stdin"
        cat >"$TP_INPUT" || die 'failed to read standard input'
        return 0
    fi
    if [ ! -e "$file" ]; then
        die "no such file: $file"
    fi
    if [ -d "$file" ]; then
        die "is a directory, expected a file: $file"
    fi
    if [ ! -r "$file" ]; then
        die "file is not readable: $file"
    fi
    TP_INPUT="$file"
}

# Case-fold stdin. The character classes MUST stay quoted: unquoted
# [:upper:] is a glob that silently expands against the working directory.
tp_lower() {
    tr '[:upper:]' '[:lower:]'
}

# Word tokenizer: every run of non-alphanumeric characters becomes one
# newline (-s squeezes, so no empty-line cleanup pass is needed), then any
# leading blank from a non-alphanumeric first character is dropped.
tp_words() {
    tr -cs '[:alnum:]' '\n' <"$1" | grep -v '^$' || true
}

# Sentence splitter: break after . ! ? when followed by whitespace.
tp_sentences() {
    sed -E 's/([.!?])[[:space:]]+/\1\n/g' "$1" | sed '/^[[:space:]]*$/d'
}
