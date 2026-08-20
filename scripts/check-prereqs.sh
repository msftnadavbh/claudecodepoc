#!/usr/bin/env bash
set -euo pipefail

source "$(dirname -- "${BASH_SOURCE[0]}")/azure-context.sh"

missing=0
for command in az jq curl git python3; do
  if command -v "$command" >/dev/null 2>&1; then
    printf '[ok] %s\n' "$command"
  else
    printf '[missing] %s\n' "$command" >&2
    missing=1
  fi
done

if ((missing)); then
  exit 1
fi

"${REPO_ROOT}/scripts/assert-azure-context.sh"
az bicep version
python3 --version

if command -v claude >/dev/null 2>&1; then
  claude --version
else
  printf '[missing] claude (install after Azure preflight with the official native installer)\n'
fi
