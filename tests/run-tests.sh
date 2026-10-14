#!/usr/bin/env bash
#
# run-tests.sh - tests for the text-processing collection.
#
# No network, no API key, no side effects outside a temporary directory.
#
#   tests/run-tests.sh            # run everything
#   tests/run-tests.sh chunk      # run tests whose name matches "chunk"
#
# Many of these are regression tests for bugs found while building the
# scripts; each such case names the bug it guards against.

set -uo pipefail

TESTS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname -- "$TESTS_DIR")"
TP="$REPO_DIR/text-processing"
FIXTURES="$TESTS_DIR/fixtures"

FILTER="${1:-}"
PASS=0
FAIL=0
FAILED_NAMES=()

WORK="$(mktemp -d "${TMPDIR:-/tmp}/tp-tests.XXXXXX")"
# Invoked through the trap below, which shellcheck cannot see.
# shellcheck disable=SC2317
cleanup() { rm -rf -- "$WORK"; }
trap cleanup EXIT HUP INT TERM

red() { printf '\033[31m%s\033[0m' "$*"; }
green() { printf '\033[32m%s\033[0m' "$*"; }

# check NAME EXPECTED ACTUAL
check() {
    local name="$1" expected="$2" actual="$3"
    if [ -n "$FILTER" ] && [[ "$name" != *"$FILTER"* ]]; then
        return 0
    fi
    if [ "$expected" = "$actual" ]; then
        PASS=$((PASS + 1))
        printf '  %s %s\n' "$(green ok)" "$name"
    else
        FAIL=$((FAIL + 1))
        FAILED_NAMES+=("$name")
        printf '  %s %s\n' "$(red FAIL)" "$name"
        printf '      expected: %s\n' "$expected"
        printf '      actual:   %s\n' "$actual"
    fi
}

section() { printf '\n%s\n' "$*"; }

# ---------------------------------------------------------------- hygiene

section 'pii-redact.sh'
check 'pii-redact masks an email' \
    'contact <EMAIL> now' \
    "$(printf 'contact a.b@example.com now\n' | "$TP/pii-redact.sh")"
check 'pii-redact masks a PEM block across lines' \
    '<PRIVATE_KEY>' \
    "$("$TP/pii-redact.sh" "$FIXTURES/secrets.txt" | grep -c . | xargs -I{} sh -c 'true'; "$TP/pii-redact.sh" "$FIXTURES/secrets.txt" | sed -n 2p)"
check 'pii-redact --check exits 1 on findings' '1' \
    "$("$TP/pii-redact.sh" --check "$FIXTURES/secrets.txt" >/dev/null 2>&1; echo $?)"
check 'pii-redact --check exits 0 on clean input' '0' \
    "$(printf 'nothing here\n' | "$TP/pii-redact.sh" --check >/dev/null 2>&1; echo $?)"
check 'pii-redact --only limits categories' 'call 555-123-4567 from <IP>' \
    "$(printf 'call 555-123-4567 from 10.0.0.42\n' | "$TP/pii-redact.sh" --only ips)"
check 'pii-redact rejects an unknown category' '2' \
    "$(printf 'x\n' | "$TP/pii-redact.sh" --only nope >/dev/null 2>&1; echo $?)"
# Regression: tp_input spooled stdin into a temp dir created inside a command
# substitution, whose EXIT trap deleted the dir before it could be written.
check 'REGRESSION stdin path works at all' 'hello <EMAIL>' \
    "$(printf 'hello a@b.co\n' | "$TP/pii-redact.sh")"

section 'normalize-text.sh'
# Regression: a [byte-class] sed rule split multi-byte UTF-8 and emitted one
# replacement per byte, turning a single curly quote into three characters.
check 'REGRESSION smart quotes are not byte-mangled' 'say "hi" and '"'"'bye'"'"'' \
    "$(printf 'say \xe2\x80\x9chi\xe2\x80\x9d and \xe2\x80\x98bye\xe2\x80\x99\n' | "$TP/normalize-text.sh")"
check 'normalize rejoins a hyphenated line break' 'tokenizer works' \
    "$(printf 'token-\nizer works\n' | "$TP/normalize-text.sh")"
check 'normalize maps a non-breaking space' 'a b' \
    "$(printf 'a\xc2\xa0b\n' | "$TP/normalize-text.sh")"
check 'normalize --no-unicode leaves quotes alone' "$(printf '\xe2\x80\x9cx\xe2\x80\x9d')" \
    "$(printf '\xe2\x80\x9cx\xe2\x80\x9d\n' | "$TP/normalize-text.sh" --no-unicode)"

section 'strip-markup.sh'
check 'strip-markup drops a script body' '0' \
    "$("$TP/strip-markup.sh" --html "$FIXTURES/page.html" | grep -c 'alert' || true)"
check 'strip-markup keeps link text' '1' \
    "$("$TP/strip-markup.sh" --markdown "$FIXTURES/doc.md" | grep -c 'a link' || true)"
check 'strip-markup drops fenced code by default' '0' \
    "$("$TP/strip-markup.sh" --markdown "$FIXTURES/doc.md" | grep -c 'secret_code_line' || true)"
check 'REGRESSION snake_case survives emphasis stripping' 'keep snake_case_name here' \
    "$(printf 'keep snake_case_name here\n' | "$TP/strip-markup.sh" --markdown)"
check 'strip-markup still strips real _italic_' 'an italic word' \
    "$(printf 'an _italic_ word\n' | "$TP/strip-markup.sh" --markdown)"
check 'strip-markup still strips **bold**' 'a bold word' \
    "$(printf 'a **bold** word\n' | "$TP/strip-markup.sh" --markdown)"
check 'strip-markup --keep-code keeps it' '1' \
    "$("$TP/strip-markup.sh" --keep-code --markdown "$FIXTURES/doc.md" | grep -c 'secret_code_line' || true)"

# ----------------------------------------------------------- tokenization

section 'tokenize.sh'
check 'tokenize --words' 'a
b
c' "$(printf 'a b, c!\n' | "$TP/tokenize.sh" --words)"
check 'tokenize --sentences' '2' \
    "$(printf 'One here. Two here!\n' | "$TP/tokenize.sh" --sentences | grep -c .)"
check 'tokenize --paragraphs' '2' \
    "$(printf 'para one\nline two\n\npara two\n' | "$TP/tokenize.sh" --paragraphs | grep -c .)"
check 'tokenize --count sorts by frequency' '      2 b' \
    "$(printf 'a b b\n' | "$TP/tokenize.sh" --words --count | head -1)"
check 'tokenize --lower folds case' 'abc' \
    "$(printf 'ABC\n' | "$TP/tokenize.sh" --words --lower)"

section 'token-estimate.sh'
check 'token-estimate counts chars/4' '2' \
    "$(printf 'abcdefgh\n' | "$TP/token-estimate.sh" | awk 'NR==2 {print $5}')"
check 'token-estimate --budget under exits 0' '0' \
    "$(printf 'short\n' | "$TP/token-estimate.sh" --budget 100 >/dev/null 2>&1; echo $?)"
check 'token-estimate --budget over exits 1' '1' \
    "$(printf 'this is a much longer line of text\n' | "$TP/token-estimate.sh" --budget 2 >/dev/null 2>&1; echo $?)"
# Regression: filenames were interpolated into JSON unescaped.
printf 'x\n' > "$WORK/we\"ird\\name.txt"
check 'REGRESSION --json escapes a hostile filename' '0' \
    "$("$TP/token-estimate.sh" --json "$WORK/we\"ird\\name.txt" | jq -e . >/dev/null 2>&1; echo $?)"

# ------------------------------------------------------------ statistics

section 'stopwords.sh / ngrams.sh / lexical-stats.sh'
# Whole-line matching: the stopword "a" must not remove "apple".
check 'stopwords match whole lines only' 'apple' \
    "$(printf 'a\napple\n' | "$TP/stopwords.sh")"
check 'stopwords --invert keeps only stopwords' 'the' \
    "$(printf 'the\nzebra\n' | "$TP/stopwords.sh" --invert)"
check 'ngrams counts bigrams' '      2 b c' \
    "$(printf 'b c a b c\n' | "$TP/ngrams.sh" -n 2 --top 1)"
check 'ngrams -n 3 yields trigrams' 'a b c' \
    "$(printf 'a b c\n' | "$TP/ngrams.sh" -n 3 | awk '{print $2, $3, $4}')"
check 'ngrams drops incomplete trailing n-grams' '1' \
    "$(printf 'a b\n' | "$TP/ngrams.sh" -n 2 | grep -c .)"
check 'lexical-stats ttr of all-distinct words' '1.0000' \
    "$(printf 'a b c d\n' | "$TP/lexical-stats.sh" | awk '$1=="ttr" {print $2}')"
check 'lexical-stats --json is valid' '0' \
    "$(printf 'a b\n' | "$TP/lexical-stats.sh" --json | jq -e . >/dev/null 2>&1; echo $?)"

section 'tfidf.sh / kwic.sh / zipf.sh'
# A term in every document narrows nothing, so its idf must be exactly 0.
check 'tfidf idf is 0 for a term in every document' '0.0000' \
    "$("$TP/tfidf.sh" "$FIXTURES/corpus/d1.txt" "$FIXTURES/corpus/d2.txt" |
        awk '$1=="common" {print $3}')"
check 'tfidf needs two documents' '2' \
    "$("$TP/tfidf.sh" "$FIXTURES/corpus/d1.txt" >/dev/null 2>&1; echo $?)"
check 'kwic finds a term with context' '1' \
    "$(printf 'one two target four five\n' | "$TP/kwic.sh" --window 1 target | grep -c 'two target four')"
# A literal pattern must have its metacharacters escaped.
check 'kwic treats the pattern literally by default' '0' \
    "$(printf 'clean data\n' | "$TP/kwic.sh" 'c.ean' | grep -c . || true)"
check 'kwic --regex enables metacharacters' '1' \
    "$(printf 'clean data\n' | "$TP/kwic.sh" --regex 'c.ean' | grep -c . || true)"
check 'zipf ratio of the top word is 1.00' '1.00' \
    "$(printf 'a a b\n' | "$TP/zipf.sh" --top 1 | awk 'NR==2 {print $5}')"

# -------------------------------------------------------------- chunking

section 'chunk-text.sh'
check 'chunk-text splits on sentences' '2' \
    "$(printf 'One two three. Four five six.\n' | "$TP/chunk-text.sh" --max-words 3 --overlap 0 --format tsv | grep -c .)"
check 'chunk-text never splits mid-sentence' 'One two three.' \
    "$(printf 'One two three. Four.\n' | "$TP/chunk-text.sh" --max-words 3 --overlap 0 --format tsv | head -1 | cut -f4)"
# Regression: a sentence longer than --max-words added no words, so the inner
# loop never advanced and the splitter spun forever.
check 'REGRESSION oversized sentence terminates' '0' \
    "$(printf 'a b c d e f g h i j.\n' | timeout 10 "$TP/chunk-text.sh" --max-words 2 --format tsv >/dev/null 2>&1; echo $?)"
check 'REGRESSION oversized sentence is emitted whole' '1' \
    "$(printf 'a b c d e f g h i j.\n' | timeout 10 "$TP/chunk-text.sh" --max-words 2 --format tsv | grep -c .)"
# Regression: overlap >= chunk length could step back to where it started.
check 'REGRESSION overlap larger than chunk terminates' '0' \
    "$(timeout 10 "$TP/chunk-text.sh" --max-words 5 --overlap 9 --format tsv "$FIXTURES/doc.md" >/dev/null 2>&1; echo $?)"
check 'chunk-text empty input yields nothing' '' \
    "$(printf '' | "$TP/chunk-text.sh" --format tsv)"
check 'chunk-text jsonl survives quotes and backslashes' 'He said "hi" \ ok.' \
    "$(printf 'He said "hi" \\ ok.\n' | "$TP/chunk-text.sh" --format jsonl | jq -r .text)"

section 'chunk-markdown.sh'
check 'chunk-markdown builds a heading path' 'Guide > Setup' \
    "$("$TP/chunk-markdown.sh" --format tsv "$FIXTURES/guide.md" | awk -F'\t' 'NR==2 {print $1}')"
# Regression class from toc-from-markdown.sh: a bare grep "#" treats prose and
# code comments as headings.
check 'REGRESSION a # inside prose is not a heading' '0' \
    "$("$TP/chunk-markdown.sh" --format tsv "$FIXTURES/guide.md" | awk -F'\t' '{print $1}' | grep -c '42' || true)"
check 'REGRESSION a # inside a code fence is not a heading' '0' \
    "$("$TP/chunk-markdown.sh" --format tsv "$FIXTURES/guide.md" | awk -F'\t' '{print $1}' | grep -c 'not a heading' || true)"
check 'chunk-markdown --level folds deeper headings' '0' \
    "$("$TP/chunk-markdown.sh" --level 1 --format tsv "$FIXTURES/guide.md" | awk -F'\t' '{print $1}' | grep -c '>' || true)"
check 'chunk-markdown --format jsonl is valid' '0' \
    "$("$TP/chunk-markdown.sh" --format jsonl "$FIXTURES/guide.md" | jq -e -s . >/dev/null 2>&1; echo $?)"

# ----------------------------------------------- dedup and similarity

section 'dedup.sh / similarity.sh / vocab-diff.sh'
check 'dedup preserves first-seen order' 'b
a
c' "$(printf 'b\na\nb\nc\na\n' | "$TP/dedup.sh")"
check 'dedup --ignore-case' '1' \
    "$(printf 'Ab\nab\n' | "$TP/dedup.sh" --ignore-case | grep -c .)"
check 'dedup --only-duplicates reports counts' '      2 x' \
    "$(printf 'x\ny\nx\n' | "$TP/dedup.sh" --only-duplicates)"
check 'similarity of a file with itself is 1' '1.0000' \
    "$("$TP/similarity.sh" "$FIXTURES/corpus/d1.txt" "$FIXTURES/corpus/d1.txt" | awk '$1=="jaccard" {print $2}')"
check 'similarity of disjoint files is 0' '0.0000' \
    "$("$TP/similarity.sh" "$FIXTURES/a.txt" "$FIXTURES/b.txt" | awk '$1=="jaccard" {print $2}')"
check 'containment is 1 when one side is a subset' '1.0000' \
    "$("$TP/similarity.sh" "$FIXTURES/sub.txt" "$FIXTURES/super.txt" | awk '$1=="containment" {print $2}')"
# Shingles encode word order; bare word sets do not.
check 'shingles are order-sensitive' '0.0000' \
    "$("$TP/similarity.sh" --shingles 3 "$FIXTURES/order1.txt" "$FIXTURES/order2.txt" | awk '$1=="jaccard" {print $2}')"
check 'words alone are order-insensitive' '1.0000' \
    "$("$TP/similarity.sh" "$FIXTURES/order1.txt" "$FIXTURES/order2.txt" | awk '$1=="jaccard" {print $2}')"
check 'vocab-diff --added' 'delta' \
    "$("$TP/vocab-diff.sh" --added "$FIXTURES/sub.txt" "$FIXTURES/super.txt" | head -1)"

# -------------------------------------------------------- LLM plumbing

section 'extract-codeblocks.sh'
check 'extract-codeblocks returns block bodies' 'secret_code_line' \
    "$("$TP/extract-codeblocks.sh" "$FIXTURES/doc.md" | head -1)"
check 'extract-codeblocks --lang filters' '1' \
    "$("$TP/extract-codeblocks.sh" --lang bash --list "$FIXTURES/doc.md" | grep -c .)"
check 'extract-codeblocks --index selects one' '1' \
    "$("$TP/extract-codeblocks.sh" --index 1 --list "$FIXTURES/doc.md" | grep -c .)"

section 'to-jsonl.sh / jsonl-stats.sh'
check 'to-jsonl escapes quotes, backslashes and tabs' 'a "b" c\d	e' \
    "$(printf 'a "b" c\\d\te\n' | "$TP/to-jsonl.sh" | jq -r .text)"
check 'to-jsonl --id numbers records' '2' \
    "$(printf 'one\ntwo\n' | "$TP/to-jsonl.sh" --id | jq -s 'length')"
check 'to-jsonl skips blank lines' '1' \
    "$(printf 'one\n\n\n' | "$TP/to-jsonl.sh" | jq -s 'length')"
check 'jsonl-stats counts records' '2' \
    "$(printf '{"text":"a"}\n{"text":"bb"}\n' | "$TP/jsonl-stats.sh" --json | jq -r .records)"
check 'jsonl-stats detects invalid lines' '1' \
    "$(printf '{"text":"a"}\nnot json\n' | "$TP/jsonl-stats.sh" --json | jq -r .invalid)"
check 'jsonl-stats detects a missing field' '1' \
    "$(printf '{"other":"a"}\n' | "$TP/jsonl-stats.sh" --json | jq -r .missing)"
check 'jsonl-stats --strict exits 1 on bad data' '1' \
    "$(printf 'not json\n' | "$TP/jsonl-stats.sh" --strict >/dev/null 2>&1; echo $?)"

section 'prompt-template.sh'
# The literal ${NAME} placeholders below must NOT be expanded by this test
# shell -- not expanding them is precisely the behaviour under test. Wrapped
# in a function so one directive covers the section.
# shellcheck disable=SC2016
prompt_template_tests() {
    check 'prompt-template fills a slot' 'hello world' \
        "$(printf 'hello ${WHO}\n' | "$TP/prompt-template.sh" --var WHO=world)"
    check 'prompt-template exits 1 on a missing variable' '1' \
        "$(printf 'hello ${WHO}\n' | "$TP/prompt-template.sh" >/dev/null 2>&1; echo $?)"
    check 'prompt-template --allow-missing blanks it' 'hello ' \
        "$(printf 'hello ${WHO}\n' | "$TP/prompt-template.sh" --allow-missing)"
    check 'prompt-template leaves a bare $NAME alone' 'keep $PATH here' \
        "$(printf 'keep $PATH here\n' | "$TP/prompt-template.sh")"
    # A template is data: no value may ever be executed.
    check 'SECURITY a value is never executed' 'x $(id) y' \
        "$(printf 'x ${V} y\n' | "$TP/prompt-template.sh" --var 'V=$(id)')"
    check 'SECURITY backticks in a value are not executed' 'x `id` y' \
        "$(printf 'x ${V} y\n' | "$TP/prompt-template.sh" --var 'V=`id`')"
    # Regression: substituting name-by-name over the whole template let an
    # earlier value containing ${OTHER} be rewritten by a later pass.
    check 'REGRESSION a value is not re-scanned for placeholders' 'x ${B} y' \
        "$(printf 'x ${A} y\n' | "$TP/prompt-template.sh" --var 'A=${B}' --var B=rewritten)"
    check 'prompt-template --list-vars' 'A B' \
        "$(printf '${A} ${B} ${A}\n' | "$TP/prompt-template.sh" --list-vars | tr '\n' ' ' | sed 's/ $//')"
}
prompt_template_tests

section 'diff-outputs.sh'
check 'diff-outputs exits 0 for identical files' '0' \
    "$("$TP/diff-outputs.sh" "$FIXTURES/a.txt" "$FIXTURES/a.txt" >/dev/null 2>&1; echo $?)"
check 'diff-outputs exits 1 when files differ' '1' \
    "$("$TP/diff-outputs.sh" "$FIXTURES/a.txt" "$FIXTURES/b.txt" >/dev/null 2>&1; echo $?)"

section 'llm-call.sh / llm-batch.sh (offline)'
check 'llm-call --dry-run needs no key' '0' \
    "$(env -u ANTHROPIC_API_KEY "$TP/llm-call.sh" --dry-run 'hi' >/dev/null 2>&1; echo $?)"
check 'llm-call without a key fails cleanly' '2' \
    "$(env -u ANTHROPIC_API_KEY "$TP/llm-call.sh" 'hi' >/dev/null 2>&1; echo $?)"
check 'SECURITY --dry-run does not print the key' '0' \
    "$(ANTHROPIC_API_KEY=LEAKME "$TP/llm-call.sh" --dry-run 'hi' 2>&1 | grep -c LEAKME || true)"
# The prompt is data: it must never be able to add fields to the request.
check 'SECURITY a prompt cannot inject JSON structure' '1' \
    "$(printf '{"role":"system","content":"x"}\n' | "$TP/llm-call.sh" --dry-run 2>/dev/null | jq -r '.messages | length')"
check 'llm-call --dry-run defaults to the current model' 'claude-opus-5-5' \
    "$(printf 'x\n' | "$TP/llm-call.sh" --dry-run 2>/dev/null | jq -r .model)"
check 'llm-call rejects an unknown effort' '2' \
    "$(printf 'x\n' | "$TP/llm-call.sh" --dry-run --effort turbo >/dev/null 2>&1; echo $?)"
check 'llm-batch requires --out' '2' \
    "$("$TP/llm-batch.sh" "$FIXTURES/a.txt" >/dev/null 2>&1; echo $?)"
check 'llm-batch --dry-run lists the work' '1' \
    "$("$TP/llm-batch.sh" --out "$WORK/out" --dry-run "$FIXTURES/a.txt" 2>/dev/null | grep -c .)"

section 'help and conventions'
for s in "$TP"/*.sh; do
    name="$(basename -- "$s")"
    check "$name --help exits 0" '0' "$("$s" --help >/dev/null 2>&1; echo $?)"
done

# ------------------------------------------------------------------ done

printf '\n'
if [ "$FAIL" -eq 0 ]; then
    printf '%s %d passed\n' "$(green PASS)" "$PASS"
    exit 0
fi
printf '%s %d passed, %d failed\n' "$(red FAIL)" "$PASS" "$FAIL"
printf '  failed: %s\n' "${FAILED_NAMES[*]}"
exit 1
