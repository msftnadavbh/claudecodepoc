#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/activate-apim.sh"

tool_search_enabled="${ENABLE_TOOL_SEARCH:-false}"
case "$tool_search_enabled" in
  true)
    tools='Read,Edit,Bash,ToolSearch'
    allowed_tools='Read,Edit,Bash(python3 -m unittest discover -s tests -v),ToolSearch'
    prompt='First use ToolSearch once to search for tools relevant to repository inspection. Then inspect this repository, find why the tests fail, fix the bug, run the tests, and explain what you changed.'
    ;;
  false)
    tools='Read,Edit,Bash'
    allowed_tools='Read,Edit,Bash(python3 -m unittest discover -s tests -v)'
    prompt='Inspect this repository, find why the tests fail, fix the bug, run the tests, and explain what you changed.'
    ;;
  *)
    printf 'ERROR: ENABLE_TOOL_SEARCH must be true or false.\n' >&2
    exit 1
    ;;
esac
export ENABLE_TOOL_SEARCH="$tool_search_enabled"

work_parent="$(mktemp -d "${TMPDIR:-/tmp}/claude-apim-smoke.XXXXXX")"
work_dir="${work_parent}/demo-repo"
cp -R "${REPO_ROOT}/demo-repo" "$work_dir"

(
  cd "$work_dir"
  python3 -m unittest discover -s tests -v >/dev/null 2>&1 && {
    printf 'ERROR: Demo fixture no longer starts with a failing test.\n' >&2
    exit 1
  }

  claude_args=(
    --model opus
    --permission-mode acceptEdits
    --tools "$tools"
    --allowed-tools "$allowed_tools"
    --disallowed-tools 'WebFetch,WebSearch'
    --max-budget-usd 5
    --no-session-persistence
  )

  if [[ "$tool_search_enabled" == 'true' ]]; then
    if ! claude_output="$(claude "${claude_args[@]}" \
      --verbose --output-format stream-json -p "$prompt")"; then
      printf '%s\n' "$claude_output" >&2
      exit 1
    fi
    if ! jq -s -e '
      any(.[];
        any(.message.content[]?;
          .type == "tool_use" and .name == "ToolSearch"
        )
      )
    ' <<<"$claude_output" >/dev/null; then
      printf 'ERROR: Tool-search smoke did not observe a ToolSearch tool-use event.\n' >&2
      exit 1
    fi
    jq -r 'select(.type == "result") | .result // empty' <<<"$claude_output"
  else
    claude "${claude_args[@]}" -p "$prompt"
  fi

  python3 -m unittest discover -s tests -v
)

printf 'Smoke-test worktree retained at %s for inspection.\n' "$work_dir"
