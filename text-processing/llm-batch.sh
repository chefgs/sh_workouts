#!/usr/bin/env bash
#
# llm-batch.sh - run llm-call.sh over many files, politely and resumably.
#
# Three properties that matter when a batch costs real money:
#   * Resumable. A file whose output already exists is skipped, so an
#     interrupted run is restarted by re-running the same command.
#   * Rate-limit aware. Concurrency is 1 by default and there is a
#     configurable delay between launches; llm-call.sh handles 429 backoff.
#   * Accountable. Every input gets a row in a manifest with its exit status,
#     so a partial failure is visible instead of silent.
#
#   ./llm-batch.sh --out answers --system "Summarise in one line" notes/*.txt
#   ./llm-batch.sh --out answers --dir notes --jobs 2 --redact

set -euo pipefail
# shellcheck source=lib/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib/common.sh"

TP_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LLM_CALL="$TP_DIR/llm-call.sh"

usage() {
    cat <<'USAGE'
Usage: llm-batch.sh --out DIR [OPTIONS] FILE...
       llm-batch.sh --out DIR [OPTIONS] --dir INPUT_DIR

Run llm-call.sh once per input file, writing DIR/<name>.txt per answer
(the input's own extension is replaced, so notes.md yields notes.txt).

Required:
  --out DIR          directory for the answers and the manifest

Options:
  --dir INPUT_DIR    use every regular file directly inside INPUT_DIR
  --jobs N           run up to N calls concurrently (default 1)
  --delay SECONDS    wait between launches (default 1)
  --force            re-run inputs whose output already exists
  --dry-run          list what would run, call nothing
  -h, --help         show this help

Passed through to llm-call.sh:
  --system TEXT, --model ID, --max-tokens N, --effort LEVEL, --redact,
  --retries N, --timeout SECONDS

The manifest is DIR/manifest.tsv with columns: STATUS, EXIT, INPUT, OUTPUT.
Exit status: 0 all succeeded or were skipped, 1 at least one call failed,
2 usage or runtime error.
USAGE
}

out_dir=''
input_dir=''
jobs=1
delay=1
force=0
dry_run=0
passthrough=()
inputs=()

while [ $# -gt 0 ]; do
    case "$1" in
        --out)
            [ $# -ge 2 ] || die 'option --out needs a value'
            out_dir="$2"
            shift 2
            ;;
        --dir)
            [ $# -ge 2 ] || die 'option --dir needs a value'
            input_dir="$2"
            shift 2
            ;;
        --jobs)
            [ $# -ge 2 ] || die 'option --jobs needs a value'
            tp_require_int "$2" '--jobs'
            [ "$2" -ge 1 ] || die '--jobs must be at least 1'
            jobs="$2"
            shift 2
            ;;
        --delay)
            [ $# -ge 2 ] || die 'option --delay needs a value'
            tp_require_int "$2" '--delay'
            delay="$2"
            shift 2
            ;;
        --force) force=1; shift ;;
        --dry-run) dry_run=1; shift ;;
        --system | --model | --max-tokens | --effort | --retries | --timeout)
            [ $# -ge 2 ] || die "option $1 needs a value"
            passthrough+=("$1" "$2")
            shift 2
            ;;
        --redact)
            passthrough+=(--redact)
            shift
            ;;
        -h | --help) usage; exit 0 ;;
        --)
            shift
            while [ $# -gt 0 ]; do
                inputs+=("$1")
                shift
            done
            ;;
        -*) die "unknown option: $1 (try --help)" ;;
        *)
            inputs+=("$1")
            shift
            ;;
    esac
done

[ -n "$out_dir" ] || die 'option --out DIR is required (try --help)'
[ -x "$LLM_CALL" ] || die "llm-call.sh not found or not executable: $LLM_CALL"

if [ -n "$input_dir" ]; then
    [ ${#inputs[@]} -eq 0 ] || die 'pass either --dir or a list of files, not both'
    [ -d "$input_dir" ] || die "not a directory: $input_dir"
    for f in "$input_dir"/*; do
        if [ -f "$f" ]; then
            inputs+=("$f")
        fi
    done
fi
[ ${#inputs[@]} -gt 0 ] || die 'no input files (try --help)'

mkdir -p -- "$out_dir" || die "cannot create directory: $out_dir"
manifest="$out_dir/manifest.tsv"

if [ "$dry_run" -eq 1 ]; then
    printf 'would run %d call(s) with: llm-call.sh %s\n' \
        "${#inputs[@]}" "${passthrough[*]-}" >&2
    for f in "${inputs[@]}"; do
        base="$(basename -- "$f")"
        printf '%s\t->\t%s/%s.txt\n' "$f" "$out_dir" "${base%.*}"
    done
    exit 0
fi

printf 'STATUS\tEXIT\tINPUT\tOUTPUT\n' >"$manifest"

# One call. Runs in a subshell so a failure cannot abort the batch; the result
# row is appended by the parent after wait, keeping the manifest ordered.
run_one() {
    local src="$1" dest="$2" status_file="$3" rc=0
    if "$LLM_CALL" ${passthrough[@]+"${passthrough[@]}"} --file "$src" \
        >"$dest.partial" 2>"$dest.err"; then
        mv -- "$dest.partial" "$dest"
        printf 'ok\t0\n' >"$status_file"
        rm -f -- "$dest.err"
    else
        rc=$?
        rm -f -- "$dest.partial"
        printf 'failed\t%d\n' "$rc" >"$status_file"
    fi
}

tp_tmpdir
failures=0
skipped=0
launched=0
pids=()
slots=()

index=0
for src in "${inputs[@]}"; do
    base="$(basename -- "$src")"
    # Strip one extension so notes.txt becomes notes.txt, not notes.txt.txt.
    dest="$out_dir/${base%.*}.txt"
    if [ "$force" -eq 0 ] && [ -s "$dest" ]; then
        printf 'skipped\t0\t%s\t%s\n' "$src" "$dest" >>"$manifest"
        skipped=$((skipped + 1))
        continue
    fi

    # Hold at the concurrency limit before launching another call.
    while [ "$(jobs -rp | grep -c '' || true)" -ge "$jobs" ]; do
        sleep 0.2
    done

    slot="$TP_TMPDIR/slot.$index"
    printf '%s\t%s' "$src" "$dest" >"$TP_TMPDIR/meta.$index"
    run_one "$src" "$dest" "$slot" &
    pids+=("$!")
    slots+=("$slot")
    launched=$((launched + 1))
    index=$((index + 1))
    if [ "$delay" -gt 0 ]; then
        sleep "$delay"
    fi
done

# Collect every result and build the manifest rows in input order.
for i in "${!pids[@]}"; do
    wait "${pids[$i]}" 2>/dev/null || true
done
for i in "${!slots[@]}"; do
    line="$(cat -- "${slots[$i]}" 2>/dev/null || printf 'failed\t2\n')"
    meta="$(cat -- "$TP_TMPDIR/meta.$i" 2>/dev/null || printf '?\t?')"
    printf '%s\t%s\n' "$line" "$meta" >>"$manifest"
    case "$line" in
        failed*) failures=$((failures + 1)) ;;
    esac
done
printf 'batch complete: %d launched, %d skipped, %d failed\n' \
    "$launched" "$skipped" "$failures" >&2
printf 'manifest: %s\n' "$manifest" >&2

if [ "$failures" -gt 0 ]; then
    exit 1
fi
