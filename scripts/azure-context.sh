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

required=(
  AZURE_TENANT_ID AZURE_SUBSCRIPTION_ID AZURE_LOCATION
  FOUNDRY_RESOURCE_GROUP FOUNDRY_RESOURCE_NAME FOUNDRY_PROJECT_NAME
  CLAUDE_DEPLOYMENT_NAME CLAUDE_MODEL_NAME CLAUDE_MODEL_VERSION
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

unset required name uuid
