#!/usr/bin/env bash
#
# strip-markup.sh - reduce HTML or Markdown to the prose inside it.
#
# Markup inflates token counts and pollutes term statistics: a retrieval index
# does not benefit from knowing that a word sat inside <strong> or **bold**.
#
#   ./strip-markup.sh page.html
#   ./strip-markup.sh --markdown README.md | ./token-estimate.sh

set -euo pipefail
# shellcheck source=lib/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib/common.sh"

usage() {
    cat <<'USAGE'
Usage: strip-markup.sh [OPTIONS] [FILE]

Strip markup, keeping the text. Reads FILE, or stdin when FILE is omitted
or "-".

Options:
  --html        treat the input as HTML
  --markdown    treat the input as Markdown
  --auto        choose by file extension, then by sniffing (default)
  --keep-code   Markdown only: keep fenced code block contents
  -h, --help    show this help

HTML:     drops <script>/<style> bodies and comments, removes tags, decodes
          the five basic entities plus &nbsp; and numeric &#39;.
Markdown: drops fenced code, turns [text](url) into text and ![alt](url) into
          alt, then removes heading, emphasis, quote, list and rule markers.
          Underscores inside a word are left alone, so snake_case identifiers
          survive rather than being read as emphasis.
USAGE
}

mode=auto
keep_code=0

while [ $# -gt 0 ]; do
    case "$1" in
        --html) mode=html; shift ;;
        --markdown | --md) mode=markdown; shift ;;
        --auto) mode=auto; shift ;;
        --keep-code) keep_code=1; shift ;;
        -h | --help) usage; exit 0 ;;
        --) shift; break ;;
        -*) die "unknown option: $1 (try --help)" ;;
        *) break ;;
    esac
done
[ $# -le 1 ] || die 'expected at most one FILE argument'

arg="${1:-}"
tp_input "$arg"

if [ "$mode" = auto ]; then
    case "${arg,,}" in
        *.html | *.htm | *.xhtml) mode=html ;;
        *.md | *.markdown) mode=markdown ;;
        *)
            # No usable extension (or reading stdin): sniff for a tag that
            # only appears in HTML.
            if grep -q -i -E '<(html|body|div|p|br|span|table)\b' "$TP_INPUT"; then
                mode=html
            else
                mode=markdown
            fi
            ;;
    esac
fi

strip_html() {
    # Element bodies first, then comments, then the tags themselves. Slurping
    # (:a;N;$!ba) is required because any of these can span lines.
    sed -E ':a;N;$!ba
            s#<script\b[^>]*>.*?</script>##Ig
            s#<style\b[^>]*>.*?</style>##Ig
            s#<!--.*?-->##g' "$TP_INPUT" |
        # Block-level tags become line breaks so that words do not run together.
        sed -E -e 's#</?(p|div|br|li|tr|h[1-6]|blockquote|section|article)\b[^>]*>#\n#Ig' \
            -e 's#<[^>]+>##g' |
        # Entities last: decoding first would let a literal &lt;b&gt; turn into
        # a tag and then be stripped as one.
        sed -E -e 's/&nbsp;/ /g' -e 's/&#39;/'"'"'/g' -e 's/&quot;/"/g' \
            -e 's/&lt;/</g' -e 's/&gt;/>/g' -e 's/&amp;/\&/g' |
        sed -E 's/[[:space:]]+$//' | cat -s
}

# SC2016: the backticks in the inline-code rule are literal characters inside
# a sed expression, not an attempted command substitution.
# shellcheck disable=SC2016
strip_markdown() {
    {
        if [ "$keep_code" -eq 1 ]; then
            # Keep the code, drop only the fence lines.
            grep -v -E '^[[:space:]]*```' "$TP_INPUT" || true
        else
            # Toggle on each fence and print only what falls outside.
            awk '/^[[:space:]]*```/ { inblock = !inblock; next } !inblock' "$TP_INPUT"
        fi
    } |
        sed -E \
            -e 's/!\[([^]]*)\]\([^)]*\)/\1/g' \
            -e 's/\[([^]]*)\]\([^)]*\)/\1/g' \
            -e 's/\[([^]]*)\]\[[^]]*\]/\1/g' \
            -e 's/^[[:space:]]*#+[[:space:]]*//' \
            -e 's/^[[:space:]]*>[[:space:]]?//' \
            -e 's/^[[:space:]]*[-*+][[:space:]]+//' \
            -e 's/^[[:space:]]*[0-9]+\.[[:space:]]+//' \
            -e 's/^[[:space:]]*([-*_][[:space:]]*){3,}[[:space:]]*$//' \
            -e 's/\*\*([^*]+)\*\*/\1/g' \
            -e 's/(^|[^[:alnum:]_])__([^_]+)__($|[^[:alnum:]_])/\1\2\3/g' \
            -e 's/\*([^*]+)\*/\1/g' \
            -e 's/(^|[^[:alnum:]_])_([^_]+)_($|[^[:alnum:]_])/\1\2\3/g' \
            -e 's/`([^`]*)`/\1/g' \
            -e 's/~~([^~]+)~~/\1/g' |
        sed -E 's/[[:space:]]+$//' | cat -s
}

case "$mode" in
    html) strip_html ;;
    markdown) strip_markdown ;;
    *) die "internal: unknown mode $mode" ;;
esac
