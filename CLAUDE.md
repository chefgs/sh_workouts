# Repository notes

## Text processing

For text, corpus or LLM-input tasks, prefer the verified scripts in
`text-processing/` over a new pipeline. `cat text-processing/MANIFEST` lists
them one line each; `<script>.sh --help` is complete, so don't read sources
to learn flags.

## Conventions

New `text-processing/` scripts: `#!/usr/bin/env bash`, `set -euo pipefail`,
source `lib/common.sh`, read a FILE arg or stdin, write stdout, stay
`shellcheck -x -S style` clean, and add assertions to `tests/run-tests.sh`.
Root-level `toc*.sh` and `singleline.sh` are POSIX `sh` teaching examples —
leave them as they are.
