# Text Processing Collection

A set of composable shell scripts for text and corpus work, built around one
idea: **every stage of a modern GenAI preprocessing pipeline has a `tr` / `sed`
/ `awk` equivalent.** Tokenizing, chunking, deduplicating, scoring terms by
rarity — these are Unix pipeline problems that predate the models by decades.

This collection is the generalisation of [`singleline.sh`](./singleline.md),
which already demonstrated word-frequency counting with
`tr -cs | sort | uniq -c | sort -nr`.

> **Note on structure.** The rest of `docs/` uses one page per script. This
> collection is documented on a single page instead: each script's own
> `--help` is complete and authoritative, so 23 near-duplicate pages would
> add maintenance burden without adding information. Use this page for the
> concepts and the pipeline view, and `--help` for exact flags.

---

## Conventions

These hold for every script in `text-processing/`:

| Convention | Detail |
|---|---|
| Input | A `FILE` argument, or stdin when `FILE` is omitted or `-` |
| Output | stdout; diagnostics and counters go to stderr |
| Help | `-h` / `--help` on every script, and it is complete |
| Option order | Options come **before** the file argument (`llm-call.sh` accepts either order) |
| Shell | `#!/usr/bin/env bash` with `set -euo pipefail` |
| Exit codes | `0` success · `1` meaningful negative result · `2` usage or runtime error · `3` API failure (`llm-call.sh`) |

Exit code `1` is deliberately a *result*, not an error, so the scripts can
gate CI directly:

```bash
./pii-redact.sh --check doc.md            # 1 = sensitive data present
./token-estimate.sh --budget 8000 p.txt   # 1 = will not fit
./jsonl-stats.sh --strict data.jsonl      # 1 = malformed records
./diff-outputs.sh before.txt after.txt    # 1 = output changed
```

**Two input shapes.** Statistics scripts (`ngrams`, `lexical-stats`, `tfidf`,
`zipf`, `similarity`, `vocab-diff`) take **raw text** and tokenize internally.
Pure filters (`stopwords`, `dedup`) take **one token or record per line** and
compose with `tokenize.sh`.

### Requirements

- bash 4+, and the usual coreutils (`tr`, `sed`, `sort`, `uniq`, `comm`,
  `paste`, `grep`, `awk`)
- `jq` — required by `to-jsonl.sh`, `jsonl-stats.sh`, `llm-call.sh`,
  `llm-batch.sh`, and by `--format jsonl` anywhere
- `git` — required by `diff-outputs.sh` (for word-level diff)
- `curl` — required by `llm-call.sh`

Scripts check their own dependencies and fail with a clear message.

---

## Quick start

```bash
chmod +x text-processing/*.sh
text-processing/pipeline-demo.sh          # the whole collection, no API key
cat text-processing/MANIFEST              # one line per script
text-processing/chunk-text.sh --help      # details for any one of them
```

---

## 1. Corpus hygiene

Markup, inconsistent punctuation and stray credentials all degrade everything
downstream. Clean first.

### `pii-redact.sh` — mask personal data and credentials

The most important script here. Run it before text leaves the machine.

```bash
./pii-redact.sh notes.txt                   # mask everything
./pii-redact.sh --except urls notes.txt     # keep URLs
./pii-redact.sh --check notes.txt           # exit 1 if anything found
./pii-redact.sh --stats notes.txt           # per-category counts on stderr
```

Categories, applied in this order: `keys` (PEM blocks), `jwt`, `aws`, `urls`,
`emails`, `ssn`, `phones`, `cards`, `ips`. Order matters — key blocks collapse
first so later rules cannot leak a fragment, and URLs are masked before emails
so a `user@host` URL is masked as a whole.

> **This is a safety net, not a guarantee.** Regexes cannot find names, postal
> addresses, free-form account numbers or novel key formats. A clean run is
> **not** proof that a document is safe to publish.

### `normalize-text.sh` — canonicalise messy text

`don't` and `don’t` are different tokens to a tokenizer, and a word hyphenated
across a PDF line break is two useless ones.

```bash
pdftotext report.pdf - | ./normalize-text.sh --squeeze-blank
```

Steps: strip control characters → map Unicode punctuation and exotic spaces to
ASCII → rejoin hyphenated line breaks → trim and collapse whitespace.

The Unicode rules use alternation (`a|b`), not bracket expressions (`[ab]`),
because a bracket expression is matched **byte by byte** unless the locale is
UTF-8 — which would split a multi-byte character and emit one replacement per
byte. Pass `--no-dehyphenate` to stream instead of buffering the whole input.

### `strip-markup.sh` — HTML or Markdown to prose

```bash
./strip-markup.sh page.html
./strip-markup.sh --markdown README.md | ./token-estimate.sh
```

Auto-detects by extension, then by sniffing. Underscores inside a word are
left alone, so `snake_case` identifiers survive rather than being read as
emphasis.

---

## 2. Tokenization and sizing

### `tokenize.sh` — one unit per line

```bash
./tokenize.sh --words --lower --count notes.txt | head -20
./tokenize.sh --sentences notes.txt
./tokenize.sh --paragraphs notes.txt
./tokenize.sh --chars notes.txt
```

`--words` uses `tr -cs '[:alnum:]' '\n'`, where `-s` squeezes repeats so no
empty-line cleanup pass is needed. `--count` gives the `singleline.sh`
behaviour as a reusable tool.

### `token-estimate.sh` — tokens, cost, context budget

```bash
./token-estimate.sh corpus/*.txt
./token-estimate.sh --budget 8000 prompt.txt || echo "too big"
./token-estimate.sh --price-per-mtok 3.00 --json corpus/*.txt
```

> **The `chars/4` heuristic is approximate.** Real byte-pair encoders vary by
> 20% or more on source code, JSON and non-English text, and every provider
> tokenizes differently. Use it for sizing and CI guards, never for billing
> reconciliation or a hard context-window limit where being wrong by 20%
> matters. Override the divisor with `--chars-per-token`.

---

## 3. Vocabulary statistics

### `stopwords.sh`

A line filter over a token stream. Matching is **whole-line and literal**
(`grep -x -F`), so the stopword `a` cannot remove `apple`.

```bash
./tokenize.sh --words --lower notes.txt | ./stopwords.sh | sort | uniq -c
./tokenize.sh --words --lower notes.txt | ./stopwords.sh --invert   # inspect
```

Ships with `data/stopwords-en.txt` (146 entries); override with `--list FILE`.

### `ngrams.sh` — collocation extraction

```bash
./ngrams.sh -n 2 --top 20 notes.txt
./ngrams.sh -n 3 --stopwords notes.txt
```

The implementation is the `paste` shift trick: paste the token stream against
copies of itself offset by one line, so column *k* holds the *k*-th word of
each n-gram. Incomplete trailing n-grams are dropped by requiring exactly *n*
fields. This is the signal behind phrase detection and byte-pair merge tables.

### `lexical-stats.sh`

```bash
./lexical-stats.sh notes.txt
./lexical-stats.sh --json notes.txt | jq .ttr
```

Reports tokens, types, type/token ratio, hapax count and share, mean word
length, sentence count and mean sentence length. A **low TTR** on generated
text means the model is looping; a **very high hapax share** on scraped text
usually means tokenization is broken (every URL counted as a fresh word).

### `tfidf.sh` — retrieval scoring

```bash
./tfidf.sh corpus/*.txt
./tfidf.sh --per-doc --top 5 --dir corpus
```

`idf = log(N/df)`, natural log, so a term present in **every** document scores
exactly `0` — it narrows nothing. This is what a vector database replaces
rather than invents. Needs at least two documents.

### `kwic.sh` — keyword in context

```bash
./kwic.sh data notes.txt
./kwic.sh --window 8 --ignore-case machine notes.txt
./kwic.sh --regex 'colou?r' notes.txt
```

Patterns are **literal by default** (metacharacters escaped); pass `--regex`
to opt in. `--slurp` lets context cross line breaks, at the cost of line
numbers. The quickest demonstration of why keyword matching is not enough: it
finds "bank" in both senses and cannot tell them apart.

### `zipf.sh`

```bash
./zipf.sh --top 15 notes.txt
```

In natural language the *n*-th most common word appears about `1/n` as often
as the most common. Real prose tracks that closely; a corpus that does not
usually has repeated boilerplate, a broken tokenizer, or machine-generated
filler.

---

## 4. Chunking for retrieval

### `chunk-text.sh` — sentence-aligned chunks with overlap

```bash
./chunk-text.sh --max-words 200 --overlap 1 report.txt
./chunk-text.sh --format jsonl report.txt > chunks.jsonl
```

What a retrieval pipeline's text splitter does: cut a document into pieces
small enough to embed, never mid-sentence, with consecutive pieces overlapping
so a fact spanning a boundary survives in at least one of them.

Two guarantees worth knowing, because the naive implementation fails both:

- A sentence **longer** than `--max-words` is emitted as its own oversized
  chunk rather than split or dropped. The naive loop adds nothing, never
  advances, and spins forever.
- `--overlap` larger than the chunk never steps back to where it started.
  Progress is guaranteed for every input.

Formats: `text` (default), `tsv`, `jsonl`. Tabs inside the text become spaces
so `tsv` and `jsonl` stay unambiguous.

### `chunk-markdown.sh` — structure-aware chunks

```bash
./chunk-markdown.sh README.md
./chunk-markdown.sh --level 2 --max-words 150 --format jsonl README.md
```

One chunk per section, each labelled with its heading path
(`Guide > Setup > Docker`) — exactly the metadata a retrieval answer needs in
order to cite where it found something.

Only ATX headings anchored at the start of a line are recognised, and fenced
code blocks are tracked, so `C#`, `issue #42` and a `#` comment inside a code
fence are **not** mistaken for headings. `--max-words` delegates to
`chunk-text.sh` rather than reimplementing the sentence arithmetic.

---

## 5. Deduplication and similarity

### `dedup.sh`

```bash
./dedup.sh records.txt                                      # order-preserving
./dedup.sh --ignore-case --normalize-space --count records.txt
./dedup.sh --only-duplicates records.txt                    # what repeats
```

Default mode is `awk '!seen[$0]++'`: keeps the first copy and holds distinct
keys in memory. For inputs too large for that, `--sort` uses `sort -u` and
needs no seen-set. Deduplicating a corpus is one of the highest-value
preprocessing steps there is — duplicates waste context, skew term statistics
and over-weight whatever was repeated.

### `similarity.sh`

```bash
./similarity.sh a.txt b.txt
./similarity.sh --shingles 5 --json a.txt b.txt
```

Reports `jaccard` (shared / union) and `containment` (shared / smaller side).
Containment catches what Jaccard understates: a short document fully contained
in a long one scores low on Jaccard but `1.00` on containment.

`--shingles N` compares overlapping *N*-word shingles instead of bare words,
which makes it **order-sensitive** — the basis of near-duplicate detection.
Two documents with identical vocabulary in a different order score `1.00` on
words and `0.00` on 3-word shingles.

### `vocab-diff.sh`

```bash
./vocab-diff.sh v1.txt v2.txt              # "+ added" / "- removed"
./vocab-diff.sh --added v1.txt v2.txt | ./stopwords.sh
./vocab-diff.sh --summary v1.txt v2.txt
```

`comm`-based set operations for drift checks.

---

## 6. LLM input and output

### `extract-codeblocks.sh`

```bash
./extract-codeblocks.sh answer.md
./extract-codeblocks.sh --lang bash --list answer.md
./extract-codeblocks.sh --out ./blocks answer.md
```

Both ``` and `~~~` fences are recognised; `--out` names each file by the
block's language.

> **Extracting code is not vetting it.** Never pipe this output straight into
> a shell or an interpreter. Read it first.

### `to-jsonl.sh`

```bash
./to-jsonl.sh --mode sentences notes.txt > records.jsonl
./chunk-text.sh --format tsv notes.txt | cut -f4 | ./to-jsonl.sh --id
```

Escaping is delegated to `jq -R`, which is the entire point: hand-built JSON
breaks the moment the text contains a quote, a backslash, a tab or a control
character, and that breakage is silent until something downstream rejects the
file.

### `jsonl-stats.sh`

```bash
./jsonl-stats.sh records.jsonl
./jsonl-stats.sh --field prompt --strict records.jsonl
```

Run this before paying to embed or fine-tune. It catches the two problems that
matter: records that are not valid JSON, and a length distribution whose tail
will be silently truncated by a context window.

### `prompt-template.sh`

```bash
./prompt-template.sh --var TOPIC=chunking --var TONE=brief tpl.txt
TOPIC=chunking TONE=brief ./prompt-template.sh tpl.txt
./prompt-template.sh --list-vars tpl.txt
```

Security and correctness properties:

- Substitution uses bash parameter expansion, **never `eval`** and never a
  here-doc. A value containing `$(id)` or backticks is inserted literally.
- **Missing variables are an error** (exit 1), because a silently blank slot
  produces a prompt that looks fine and means something else. `--allow-missing`
  opts out.
- Substitution is **single-pass**: a value containing `${OTHER}` is final the
  moment it is appended and is never re-scanned, so one value cannot pull in
  another variable.
- Only `${NAME}` is recognised. A bare `$NAME` is left alone, so prose and
  shell snippets inside a template survive.

### `diff-outputs.sh`

```bash
./diff-outputs.sh before.txt after.txt
./diff-outputs.sh --sentences --similarity before.txt after.txt
```

Word-level diff via `git diff --word-diff`. A line diff is close to useless
for prose, because rewrapping one paragraph marks every line as changed. Exits
`1` when the files differ, mirroring `diff(1)`, so it can gate a regression
test directly.

---

## 7. Calling a model

### `llm-call.sh`

```bash
export ANTHROPIC_API_KEY=...
./llm-call.sh "Summarise this" --file notes.txt
./llm-call.sh --redact --file notes.txt --stream
./llm-call.sh --dry-run "test"            # prints the request, sends nothing
```

**Security properties — the reason this exists rather than a bare `curl` in
your shell history:**

1. The API key is read from the **environment only**, never from an argument.
   A process's argv is world-readable on Linux (`/proc/PID/cmdline`), so a key
   on a command line leaks to every local user and into shell history.
2. The key reaches curl through a `0600` config file in a `0700` temporary
   directory, so it never appears in **curl's own argv** either. The
   trade-off: the key touches the filesystem briefly instead of process
   memory. A short-lived private file beats world-readable argv.
3. The request body is built with `jq`, never by string interpolation, so
   quotes, newlines and backslashes in the prompt cannot break out of the JSON
   or inject fields.
4. The key is never echoed — not even by `--dry-run`, which reads no
   credentials at all.
5. `--redact` runs the input through `pii-redact.sh` before sending.

Other behaviour: retries 429 and 5xx with exponential backoff, honouring
`Retry-After` when present; a policy decline arrives as HTTP 200 with
`stop_reason: "refusal"` and exits `1` (the status code alone is not enough to
know a call produced an answer); the server-side refusal fallback is enabled
by default, so a decline is retried on a fallback model inside the same call
(`--no-fallbacks` to disable). Thinking is on by default on current models and
is not configurable here — control depth with `--effort`.

### `llm-batch.sh`

```bash
./llm-batch.sh --out answers --system "Summarise in one line" notes/*.txt
./llm-batch.sh --out answers --dir notes --jobs 2 --redact
```

Three properties that matter when a batch costs real money:

- **Resumable** — a file whose output already exists is skipped, so an
  interrupted run restarts by re-running the same command (`--force` to
  override).
- **Rate-limit aware** — concurrency is 1 by default with a configurable
  delay between launches; `llm-call.sh` handles 429 backoff.
- **Accountable** — every input gets a row in `manifest.tsv` with its exit
  status, so a partial failure is visible instead of silent.

---

## Composing them

The scripts are deliberately small and chainable:

```bash
# Full document-ingestion pipeline
./pii-redact.sh doc.md \
  | ./normalize-text.sh --squeeze-blank \
  | ./strip-markup.sh --markdown \
  | ./chunk-text.sh --max-words 200 --overlap 1 --format jsonl \
  > chunks.jsonl

# Top content phrases, stopwords removed
./strip-markup.sh --markdown README.md | ./ngrams.sh -n 2 --stopwords --top 20

# Will this prompt fit, and what will it cost?
./prompt-template.sh --var TOPIC=x tpl.txt \
  | ./token-estimate.sh --budget 8000 --price-per-mtok 3.00

# Gate a commit on no secrets leaking into docs
./pii-redact.sh --check docs/*.md || { echo "sensitive data found"; exit 1; }
```

`pipeline-demo.sh` runs a version of the first chain end to end, with
commentary and no API key.

---

## Where these are useful

Every scenario below was run against real input while writing this page; the
numbers shown are what the scripts printed.

| Use | Fit |
|---|---|
| Safety gates in git hooks and CI | Strong |
| Cost and size control before a model call | Strong |
| Checking LLM output (loops, code, regressions) | Strong |
| Document and dataset pipelines (RAG, fine-tune prep, eval sets) | Strong |
| Analysing text you already have (logs, tickets, docs) | Good |
| Pieces of a code-development CLI | Partial (see [below](#building-a-cli-around-these)) |
| Chunking source code | **Not a fit** |
| Meaning-level similarity or semantic search | **Not a fit** |
| Non-English text in the word-level scripts | **Not a fit yet** ([limitations](#known-limitations)) |

### Safety gates

**Block a commit that contains a secret.** `--check` exits `1` on findings, so
it works as a git hook with no wrapper. This scans only the lines being
committed, and prints the findings only when it blocks:

```bash
#!/usr/bin/env bash
# .git/hooks/pre-commit
if ! report=$(git diff --cached --diff-filter=ACM -U0 \
      | grep '^+' | grep -v '^+++' \
      | text-processing/pii-redact.sh --check 2>&1 >/dev/null); then
    printf '%s\n' "$report" >&2
    echo "commit blocked: staged changes contain sensitive data" >&2
    exit 1
fi
```

A staged JWT produced `jwt 1 / total 1 finding(s) / commit blocked` and exit
`1`; a clean commit was silent and allowed. The same one-liner works as a CI
step over documentation: `pii-redact.sh --check docs/*.md`.

**Scrub before anything leaves the machine.** `llm-call.sh --redact` runs the
prompt through `pii-redact.sh` first. The same applies to logs pasted into a
bug report or a chat window.

### Cost and size control

**Skip the model call when the input will not fit.** A failed `--budget` is a
real exit code, so it stops the pipeline:

```bash
tmp=$(mktemp)
pii-redact.sh big.txt > "$tmp"
if token-estimate.sh --budget 6000 "$tmp"; then
    llm-call.sh "Summarise this" --file "$tmp"
else
    echo "over budget: chunk it first" >&2
fi
rm -f "$tmp"
```

**Price a bulk job before running it.**
`token-estimate.sh --price-per-mtok 3.00 corpus/*.txt` prints a per-file and
total estimate, so the cost of `llm-batch.sh` is known in advance.

**Generate a PR description from a diff.** Redact, check the budget, build the
request, and use `--dry-run` to inspect it without sending anything:

```bash
git diff --cached | pii-redact.sh | llm-call.sh --dry-run \
    --system 'Write a PR description.'
```

### Checking model output

**Detect a repetition loop.** `lexical-stats.sh` reports the type/token ratio
(distinct words ÷ total words). A model stuck repeating itself scores very low:

| Text | Tokens | TTR |
|---|---|---|
| "I am happy to help with that." repeated 30 times | 210 | **0.0333** |
| One normal sentence | 19 | **0.8947** |

TTR falls naturally as text gets longer, so compare outputs of similar length
rather than applying one fixed threshold.

**Lint a model's code before running it.** `extract-codeblocks.sh` pulls out
the code, and a linter judges it. For the answer `for f in $(ls *.txt); do
echo $f; done`, shellcheck flagged `SC2045 (error): Iterating over ls output is
fragile`:

```bash
extract-codeblocks.sh --lang bash answer.md > block.sh
shellcheck -s bash block.sh        # read the verdict, then decide
```

Extracted code is untrusted. Linting it is a first filter, not a safety proof.

**Did changing the model or the prompt change the answer?** `diff-outputs.sh`
exits `1` when outputs differ and `0` when identical, so it gates a regression
test directly. On two answers differing only in `10→20` and `30→60`, it showed
the changes inline (`[-10.-]{+20.+}`) and `--similarity` reported jaccard
`0.7647`. This is worth running whenever you switch models.

**Validate a dataset in CI.** `jsonl-stats.sh --strict data.jsonl` exits `1` on
any malformed record or missing field, before you pay to embed or train on it.

### Analysing text you already have

**Log triage: what repeats most.** `dedup.sh --only-duplicates app.log` printed
`3 ERROR db timeout on shard-3` and `2 INFO request ok`. Plain `dedup.sh`
collapses the log to its distinct lines in their original order, and adding
`| grep -v INFO` leaves just the distinct problems.

**Support tickets: recurring complaints.** `ngrams.sh -n 2 --stopwords` over
five tickets put `export button` first with a count of 3, ahead of every
one-off phrase.

**Documentation: terminology consistency.** `kwic.sh 'log in'` against
`kwic.sh 'login'` shows every use of each form with surrounding words, which
exposes places where the verb and the noun are mixed up.

**Documentation: what changed between versions.** `vocab-diff.sh v1.md v2.md`
listed `+ pipx`, `+ async`, `- pip`. Numbers are split on the dot, so
`3.9 → 3.12` appears as `- 9` and `+ 12`.

**Near-duplicate content.** `similarity.sh --shingles 5 a.txt b.txt` compares
5-word sequences, so it finds copied passages rather than documents that merely
share vocabulary. Two texts with the same words in a different order score
`1.00` on words and `0.00` on 3-word shingles.

**A quick smell test for a corpus.** `zipf.sh` and `lexical-stats.sh` show
quickly whether a scraped corpus is natural language or mostly repeated
boilerplate.

### Building a CLI around these

If you are building a code-development or file-processing tool, treat the
scripts as a **reference implementation and a set of CI steps**, not as the
engine. In a Go, Python or Node tool, every call forks a process, Windows
support is awkward, and errors across a pipe are hard to handle.

| Script | In a CLI |
|---|---|
| `pii-redact.sh` | Port the patterns; keep `--check` as a git hook or CI step as-is |
| `token-estimate.sh` | Port (it is a few lines); the `--budget` exit-code contract is the useful part |
| `extract-codeblocks.sh` | Port; the fence-toggling logic is simple |
| `prompt-template.sh` | Port the single-pass, no-`eval`, missing-is-an-error behaviour |
| `diff-outputs.sh` | Use as a CI step for prompt regression |
| `llm-batch.sh` | Copy the pattern: resumable, per-item manifest, skip what is done |
| `ngrams` `tfidf` `zipf` `lexical-stats` `stopwords` | Skip: language-analysis tools, not code tools |

Port the logic and keep `tests/run-tests.sh` as the specification: 113
assertions pin the behaviour, including the edge cases a fresh implementation
tends to get wrong.

The conventions are what transfer regardless of language:

- **Exit `1` means "a result", not "a crash"**: over budget, secret found,
  output changed. That is what makes a tool scriptable.
- **A `--dry-run` that reads no credentials**, so anyone can inspect what
  would be sent.
- **Build JSON with a serializer**, never by joining strings; the failure is
  silent until the first quote character.
- **Secrets from the environment, never from arguments.** Command lines are
  readable by other local users through `/proc`.
- **A manifest with per-item status** on any batch operation, so a partial
  failure is visible.

### Where these are not a fit

**Chunking source code.** The chunkers split on sentences and Markdown
headings. Code has neither. Run on a Python file, `chunk-text.sh` put a
method's signature in one chunk and its body in the next, and `tokenize.sh
--words` split `get_user_by_id` into `get`, `user`, `by`, `id` while leaving
`computeTotalPrice` whole. Embedding half a function returns half a function.
Code needs syntax-aware chunking at function and class boundaries, from a
parser such as tree-sitter.

**Meaning-level similarity.** `similarity.sh` compares words. "car" and
"automobile" share nothing, so they score `0`. Use embeddings when meaning
matters; use this when you want exact and near-exact overlap.

**Very large inputs.** `normalize-text.sh` reads its whole input into memory
(use `--no-dehyphenate` to stream), and `dedup.sh` holds every distinct line in
memory (use `--sort` instead).

---

## Using these from an AI coding assistant

`.claude/skills/text-processing/SKILL.md` registers the collection as a skill
so an assistant prefers these verified scripts over writing a fresh one-liner.

The mechanism matters more than the scripts. A skill keeps only its name and
description resident (~170 tokens) and loads the body on demand, whereas
pasting a full catalogue into `CLAUDE.md` would cost ~1,750 tokens on **every
turn of every conversation** in the repository — including the ones that never
touch text processing.

The direct saving per call is small (roughly 11 tokens on a simple one-liner,
70 on a complex one). The real saving is **avoided failure cycles**: a wrong
one-liner costs an error, a diagnosis and a corrected rewrite, which measured
around 250 tokens per round. The scripts do not save tokens by being shorter;
they save tokens by not being wrong.

Keep each script's `--help` short and accurate. The failure mode is an
assistant reading a script's source to learn its flags — 300+ tokens, instantly
worse than writing the one-liner it was avoiding.

---

## Known limitations

**The word-level scripts do not handle non-ASCII text.** They share one
tokenizer, built on `tr -cs '[:alnum:]'`, and GNU `tr` works on bytes. Accented
letters are treated as separators and scripts without them are dropped:

| Input | Tokenizer output |
|---|---|
| `café naïve résumé` | `caf` `na` `ve` `r` `sum` |
| `こんにちは 世界` | nothing |
| `Привет мир` | nothing |

This was confirmed with no locale set and with `LC_ALL=C.utf8`, so setting a
locale does not fix it. Affected, because they call the shared tokenizer:
`tokenize.sh --words`, `ngrams.sh`, `lexical-stats.sh`, `tfidf.sh`, `zipf.sh`,
`similarity.sh` and `vocab-diff.sh`. Most return empty or truncated results
silently; `lexical-stats.sh` at least says `no tokens found`.

Unaffected, because they work on lines, sentences or whole documents rather
than words: `kwic.sh` (found `мир` correctly), `dedup.sh`, `chunk-text.sh`,
`chunk-markdown.sh`, `pii-redact.sh`, `normalize-text.sh`, `strip-markup.sh`,
`extract-codeblocks.sh`, `to-jsonl.sh`, `prompt-template.sh`,
`diff-outputs.sh` and `llm-call.sh`.

**Token estimates count bytes, not characters.** `token-estimate.sh` uses
`wc -c`, so non-ASCII text is overestimated: `こんにちは` (5 characters, 16
bytes with the newline) came out as 4 tokens. `jsonl-stats.sh` counts
characters through `jq`, so the two scripts disagree on the same text. Even for
English the `chars/4` rule is only a heuristic: real tokenizers vary by 20% or
more on code and non-English text.

**PII patterns are US-centric.** The phone and SSN formats are US-style, and
only IPv4 addresses are recognised. Names, postal addresses and novel key
formats are not detectable by pattern at all, so a clean result is not proof a
document is safe to publish.

**Options come before the file argument** in every script except
`llm-call.sh`, which accepts either order.

---

## Testing

```bash
tests/run-tests.sh              # 113 assertions, no network, no API key
tests/run-tests.sh chunk        # only tests matching "chunk"
cd text-processing && shellcheck -x -S style ./*.sh lib/common.sh
```

Run from inside `text-processing/` so the `# shellcheck source=lib/common.sh`
directives resolve; `-x` makes shellcheck follow the sourced library.

Many assertions are regression tests for bugs found while building the
collection, and each names the bug it guards:

| Guard | Bug it prevents |
|---|---|
| stdin path works at all | A temp dir created inside a command substitution was deleted by the subshell's own `EXIT` trap before it could be written |
| smart quotes are not byte-mangled | A `[byte-class]` sed rule split multi-byte UTF-8 and emitted one replacement per byte |
| oversized sentence terminates | A sentence longer than `--max-words` added no words, so the splitter never advanced |
| overlap larger than chunk terminates | Overlap could step back to where the previous chunk started |
| a value is not re-scanned | Name-by-name substitution let one value's `${OTHER}` be rewritten by a later pass |
| `--json` escapes a hostile filename | Filenames were interpolated into JSON unescaped |
| `snake_case` survives | The `_italic_` rule ate underscores inside identifiers |
| a `#` inside prose or code is not a heading | `grep "#"` treats `C#`, `issue #42` and code comments as headings |

CI runs both jobs on every push and pull request
(`.github/workflows/shellcheck.yml`). The test job touches no network and
spends no money: `llm-call.sh` is exercised only through `--dry-run`.
