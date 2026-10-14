---
name: text-processing
description: Shell pipelines for text and corpus work in this repository - tokenize, count tokens and estimate cost, chunk documents for RAG, redact PII and secrets before sending text anywhere, n-grams, TF-IDF, keyword-in-context, deduplicate, measure document similarity, extract fenced code blocks from model output, build and validate JSONL datasets, fill prompt templates, and call the Claude API. Use when processing text or Markdown files, preparing input for an LLM, chunking documents, estimating token counts or cost, scrubbing sensitive data, or building a JSONL dataset - prefer these verified scripts over writing a new one-liner.
---

# Text processing scripts

`text-processing/` holds verified, shellcheck-clean scripts for text and
corpus work. Prefer them over writing a fresh pipeline: each one has been
tested against edge cases (empty input, oversized sentences, hostile
filenames, quotes and backslashes in JSON) that an ad-hoc one-liner usually
gets wrong.

## Finding the right one

Read `text-processing/MANIFEST` - one line per script, grouped by pipeline
stage. Then run `text-processing/<script>.sh --help` for its options. Do not
read a script's source to learn its interface; `--help` is complete.

## Conventions

- Every script reads a `FILE` argument or stdin, and writes to stdout.
- Options come before the file argument. `llm-call.sh` accepts either order.
- Statistics scripts (`ngrams`, `lexical-stats`, `tfidf`, `zipf`,
  `similarity`, `vocab-diff`) take raw text and tokenize internally.
- Filters (`stopwords`, `dedup`) take one token or record per line and
  compose with `tokenize.sh`.
- `--json` or `--format jsonl` is available where machine-readable output
  makes sense.
- Exit codes: 0 success, 1 a meaningful negative result (over budget, PII
  found, files differ, model declined), 2 usage or runtime error.

## The ones worth reaching for first

| Task | Script |
|---|---|
| "how many tokens is this" / will it fit | `token-estimate.sh --budget N` |
| scrub secrets before sending text out | `pii-redact.sh` (`--check` to gate CI) |
| split a document for embedding | `chunk-text.sh`, or `chunk-markdown.sh` for Markdown |
| get the code out of a model's answer | `extract-codeblocks.sh --lang bash` |
| build or check a JSONL dataset | `to-jsonl.sh`, `jsonl-stats.sh --strict` |
| are these two texts near-duplicates | `similarity.sh --shingles 5` |

## Caveats to repeat, not hide

- Token counts use the chars/4 heuristic over bytes. Real tokenizers vary by
  20% or more on code and non-English text. Fine for sizing, not for billing.
- The word-level scripts (`tokenize --words`, `ngrams`, `lexical-stats`,
  `tfidf`, `zipf`, `similarity`, `vocab-diff`) drop non-ASCII text: `café`
  becomes `caf`, and Japanese or Cyrillic yields nothing. Do not use them on
  non-English input.
- Do not use the chunkers on source code; they split on sentences and
  headings and cut functions in half. Code needs a parser.
- `pii-redact.sh` is regex-based. It cannot find names, addresses or novel
  key formats; a clean run is not proof a document is safe to publish.
- `extract-codeblocks.sh` output is untrusted. Never pipe it into a shell.

## Running the tests

`tests/run-tests.sh` covers the collection and needs no network or API key.
