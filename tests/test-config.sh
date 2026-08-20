#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
temp_env="$(mktemp)"
trap 'rm -f "$temp_env"' EXIT

sed \
  -e 's/00000000-0000-0000-0000-000000000000/11111111-1111-1111-1111-111111111111/' \
  -e '0,/11111111-1111-1111-1111-111111111111/s//22222222-2222-2222-2222-222222222222/' \
  -e 's/your-globally-unique-foundry-name/claudecodepoc-test-foundry/' \
  -e 's/your-globally-unique-apim-name/claudecodepoc-test-apim/' \
  -e 's/Your legal organization name/Test Organization/' \
  "${REPO_ROOT}/.env.azure.example" > "$temp_env"

AZURE_ENV_FILE="$temp_env" source "${REPO_ROOT}/scripts/azure-context.sh"
[[ "$DEPLOYMENT_MODE" == greenfield ]]
[[ "$CLAUDE_MODEL_FAMILY" == sonnet ]]
[[ "$CLAUDE_MODEL_NAME" == claude-sonnet-5 ]]
[[ "$CLAUDE_DEPLOYMENT_NAME" == claude-sonnet-5 ]]
