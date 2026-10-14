#!/usr/bin/env bash
#
# prompt-template.sh - fill ${PLACEHOLDER} slots in a prompt template.
#
# Substitution is done with bash parameter expansion, never with eval and
# never with a shell here-doc: a template is data, and data that gets
# evaluated is a command-injection bug waiting for someone to paste a
# $(rm -rf ...) into a variable.
#
# Unset variables are an error by default, because a silently blank slot
# produces a prompt that looks fine and means something else.
#
#   ./prompt-template.sh --var TOPIC=chunking --var TONE=brief tpl.txt
#   TOPIC=chunking ./prompt-template.sh tpl.txt
#   ./prompt-template.sh --list-vars tpl.txt

set -euo pipefail
# shellcheck source=lib/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib/common.sh"

usage() {
    cat <<'USAGE'
Usage: prompt-template.sh [OPTIONS] [FILE]

Replace every ${NAME} placeholder with a value. Reads FILE, or stdin when
FILE is omitted or "-".

Options:
  --var NAME=VALUE   set NAME (repeatable; takes precedence over the
                     environment)
  --allow-missing    replace unknown placeholders with an empty string
                     instead of failing
  --list-vars        list the placeholder names in the template and exit
  -h, --help         show this help

Only the ${NAME} form is recognised, with NAME matching [A-Za-z_][A-Za-z0-9_]*.
A bare $NAME is left alone, so prose and shell snippets inside a template
survive untouched.

Values are inserted literally and are never re-scanned, so a value that
itself contains ${OTHER} does not expand.

Exit status: 0 ok, 1 missing variables, 2 usage or runtime error.
USAGE
}

declare -A overrides=()
allow_missing=0
list_vars=0

while [ $# -gt 0 ]; do
    case "$1" in
        --var)
            [ $# -ge 2 ] || die 'option --var needs a NAME=VALUE argument'
            case "$2" in
                [A-Za-z_]*=*) : ;;
                *) die "--var expects NAME=VALUE, got: $2" ;;
            esac
            name="${2%%=*}"
            case "$name" in
                *[!A-Za-z0-9_]*) die "invalid variable name: $name" ;;
            esac
            overrides["$name"]="${2#*=}"
            shift 2
            ;;
        --allow-missing) allow_missing=1; shift ;;
        --list-vars) list_vars=1; shift ;;
        -h | --help) usage; exit 0 ;;
        --) shift; break ;;
        -*) die "unknown option: $1 (try --help)" ;;
        *) break ;;
    esac
done
[ $# -le 1 ] || die 'expected at most one FILE argument'

tp_input "${1:-}"

# Read the template preserving trailing newlines: command substitution strips
# them, so append a sentinel and remove it again.
template="$(cat -- "$TP_INPUT"; printf 'x')"
template="${template%x}"

# Collect the distinct placeholder names in the order they first appear.
mapfile -t names < <(
    grep -o -E '\$\{[A-Za-z_][A-Za-z0-9_]*\}' -- "$TP_INPUT" |
        sed -E 's/^\$\{//; s/\}$//' |
        awk '!seen[$0]++'
)

if [ "$list_vars" -eq 1 ]; then
    if [ ${#names[@]} -gt 0 ]; then
        printf '%s\n' "${names[@]}"
    fi
    exit 0
fi

# Resolve a value for every placeholder before touching the template, so
# that a missing variable is reported once, up front.
declare -A values=()
missing=()
for name in "${names[@]}"; do
    if [ -n "${overrides[$name]+set}" ]; then
        values["$name"]="${overrides[$name]}"
    elif [ -n "${!name+set}" ]; then
        values["$name"]="${!name}"
    elif [ "$allow_missing" -eq 1 ]; then
        values["$name"]=''
    else
        missing+=("$name")
    fi
done

if [ ${#missing[@]} -gt 0 ]; then
    printf '%s: missing value for: %s\n' "$TP_SCRIPT_NAME" "${missing[*]}" >&2
    printf 'pass --var NAME=VALUE, export the variable, or use --allow-missing\n' >&2
    exit 1
fi

# Single pass, left to right: consume the template up to and including each
# placeholder and append the value to the output, which is never re-scanned.
#
# Substituting one name at a time over the whole template (the obvious
# `${template//...}` loop) is NOT equivalent: a value containing ${OTHER}
# would be rewritten by a later iteration, letting a value pull in a second
# variable. Here a value is final the moment it is appended.
out=''
rest="$template"
while [[ "$rest" =~ \$\{([A-Za-z_][A-Za-z0-9_]*)\} ]]; do
    name="${BASH_REMATCH[1]}"
    placeholder="\${$name}"
    prefix="${rest%%"$placeholder"*}"
    out+="$prefix${values[$name]-}"
    rest="${rest#"$prefix$placeholder"}"
done
template="$out$rest"

printf '%s' "$template"
