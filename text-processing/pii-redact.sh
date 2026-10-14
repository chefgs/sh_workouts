#!/usr/bin/env bash
#
# pii-redact.sh - mask personal data and credentials before text leaves the machine.
#
# Intended as the first stage of any pipeline that sends text to an LLM API,
# ships it to a log aggregator, or commits it to a repository.
#
#   ./pii-redact.sh notes.txt
#   cat notes.txt | ./pii-redact.sh --except urls
#   ./pii-redact.sh --check notes.txt   # exit 1 if anything sensitive is found
#
# IMPORTANT: regex redaction is a safety net, not a guarantee. It cannot find
# names, postal addresses, free-form account numbers or novel key formats.
# Never treat a clean run as proof that a document is safe to publish.

set -euo pipefail
# shellcheck source=lib/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib/common.sh"

# Order matters: keys collapse first so later per-line rules cannot leak a
# fragment of a key block, and urls run before emails so that a userinfo@host
# URL is masked as a whole rather than as an address.
CATEGORIES=(keys jwt aws urls emails ssn phones cards ips)

usage() {
    cat <<'USAGE'
Usage: pii-redact.sh [OPTIONS] [FILE]

Replace sensitive substrings with <PLACEHOLDER> tokens. Reads FILE, or stdin
when FILE is omitted or "-".

Options:
  --only LIST     redact only these categories (comma separated)
  --except LIST   redact everything except these categories
  --check         report findings on stderr, emit no text, exit 1 if any found
  --stats         emit text as usual, print a per-category count on stderr
  --list          list the category names and exit
  -h, --help      show this help

Categories (applied in this order):
  keys    PEM private key blocks        -> <PRIVATE_KEY>
  jwt     JSON Web Tokens               -> <JWT>
  aws     AWS access key IDs            -> <AWS_KEY>
  urls    http/https URLs               -> <URL>
  emails  email addresses               -> <EMAIL>
  ssn     US social security numbers    -> <SSN>
  phones  US-style phone numbers        -> <PHONE>
  cards   13-16 digit card numbers      -> <CARD>
  ips     IPv4 addresses                -> <IP>

Exit status: 0 ok, 1 findings in --check mode, 2 usage or runtime error.
USAGE
}

# The extended regex that identifies a category. Kept separate from the
# replacement token so that counting (--stats, --check) and substitution use
# one single source of truth instead of parsing the sed expression back apart.
# No pattern may contain '#', which is used as the sed delimiter below.
pii_regex() {
    case "$1" in
        keys)   printf '%s' '-----BEGIN [A-Z ]*PRIVATE KEY-----' ;;
        jwt)    printf '%s' '\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}' ;;
        aws)    printf '%s' '\b(AKIA|ASIA)[0-9A-Z]{16}\b' ;;
        urls)   printf '%s' '\bhttps?://[^[:space:]<>"]+' ;;
        emails) printf '%s' '[[:alnum:]._%+-]+@[[:alnum:]._-]+\.[[:alpha:]]{2,}' ;;
        ssn)    printf '%s' '\b[0-9]{3}-[0-9]{2}-[0-9]{4}\b' ;;
        phones) printf '%s' '(\([0-9]{3}\)[ ]?|\b[0-9]{3}-)[0-9]{3}-[0-9]{4}\b' ;;
        cards)  printf '%s' '\b([0-9]{4}[ -][0-9]{4}[ -][0-9]{4}[ -][0-9]{4}|[0-9]{13,16})\b' ;;
        ips)    printf '%s' '\b[0-9]{1,3}(\.[0-9]{1,3}){3}\b' ;;
        *)      die "no pattern for category: $1" ;;
    esac
}

pii_token() {
    case "$1" in
        keys)   printf '%s' '<PRIVATE_KEY>' ;;
        jwt)    printf '%s' '<JWT>' ;;
        aws)    printf '%s' '<AWS_KEY>' ;;
        urls)   printf '%s' '<URL>' ;;
        emails) printf '%s' '<EMAIL>' ;;
        ssn)    printf '%s' '<SSN>' ;;
        phones) printf '%s' '<PHONE>' ;;
        cards)  printf '%s' '<CARD>' ;;
        ips)    printf '%s' '<IP>' ;;
        *)      die "no token for category: $1" ;;
    esac
}

in_list() {
    local needle="$1" item
    shift
    for item in "$@"; do
        if [ "$item" = "$needle" ]; then
            return 0
        fi
    done
    return 1
}

mode=redact
only=''
except=''

while [ $# -gt 0 ]; do
    case "$1" in
        --only)
            [ $# -ge 2 ] || die 'option --only needs a value'
            only="$2"
            shift 2
            ;;
        --except)
            [ $# -ge 2 ] || die 'option --except needs a value'
            except="$2"
            shift 2
            ;;
        --check) mode=check; shift ;;
        --stats) mode=stats; shift ;;
        --list)  printf '%s\n' "${CATEGORIES[@]}"; exit 0 ;;
        -h | --help) usage; exit 0 ;;
        --) shift; break ;;
        -*) die "unknown option: $1 (try --help)" ;;
        *) break ;;
    esac
done

if [ -n "$only" ] && [ -n "$except" ]; then
    die 'use --only or --except, not both'
fi
if [ $# -gt 1 ]; then
    die 'expected at most one FILE argument'
fi

# Resolve the active category list, validating every name the caller gave.
active=()
if [ -n "$only" ]; then
    IFS=, read -r -a requested <<<"$only"
    for cat in "${requested[@]}"; do
        in_list "$cat" "${CATEGORIES[@]}" || die "unknown category: $cat"
        active+=("$cat")
    done
else
    skip=()
    if [ -n "$except" ]; then
        IFS=, read -r -a skip <<<"$except"
        for cat in "${skip[@]}"; do
            in_list "$cat" "${CATEGORIES[@]}" || die "unknown category: $cat"
        done
    fi
    for cat in "${CATEGORIES[@]}"; do
        if [ ${#skip[@]} -eq 0 ] || ! in_list "$cat" "${skip[@]}"; then
            active+=("$cat")
        fi
    done
fi
[ ${#active[@]} -gt 0 ] || die 'no categories selected'

tp_input "${1:-}"

# --check and --stats both need counts, so gather them before redacting.
if [ "$mode" != redact ]; then
    found=0
    for cat in "${active[@]}"; do
        # grep -c counts matching lines; piping -o through grep -c '' counts
        # every occurrence, including several on one line.
        n=$(grep -o -E -- "$(pii_regex "$cat")" "$TP_INPUT" | grep -c '' || true)
        if [ "$n" -gt 0 ]; then
            printf '%-8s %d\n' "$cat" "$n" >&2
            found=$((found + n))
        fi
    done
    printf 'total %d finding(s)\n' "$found" >&2
    if [ "$mode" = check ]; then
        [ "$found" -eq 0 ] || exit 1
        exit 0
    fi
fi

# Build the sed program. A PEM block spans lines, so it needs an address range
# with `c` rather than a substitution.
sed_args=()
for cat in "${active[@]}"; do
    if [ "$cat" = keys ]; then
        sed_args+=(-e '/-----BEGIN [A-Z ]*PRIVATE KEY-----/,/-----END [A-Z ]*PRIVATE KEY-----/c\<PRIVATE_KEY>')
    else
        sed_args+=(-e "s#$(pii_regex "$cat")#$(pii_token "$cat")#g")
    fi
done

sed -E "${sed_args[@]}" -- "$TP_INPUT"
