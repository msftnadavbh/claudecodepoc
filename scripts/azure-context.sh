#!/usr/bin/env bash

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
AZURE_ENV_FILE="${AZURE_ENV_FILE:-${REPO_ROOT}/.env.azure.local}"

if [[ ! -f "$AZURE_ENV_FILE" ]]; then
  printf 'ERROR: Missing %s. Copy .env.azure.example to .env.azure.local and configure it.\n' "$AZURE_ENV_FILE" >&2
  return 1 2>/dev/null || exit 1
fi

set -a
source "$AZURE_ENV_FILE"
set +a

DEPLOYMENT_MODE="${DEPLOYMENT_MODE:-greenfield}"
CLAUDE_MODEL_FAMILY="${CLAUDE_MODEL_FAMILY:-sonnet}"
case "$CLAUDE_MODEL_FAMILY" in
  opus) default_model='claude-opus-5' ;;
  sonnet) default_model='claude-sonnet-5' ;;
  haiku) default_model='claude-haiku-4-5' ;;
  *)
    printf 'ERROR: CLAUDE_MODEL_FAMILY must be opus, sonnet, or haiku.\n' >&2
    return 1 2>/dev/null || exit 1
    ;;
esac
CLAUDE_MODEL_NAME="${CLAUDE_MODEL_NAME:-$default_model}"
CLAUDE_MODEL_VERSION="${CLAUDE_MODEL_VERSION:-2}"
CLAUDE_MODEL_CAPACITY="${CLAUDE_MODEL_CAPACITY:-25}"
CLAUDE_DEPLOYMENT_NAME="${CLAUDE_DEPLOYMENT_NAME:-$CLAUDE_MODEL_NAME}"
CLAUDE_ORGANIZATION_NAME="${CLAUDE_ORGANIZATION_NAME:-}"
CLAUDE_COUNTRY_CODE="${CLAUDE_COUNTRY_CODE:-}"
CLAUDE_INDUSTRY="${CLAUDE_INDUSTRY:-}"

required=(
  AZURE_TENANT_ID AZURE_SUBSCRIPTION_ID AZURE_LOCATION
  FOUNDRY_RESOURCE_GROUP FOUNDRY_RESOURCE_NAME FOUNDRY_PROJECT_NAME
  DEPLOYMENT_MODE CLAUDE_MODEL_FAMILY CLAUDE_DEPLOYMENT_NAME
  CLAUDE_MODEL_NAME CLAUDE_MODEL_VERSION CLAUDE_MODEL_CAPACITY
  APIM_RESOURCE_NAME APIM_SUBSCRIPTION_NAME
  LOG_ANALYTICS_WORKSPACE_NAME APP_INSIGHTS_NAME
  PUBLISHER_NAME PUBLISHER_EMAIL
)
for name in "${required[@]}"; do
  if [[ -z "${!name:-}" ]]; then
    printf 'ERROR: %s is not set in %s.\n' "$name" "$AZURE_ENV_FILE" >&2
    return 1 2>/dev/null || exit 1
  fi
done

if [[ "$DEPLOYMENT_MODE" != greenfield && "$DEPLOYMENT_MODE" != brownfield ]]; then
  printf 'ERROR: DEPLOYMENT_MODE must be greenfield or brownfield.\n' >&2
  return 1 2>/dev/null || exit 1
fi
if [[ ! "$CLAUDE_MODEL_CAPACITY" =~ ^[1-9][0-9]*$ ]]; then
  printf 'ERROR: CLAUDE_MODEL_CAPACITY must be a positive integer in thousands of TPM.\n' >&2
  return 1 2>/dev/null || exit 1
fi
if [[ "$DEPLOYMENT_MODE" == greenfield ]]; then
  if [[ -z "$CLAUDE_ORGANIZATION_NAME" || "$CLAUDE_ORGANIZATION_NAME" == 'Your legal organization name' ||
        ! "$CLAUDE_COUNTRY_CODE" =~ ^[A-Za-z]{2}$ ]]; then
    printf 'ERROR: Greenfield requires CLAUDE_ORGANIZATION_NAME and a two-letter CLAUDE_COUNTRY_CODE.\n' >&2
    return 1 2>/dev/null || exit 1
  fi
  case "$CLAUDE_INDUSTRY" in
    technology|finance|healthcare|education|retail|manufacturing|government|media|other) ;;
    *)
      printf 'ERROR: Greenfield CLAUDE_INDUSTRY is invalid; see .env.azure.example.\n' >&2
      return 1 2>/dev/null || exit 1
      ;;
  esac
fi

uuid='^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
if [[ ! "$AZURE_TENANT_ID" =~ $uuid || ! "$AZURE_SUBSCRIPTION_ID" =~ $uuid ||
      "$AZURE_TENANT_ID" == '00000000-0000-0000-0000-000000000000' ||
      "$AZURE_SUBSCRIPTION_ID" == '00000000-0000-0000-0000-000000000000' ||
      "$FOUNDRY_RESOURCE_NAME" == your-* || "$FOUNDRY_PROJECT_NAME" == your-* ||
      "$CLAUDE_DEPLOYMENT_NAME" == your-* || "$APIM_RESOURCE_NAME" == your-* ]]; then
  printf 'ERROR: Replace the example values in %s before running Azure commands.\n' "$AZURE_ENV_FILE" >&2
  return 1 2>/dev/null || exit 1
fi

export AZURE_CORE_COLLECT_TELEMETRY=false
AZURE_CLI_CACHE_NAME="${AZURE_CLI_CACHE_NAME:-claudecodepoc}"
if [[ ! "$AZURE_CLI_CACHE_NAME" =~ ^[A-Za-z0-9._-]+$ ]]; then
  printf 'ERROR: AZURE_CLI_CACHE_NAME may contain only letters, numbers, dot, underscore, and hyphen.\n' >&2
  return 1 2>/dev/null || exit 1
fi

AZURE_CLI_PYTHON='/mnt/c/Program Files/Microsoft SDKs/Azure/CLI2/python.exe'
if [[ -x "$AZURE_CLI_PYTHON" ]] && command -v powershell.exe >/dev/null 2>&1; then
  windows_local_app_data="$(powershell.exe -NoProfile -NonInteractive -Command '[Environment]::GetFolderPath("LocalApplicationData")')"
  windows_local_app_data="${windows_local_app_data%$'\r'}"
  export AZURE_CLI_PYTHON
  export AZURE_CONFIG_DIR="$(wslpath -u "${windows_local_app_data}\\${AZURE_CLI_CACHE_NAME}\\azure-cli")"
  unset windows_local_app_data
else
  unset AZURE_CLI_PYTHON
  if [[ -z "${AZURE_CLI_NATIVE:-}" ]]; then
    AZURE_CLI_NATIVE="$(command -v az 2>/dev/null || true)"
  fi
  if [[ "$AZURE_CLI_NATIVE" == "${REPO_ROOT}/scripts/az" ]]; then
    unset AZURE_CLI_NATIVE
  fi
  export AZURE_CLI_NATIVE
  export AZURE_CONFIG_DIR="${AZURE_CLI_CONFIG_DIR:-${REPO_ROOT}/.azure/cli}"
fi

case ":${PATH}:" in
  *":${REPO_ROOT}/scripts:"*) ;;
  *) export PATH="${REPO_ROOT}/scripts:${PATH}" ;;
esac

get_apim_subscription_key() {
  local key_url apim_key

  key_url="https://management.azure.com/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${FOUNDRY_RESOURCE_GROUP}/providers/Microsoft.ApiManagement/service/${APIM_RESOURCE_NAME}/subscriptions/${APIM_SUBSCRIPTION_NAME}/listSecrets?api-version=2024-05-01"
  if ! apim_key="$(az rest --method post --url "$key_url" --query primaryKey --output tsv 2>/dev/null)"; then
    printf 'ERROR: Unable to retrieve the APIM subscription key.\n' >&2
    return 1
  fi
  if [[ -z "$apim_key" || "$apim_key" == 'null' || "$apim_key" == *$'\n'* ]]; then
    printf 'ERROR: Azure returned an invalid APIM subscription key.\n' >&2
    return 1
  fi

  printf '%s' "$apim_key"
}

unset required name uuid default_model
