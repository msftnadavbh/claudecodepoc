#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/activate-apim.sh"

work_parent="$(mktemp -d "${TMPDIR:-/tmp}/claude-apim-smoke.XXXXXX")"
work_dir="${work_parent}/demo-repo"
cp -R "${REPO_ROOT}/demo-repo" "$work_dir"

(
  cd "$work_dir"
  python3 -m unittest discover -s tests -v >/dev/null 2>&1 && {
    printf 'ERROR: Demo fixture no longer starts with a failing test.\n' >&2
    exit 1
  }

  claude --model opus --permission-mode acceptEdits \
    --tools 'Read,Edit,Bash' \
    --allowed-tools 'Read,Edit,Bash(python3 -m unittest discover -s tests -v)' \
    --disallowed-tools 'WebFetch,WebSearch' \
    --max-budget-usd 5 \
    --no-session-persistence \
    -p 'Inspect this repository, find why the tests fail, fix the bug, run the tests, and explain what you changed.'

  python3 -m unittest discover -s tests -v
)

printf 'Smoke-test worktree retained at %s for inspection.\n' "$work_dir"
