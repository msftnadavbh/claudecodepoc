#!/usr/bin/env bash

_script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${_script_dir}/azure-context.sh"
"${_script_dir}/assert-azure-context.sh" || return 1

if [[ ! -f "${REPO_ROOT}/.env.azure.generated" ]]; then
  printf 'ERROR: Run scripts/deploy.sh first.\n' >&2
  return 1
fi

set -a
source "${REPO_ROOT}/.env.azure.generated"
set +a

if [[ -z "${APIM_CLAUDE_BASE_URL:-}" ]]; then
  printf 'ERROR: APIM endpoint is not present; run scripts/deploy.sh.\n' >&2
  return 1
fi

key_url="https://management.azure.com/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${FOUNDRY_RESOURCE_GROUP}/providers/Microsoft.ApiManagement/service/${APIM_RESOURCE_NAME}/subscriptions/${APIM_SUBSCRIPTION_NAME}/listSecrets?api-version=2024-05-01"
_apim_key="$(az rest --method post --url "$key_url" --query primaryKey --output tsv)"
unset key_url

export PATH="$HOME/.local/bin:$PATH"
export CLAUDE_CODE_USE_FOUNDRY=1
export ANTHROPIC_FOUNDRY_BASE_URL="$APIM_CLAUDE_BASE_URL"
export CLAUDE_CODE_SKIP_FOUNDRY_AUTH=1
export ANTHROPIC_CUSTOM_HEADERS="Ocp-Apim-Subscription-Key: ${_apim_key}"
unset ANTHROPIC_FOUNDRY_RESOURCE ANTHROPIC_FOUNDRY_API_KEY ANTHROPIC_FOUNDRY_AUTH_TOKEN
export ANTHROPIC_DEFAULT_OPUS_MODEL="$CLAUDE_DEPLOYMENT_NAME"
export ANTHROPIC_DEFAULT_SONNET_MODEL="$CLAUDE_DEPLOYMENT_NAME"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="$CLAUDE_DEPLOYMENT_NAME"
export ANTHROPIC_MODEL='opus'
export CLAUDE_CODE_DISABLE_AUTO_MEMORY=1

printf 'Claude Code APIM -> Foundry mode\n'
printf '  Gateway:    %s\n' "$APIM_CLAUDE_BASE_URL"
printf '  Deployment: %s\n' "$CLAUDE_DEPLOYMENT_NAME"
printf '  Client auth: Ocp-Apim-Subscription-Key\n'
printf '  Backend auth: APIM system-assigned managed identity\n'

unset _apim_key _script_dir
