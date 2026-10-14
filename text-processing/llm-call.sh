#!/usr/bin/env bash
#
# llm-call.sh - send text to the Claude Messages API from the shell.
#
# Security properties, which are the reason this script exists rather than a
# bare curl in your history:
#
#   1. The API key is read from the environment only, never from an argument.
#      A process's argv is world-readable on Linux (/proc/PID/cmdline), so a
#      key on a command line leaks to every local user and into shell history.
#   2. The key is passed to curl through a 0600 config file in a 0700
#      temporary directory, so it never appears in curl's own argv either.
#      (Trade-off: the key touches the filesystem briefly instead of process
#      memory. A short-lived private file beats world-readable argv.)
#   3. The request body is built with jq, never by string interpolation, so
#      quotes, newlines and backslashes in the prompt cannot break out of the
#      JSON or inject fields.
#   4. The key is never echoed, not even by --dry-run.
#   5. --redact runs the input through pii-redact.sh before it is sent.
#
#   ./llm-call.sh "Summarise this" --file notes.txt
#   ./llm-call.sh --redact --file notes.txt --stream
#   ./llm-call.sh --dry-run "test"

set -euo pipefail
# shellcheck source=lib/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib/common.sh"

TP_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

API_URL="${ANTHROPIC_API_URL:-https://api.anthropic.com/v1/messages}"
API_VERSION='2023-06-01'
DEFAULT_MODEL='claude-opus-5-5'

usage() {
    cat <<'USAGE'
Usage: llm-call.sh [OPTIONS] [PROMPT]

Send a prompt to the Claude Messages API and print the reply.

The prompt is taken from PROMPT, from --file, or from stdin. When both PROMPT
and --file are given, PROMPT acts as an instruction and the file is appended
below it.

Options:
  --file FILE        read the body of the prompt from FILE
  --system TEXT      set a system prompt
  --model ID         model id (default claude-opus-5-5)
  --max-tokens N     output cap (default 16000, or 64000 with --stream)
  --effort LEVEL     low | medium | high | xhigh | max (default medium)
  --stream           stream the reply as it is generated
  --show-thinking    ask for summarised reasoning as well as the answer
  --no-fallbacks     disable the server-side refusal fallback
  --redact           run the prompt through pii-redact.sh before sending
  --json             print the whole API response instead of just the text
  --usage            print token usage on stderr
  --timeout SECONDS  per-attempt timeout (default 600)
  --retries N        retries on 429 and 5xx (default 3, exponential backoff)
  --dry-run          print the request body and exit without calling the API
  -h, --help         show this help

Environment:
  ANTHROPIC_API_KEY  required (except with --dry-run)
  ANTHROPIC_API_URL  override the endpoint

Exit status: 0 ok, 1 the model declined (stop_reason refusal), 2 usage or
runtime error, 3 the API call failed after all retries.

Notes:
  * Thinking is on by default on current models and is not configurable here;
    control depth with --effort instead.
  * The server-side refusal fallback is enabled by default, so a policy
    decline is retried on a fallback model inside the same call. Pass
    --no-fallbacks to turn that off.
USAGE
}

prompt_text=''
prompt_file=''
system=''
model="$DEFAULT_MODEL"
max_tokens=''
effort='medium'
stream=0
show_thinking=0
fallbacks=1
redact=0
want_json=0
want_usage=0
timeout=600
retries=3
dry_run=0
positionals=()

# Unlike the other scripts in this directory, which expect their options
# before the file operand, this one accepts them in any order: a prompt and
# a --file are routinely given together and the natural way to type that is
# `llm-call.sh "instruction" --file notes.txt`.
while [ $# -gt 0 ]; do
    case "$1" in
        --file)
            [ $# -ge 2 ] || die 'option --file needs a value'
            prompt_file="$2"
            shift 2
            ;;
        --system)
            [ $# -ge 2 ] || die 'option --system needs a value'
            system="$2"
            shift 2
            ;;
        --model)
            [ $# -ge 2 ] || die 'option --model needs a value'
            model="$2"
            shift 2
            ;;
        --max-tokens)
            [ $# -ge 2 ] || die 'option --max-tokens needs a value'
            tp_require_int "$2" '--max-tokens'
            [ "$2" -ge 1 ] || die '--max-tokens must be at least 1'
            max_tokens="$2"
            shift 2
            ;;
        --effort)
            [ $# -ge 2 ] || die 'option --effort needs a value'
            case "$2" in
                low | medium | high | xhigh | max) effort="$2" ;;
                *) die "unknown effort: $2 (expected low, medium, high, xhigh or max)" ;;
            esac
            shift 2
            ;;
        --stream) stream=1; shift ;;
        --show-thinking) show_thinking=1; shift ;;
        --no-fallbacks) fallbacks=0; shift ;;
        --redact) redact=1; shift ;;
        --json) want_json=1; shift ;;
        --usage) want_usage=1; shift ;;
        --timeout)
            [ $# -ge 2 ] || die 'option --timeout needs a value'
            tp_require_int "$2" '--timeout'
            [ "$2" -ge 1 ] || die '--timeout must be at least 1'
            timeout="$2"
            shift 2
            ;;
        --retries)
            [ $# -ge 2 ] || die 'option --retries needs a value'
            tp_require_int "$2" '--retries'
            retries="$2"
            shift 2
            ;;
        --dry-run) dry_run=1; shift ;;
        -h | --help) usage; exit 0 ;;
        --)
            shift
            while [ $# -gt 0 ]; do
                positionals+=("$1")
                shift
            done
            ;;
        -*) die "unknown option: $1 (try --help)" ;;
        *)
            positionals+=("$1")
            shift
            ;;
    esac
done

if [ ${#positionals[@]} -gt 1 ]; then
    die 'expected at most one PROMPT argument'
fi
prompt_text="${positionals[0]:-}"
need_cmd curl jq

if [ -z "$max_tokens" ]; then
    if [ "$stream" -eq 1 ]; then max_tokens=64000; else max_tokens=16000; fi
fi

tp_tmpdir

# Assemble the prompt: instruction, then file or stdin content beneath it.
body_src="$TP_TMPDIR/prompt"
: >"$body_src"
if [ -n "$prompt_file" ]; then
    tp_input "$prompt_file"
    cat -- "$TP_INPUT" >>"$body_src"
elif [ -z "$prompt_text" ]; then
    # Nothing on the command line, so the prompt must be on stdin.
    tp_input '-'
    cat -- "$TP_INPUT" >>"$body_src"
fi

if [ "$redact" -eq 1 ]; then
    [ -x "$TP_DIR/pii-redact.sh" ] || die 'pii-redact.sh not found or not executable'
    "$TP_DIR/pii-redact.sh" "$body_src" >"$body_src.redacted"
    mv -- "$body_src.redacted" "$body_src"
fi

content="$TP_TMPDIR/content"
if [ -n "$prompt_text" ] && [ -s "$body_src" ]; then
    printf '%s\n\n' "$prompt_text" >"$content"
    cat -- "$body_src" >>"$content"
elif [ -n "$prompt_text" ]; then
    printf '%s\n' "$prompt_text" >"$content"
else
    cp -- "$body_src" "$content"
fi
[ -s "$content" ] || die 'the prompt is empty'

# Build the request with jq. --rawfile inserts the prompt as a JSON string
# with correct escaping; no amount of quoting or backslashes in the text can
# alter the structure of the request.
request="$TP_TMPDIR/request.json"
jq -n \
    --arg model "$model" \
    --argjson max_tokens "$max_tokens" \
    --arg effort "$effort" \
    --arg system "$system" \
    --rawfile content "$content" \
    --argjson stream "$stream" \
    --argjson show_thinking "$show_thinking" \
    --argjson fallbacks "$fallbacks" \
    '{
        model: $model,
        max_tokens: $max_tokens,
        output_config: { effort: $effort },
        messages: [ { role: "user", content: $content } ]
    }
    + (if $system != "" then { system: $system } else {} end)
    + (if $stream == 1 then { stream: true } else {} end)
    + (if $show_thinking == 1
       then { thinking: { type: "adaptive", display: "summarized" } }
       else {} end)
    + (if $fallbacks == 1 then { fallbacks: "default" } else {} end)' \
    >"$request"

if [ "$dry_run" -eq 1 ]; then
    jq . "$request"
    printf 'dry run: no request sent, no credentials read\n' >&2
    exit 0
fi

[ -n "${ANTHROPIC_API_KEY:-}" ] ||
    die 'ANTHROPIC_API_KEY is not set (export it; never pass a key as an argument)'

# Write curl's options to a private config file so that the key stays out of
# the process table. The temp dir is 0700; tighten the file to 0600 as well.
conf="$TP_TMPDIR/curl.conf"
umask 077
: >"$conf"
chmod 600 -- "$conf"
{
    printf 'url = "%s"\n' "$API_URL"
    printf 'header = "content-type: application/json"\n'
    printf 'header = "x-api-key: %s"\n' "$ANTHROPIC_API_KEY"
    printf 'header = "anthropic-version: %s"\n' "$API_VERSION"
    if [ "$fallbacks" -eq 1 ]; then
        printf 'header = "anthropic-beta: server-side-fallback-2026-07-01"\n'
    fi
    printf 'data-binary = "@%s"\n' "$request"
    printf 'max-time = %s\n' "$timeout"
    printf 'silent\nshow-error\n'
} >>"$conf"

if [ "$stream" -eq 1 ]; then
    # Server-sent events: pull the text deltas out of the data: lines.
    # jq -j concatenates without newlines so the text reads naturally.
    curl --config "$conf" --no-buffer |
        grep --line-buffered '^data: ' |
        sed -u 's/^data: //' |
        jq -j --unbuffered '
            if .type == "content_block_delta" and .delta.type == "text_delta"
            then .delta.text
            elif .type == "content_block_delta" and .delta.type == "thinking_delta"
            then .delta.thinking
            else empty end
        ' || true
    printf '\n'
    exit 0
fi

response="$TP_TMPDIR/response.json"
headers="$TP_TMPDIR/response.headers"
attempt=0
http_code=0

while :; do
    attempt=$((attempt + 1))
    http_code="$(curl --config "$conf" -o "$response" -D "$headers" -w '%{http_code}' || true)"

    case "$http_code" in
        200) break ;;
        408 | 409 | 429 | 5??)
            if [ "$attempt" -gt "$retries" ]; then
                warn "giving up after $attempt attempt(s), last status $http_code"
                break
            fi
            # Honour Retry-After when the server sends one, else back off
            # exponentially: 2, 4, 8, ... seconds.
            delay="$(awk 'BEGIN { IGNORECASE = 1 }
                tolower($1) == "retry-after:" { gsub(/\r/, "", $2); print $2; exit }' \
                "$headers" 2>/dev/null || true)"
            case "$delay" in
                '' | *[!0-9]*) delay=$((2 ** attempt)) ;;
            esac
            warn "status $http_code, retrying in ${delay}s (attempt $attempt of $retries)"
            sleep "$delay"
            ;;
        *) break ;;
    esac
done

if [ "$http_code" != 200 ]; then
    printf '%s: API call failed with status %s\n' "$TP_SCRIPT_NAME" "$http_code" >&2
    # The body carries the error type and message; it never contains the key.
    jq -r '.error.type + ": " + .error.message' <"$response" 2>/dev/null >&2 ||
        cat -- "$response" >&2
    exit 3
fi

if [ "$want_usage" -eq 1 ]; then
    jq -r '"usage: input=\(.usage.input_tokens) output=\(.usage.output_tokens)" +
           (if .usage.cache_read_input_tokens then " cache_read=\(.usage.cache_read_input_tokens)" else "" end) +
           " model=\(.model)"' <"$response" >&2 || true
fi

# A policy decline arrives as HTTP 200 with stop_reason "refusal", so the
# status code alone is not enough to know the call produced an answer.
stop_reason="$(jq -r '.stop_reason // ""' <"$response")"
if [ "$stop_reason" = refusal ]; then
    jq -r '"declined: " + (.stop_details.category // "unspecified") +
           (if .stop_details.explanation then " - " + .stop_details.explanation else "" end)' \
        <"$response" >&2
    exit 1
fi

if [ "$want_json" -eq 1 ]; then
    jq . "$response"
else
    jq -r '[.content[] | select(.type == "text") | .text] | join("")' <"$response"
fi
