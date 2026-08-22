#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
PREFERENCE_DOMAIN='com.anthropic.claudefordesktop'
PROFILE_IDENTIFIER='com.github.msftnadavbbh.claudecodepoc.claude-desktop-gateway'
PROFILE_UUID='B38A8716-81E5-4B72-B45A-96DE62F07E8A'
PREFERENCES_UUID='7C3F7918-D444-45F0-8A55-172CB6D8DCAA'
MIN_CLAUDE_DESKTOP_VERSION='1.21459.0'
STATE_DIR="${CLAUDE_DESKTOP_STATE_DIR:-${REPO_ROOT}/.claude-runtime/claude-desktop}"
PROFILE_PATH="${STATE_DIR}/claudecodepoc-claude-desktop.mobileconfig"
HELPER_PATH="${SCRIPT_DIR}/claude-desktop-credential-helper.sh"
TOOL_SEARCH_ENABLED="${ENABLE_TOOL_SEARCH:-false}"

usage() {
  printf 'Usage: %s [--check]\n' "$0" >&2
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'ERROR: %s is required.\n' "$1" >&2
    exit 1
  fi
}

version_at_least() {
  local actual="$1" required="$2" actual_part required_part index

  actual="${actual#v}"
  required="${required#v}"
  for index in 1 2 3 4; do
    actual_part="${actual%%.*}"
    required_part="${required%%.*}"
    [[ "$actual" == *.* ]] && actual="${actual#*.}" || actual=''
    [[ "$required" == *.* ]] && required="${required#*.}" || required=''
    actual_part="${actual_part:-0}"
    required_part="${required_part:-0}"

    if ((10#$actual_part > 10#$required_part)); then
      return 0
    elif ((10#$actual_part < 10#$required_part)); then
      return 1
    fi
  done
  return 0
}

find_claude_desktop() {
  local candidate

  if [[ -n "${CLAUDE_DESKTOP_APP_PATH:-}" ]]; then
    candidate="$CLAUDE_DESKTOP_APP_PATH"
    if [[ ! -d "$candidate" ]]; then
      printf 'ERROR: Claude Desktop was not found at %s.\n' "$candidate" >&2
      exit 1
    fi
    printf '%s' "$candidate"
    return
  fi

  for candidate in '/Applications/Claude.app' "${HOME}/Applications/Claude.app"; do
    if [[ -d "$candidate" ]]; then
      printf '%s' "$candidate"
      return
    fi
  done

  printf 'ERROR: Claude Desktop is not installed. Download it from https://claude.com/download.\n' >&2
  exit 1
}

validate_claude_desktop() {
  local info_plist bundle_id desktop_version

  CLAUDE_DESKTOP_APP="$(find_claude_desktop)"
  info_plist="${CLAUDE_DESKTOP_APP}/Contents/Info.plist"
  if [[ ! -f "$info_plist" ]]; then
    printf 'ERROR: Claude Desktop has no readable Info.plist at %s.\n' "$info_plist" >&2
    exit 1
  fi
  if ! bundle_id="$(plutil -extract CFBundleIdentifier raw -o - "$info_plist" 2>/dev/null)" ||
    [[ "$bundle_id" != "$PREFERENCE_DOMAIN" ]]; then
    printf 'ERROR: %s is not the supported Claude Desktop application.\n' "$CLAUDE_DESKTOP_APP" >&2
    exit 1
  fi
  if ! desktop_version="$(plutil -extract CFBundleShortVersionString raw -o - "$info_plist" 2>/dev/null)" ||
    [[ ! "$desktop_version" =~ ^[0-9]+(\.[0-9]+){1,3}$ ]]; then
    printf 'ERROR: Unable to determine the Claude Desktop version.\n' >&2
    exit 1
  fi
  if ! version_at_least "$desktop_version" "$MIN_CLAUDE_DESKTOP_VERSION"; then
    printf 'ERROR: Claude Desktop %s or later is required; installed version is %s.\n' \
      "$MIN_CLAUDE_DESKTOP_VERSION" "$desktop_version" >&2
    exit 1
  fi

  CLAUDE_DESKTOP_VERSION="$desktop_version"
}

load_repository_configuration() {
  local generate="$1" configured_tenant_id configured_subscription_id name

  source "${SCRIPT_DIR}/azure-context.sh"
  configured_tenant_id="$AZURE_TENANT_ID"
  configured_subscription_id="$AZURE_SUBSCRIPTION_ID"

  if [[ "$generate" == 'true' ]]; then
    "${SCRIPT_DIR}/write-generated-env.sh" >/dev/null
  fi
  if [[ ! -f "${REPO_ROOT}/.env.azure.generated" ]]; then
    printf 'ERROR: Missing .env.azure.generated; run %s first.\n' \
      "${SCRIPT_DIR}/configure-claude-desktop.sh" >&2
    exit 1
  fi

  unset AZURE_TENANT_ID AZURE_SUBSCRIPTION_ID
  unset APIM_CLAUDE_BASE_URL CLAUDE_DEPLOYMENT_NAME CLAUDE_MODEL_FAMILY
  set -a
  if ! source "${REPO_ROOT}/.env.azure.generated"; then
    set +a
    printf 'ERROR: Generated Azure configuration is invalid; rerun %s.\n' \
      "${SCRIPT_DIR}/configure-claude-desktop.sh" >&2
    exit 1
  fi
  set +a

  for name in AZURE_TENANT_ID AZURE_SUBSCRIPTION_ID APIM_CLAUDE_BASE_URL \
    CLAUDE_DEPLOYMENT_NAME CLAUDE_MODEL_FAMILY; do
    if [[ -z "${!name:-}" ]]; then
      printf 'ERROR: Generated configuration is missing %s.\n' "$name" >&2
      exit 1
    fi
  done
  if [[ "$AZURE_TENANT_ID" != "$configured_tenant_id" ||
        "$AZURE_SUBSCRIPTION_ID" != "$configured_subscription_id" ]]; then
    printf 'ERROR: Generated Azure configuration is stale; rerun %s.\n' \
      "${SCRIPT_DIR}/configure-claude-desktop.sh" >&2
    exit 1
  fi

  if [[ "$APIM_CLAUDE_BASE_URL" != https://* ]]; then
    printf 'ERROR: APIM_CLAUDE_BASE_URL must use HTTPS.\n' >&2
    exit 1
  fi
  case "$CLAUDE_MODEL_FAMILY" in
    opus | sonnet | haiku) ;;
    *)
      printf 'ERROR: CLAUDE_MODEL_FAMILY must be opus, sonnet, or haiku.\n' >&2
      exit 1
      ;;
  esac
}

profile_settings_match() {
  local settings_json="$1" expected_tool_search="$2"

  jq -e \
    --arg base_url "$APIM_CLAUDE_BASE_URL" \
    --arg helper "$HELPER_PATH" \
    --arg deployment "$CLAUDE_DEPLOYMENT_NAME" \
    --arg family "$CLAUDE_MODEL_FAMILY" \
    --arg label "${CLAUDE_DEPLOYMENT_NAME} via Microsoft Foundry" \
    --arg tool_search "$expected_tool_search" '
      . as $settings
      | $settings.inferenceProvider == "gateway"
        and $settings.inferenceGatewayBaseUrl == $base_url
        and $settings.inferenceCredentialKind == "helper-script"
        and $settings.inferenceCredentialHelper == $helper
        and $settings.inferenceCredentialHelperTtlSec == "3600"
        and $settings.modelDiscoveryEnabled == "false"
        and $settings.toolSearchEnabled == $tool_search
        and $settings.chatTabEnabled == "true"
        and (($settings.inferenceModels | fromjson) == [{
          name: $deployment,
          anthropicFamilyTier: $family,
          isFamilyDefault: true,
          labelOverride: $label
        }])
        and (($settings | has("inferenceGatewayApiKey")) | not)
        and (($settings | has("inferenceFoundryApiKey")) | not)
    ' <<<"$settings_json" >/dev/null
}

profile_settings_json() {
  local profile_json

  if [[ ! -f "$PROFILE_PATH" ]]; then
    printf 'ERROR: Generated profile is missing at %s.\n' "$PROFILE_PATH" >&2
    return 1
  fi
  if ! plutil -lint "$PROFILE_PATH" >/dev/null; then
    printf 'ERROR: Generated profile is not a valid property list.\n' >&2
    return 1
  fi
  if ! profile_json="$(plutil -convert json -o - "$PROFILE_PATH" 2>/dev/null)"; then
    printf 'ERROR: Unable to inspect the generated profile.\n' >&2
    return 1
  fi
  if ! jq -e \
    --arg identifier "$PROFILE_IDENTIFIER" '
      .PayloadType == "Configuration"
      and .PayloadIdentifier == $identifier
      and .PayloadScope == "System"
      and .PayloadRemovalDisallowed == false
    ' <<<"$profile_json" >/dev/null; then
    printf 'ERROR: Generated profile metadata is invalid.\n' >&2
    return 1
  fi

  jq -ce \
    --arg domain "$PREFERENCE_DOMAIN" '
      first(
        .PayloadContent[]
        | select(.PayloadType == "com.apple.ManagedClient.preferences")
        | .PayloadContent[$domain].Forced[0].mcx_preference_settings
      ) // empty
    ' <<<"$profile_json"
}

generate_profile() {
  local models_json profile_tmp

  mkdir -p "$STATE_DIR"
  chmod 700 "$STATE_DIR"
  models_json="$(jq -cn \
    --arg deployment "$CLAUDE_DEPLOYMENT_NAME" \
    --arg family "$CLAUDE_MODEL_FAMILY" \
    --arg label "${CLAUDE_DEPLOYMENT_NAME} via Microsoft Foundry" '
      [{
        name: $deployment,
        anthropicFamilyTier: $family,
        isFamilyDefault: true,
        labelOverride: $label
      }]
    ')"
  profile_tmp="${PROFILE_PATH}.tmp.$$"

  if ! (
    umask 077
    jq -n \
      --arg domain "$PREFERENCE_DOMAIN" \
      --arg profile_identifier "$PROFILE_IDENTIFIER" \
      --arg profile_uuid "$PROFILE_UUID" \
      --arg preferences_uuid "$PREFERENCES_UUID" \
      --arg base_url "$APIM_CLAUDE_BASE_URL" \
      --arg helper "$HELPER_PATH" \
      --arg models "$models_json" \
      --arg tool_search "$TOOL_SEARCH_ENABLED" '
        {
          PayloadContent: [
            {
              PayloadContent: {
                ($domain): {
                  Forced: [
                    {
                      mcx_preference_settings: {
                        inferenceProvider: "gateway",
                        inferenceGatewayBaseUrl: $base_url,
                        inferenceCredentialKind: "helper-script",
                        inferenceCredentialHelper: $helper,
                        inferenceCredentialHelperTtlSec: "3600",
                        modelDiscoveryEnabled: "false",
                        inferenceModels: $models,
                        toolSearchEnabled: $tool_search,
                        chatTabEnabled: "true"
                      }
                    }
                  ]
                }
              },
              PayloadDisplayName: "Claude Desktop gateway preferences",
              PayloadIdentifier: ($profile_identifier + ".preferences"),
              PayloadType: "com.apple.ManagedClient.preferences",
              PayloadUUID: $preferences_uuid,
              PayloadVersion: 1
            }
          ],
          PayloadDescription: "Routes Claude Desktop through the claudecodepoc APIM gateway.",
          PayloadDisplayName: "Claude Desktop via claudecodepoc",
          PayloadIdentifier: $profile_identifier,
          PayloadOrganization: "claudecodepoc",
          PayloadRemovalDisallowed: false,
          PayloadScope: "System",
          PayloadType: "Configuration",
          PayloadUUID: $profile_uuid,
          PayloadVersion: 1
        }
      ' | plutil -convert xml1 -o "$profile_tmp" -- -
  ); then
    rm -f "$profile_tmp"
    printf 'ERROR: Unable to generate the Claude Desktop profile.\n' >&2
    exit 1
  fi
  if ! plutil -lint "$profile_tmp" >/dev/null; then
    rm -f "$profile_tmp"
    printf 'ERROR: Generated Claude Desktop profile failed plutil validation.\n' >&2
    exit 1
  fi
  mv "$profile_tmp" "$PROFILE_PATH"
}

managed_preferences_json() {
  local managed_user managed_root machine_file user_file
  local machine_json='{}' user_json='{}' found=false

  if [[ -n "${CLAUDE_DESKTOP_MANAGED_PREFERENCES_FILE:-}" ]]; then
    if [[ ! -f "$CLAUDE_DESKTOP_MANAGED_PREFERENCES_FILE" ]]; then
      return 1
    fi
    plutil -convert json -o - "$CLAUDE_DESKTOP_MANAGED_PREFERENCES_FILE" 2>/dev/null
    return
  fi

  managed_user="${USER:-$(id -un)}"
  managed_root="${CLAUDE_DESKTOP_MANAGED_PREFERENCES_DIR:-/Library/Managed Preferences}"
  machine_file="${managed_root}/${PREFERENCE_DOMAIN}.plist"
  user_file="${managed_root}/${managed_user}/${PREFERENCE_DOMAIN}.plist"

  if [[ -f "$machine_file" ]]; then
    if ! machine_json="$(plutil -convert json -o - "$machine_file" 2>/dev/null)"; then
      return 1
    fi
    found=true
  fi
  if [[ -f "$user_file" ]]; then
    if ! user_json="$(plutil -convert json -o - "$user_file" 2>/dev/null)"; then
      return 1
    fi
    found=true
  fi
  if [[ "$found" != 'true' ]]; then
    return 1
  fi

  printf '%s\n%s\n' "$machine_json" "$user_json" | jq -sc '.[0] + .[1]'
}

profile_is_installed() {
  local expected_tool_search="$1" settings_json

  if ! settings_json="$(managed_preferences_json)"; then
    return 1
  fi
  profile_settings_match "$settings_json" "$expected_tool_search"
}

restart_claude_desktop() {
  local running index

  require_command osascript
  if ! running="$(osascript -e "application id \"${PREFERENCE_DOMAIN}\" is running" 2>/dev/null)"; then
    printf 'ERROR: Unable to determine whether Claude Desktop is running.\n' >&2
    exit 1
  fi
  if [[ "$running" == 'true' ]]; then
    if ! osascript -e "tell application id \"${PREFERENCE_DOMAIN}\" to quit" >/dev/null; then
      printf 'ERROR: Unable to quit Claude Desktop cleanly.\n' >&2
      exit 1
    fi
    for index in 1 2 3 4 5 6 7 8 9 10; do
      running="$(osascript -e "application id \"${PREFERENCE_DOMAIN}\" is running" 2>/dev/null)"
      [[ "$running" == 'false' ]] && break
      sleep 1
    done
    if [[ "$running" != 'false' ]]; then
      printf 'ERROR: Claude Desktop did not quit; quit it manually before reopening.\n' >&2
      exit 1
    fi
  fi

  if ! open "$CLAUDE_DESKTOP_APP"; then
    printf 'ERROR: Unable to reopen Claude Desktop.\n' >&2
    exit 1
  fi
}

print_profile_management() {
  printf 'To replace the profile, rerun this command and approve the replacement.\n'
  printf 'To remove it, use System Settings > General > Device Management; nothing is removed automatically.\n'
}

mode='configure'
if [[ "${1:-}" == '--check' ]]; then
  mode='check'
elif [[ $# -gt 0 ]]; then
  usage
  exit 2
fi

if [[ "$(uname -s)" != 'Darwin' ]]; then
  printf 'ERROR: Claude Desktop configuration currently supports macOS only.\n' >&2
  exit 1
fi
require_command jq
require_command plutil
if [[ ! -x "$HELPER_PATH" ]]; then
  printf 'ERROR: Claude Desktop credential helper is not executable: %s\n' "$HELPER_PATH" >&2
  exit 1
fi
validate_claude_desktop

if [[ "$mode" == 'check' ]]; then
  load_repository_configuration false
  if ! profile_settings="$(profile_settings_json)"; then
    exit 1
  fi
  profile_tool_search="$(jq -r '.toolSearchEnabled // empty' <<<"$profile_settings")"
  if [[ "$profile_tool_search" != 'true' && "$profile_tool_search" != 'false' ]] ||
    ! profile_settings_match "$profile_settings" "$profile_tool_search"; then
    printf 'ERROR: Generated profile does not match the repository configuration.\n' >&2
    exit 1
  fi
  if ! profile_is_installed "$profile_tool_search"; then
    printf 'ERROR: The expected Claude Desktop managed preference is not installed.\n' >&2
    exit 1
  fi

  printf 'Claude Desktop %s gateway configuration is valid and installed.\n' "$CLAUDE_DESKTOP_VERSION"
  printf 'Profile: %s\n' "$PROFILE_PATH"
  print_profile_management
  exit 0
fi

if [[ "$TOOL_SEARCH_ENABLED" != 'true' && "$TOOL_SEARCH_ENABLED" != 'false' ]]; then
  printf 'ERROR: ENABLE_TOOL_SEARCH must be true or false.\n' >&2
  exit 1
fi
require_command open
load_repository_configuration true
generate_profile
if ! profile_settings="$(profile_settings_json)" ||
  ! profile_settings_match "$profile_settings" "$TOOL_SEARCH_ENABLED"; then
  printf 'ERROR: Generated profile does not match the requested configuration.\n' >&2
  exit 1
fi

printf 'Generated and validated %s.\n' "$PROFILE_PATH"
if profile_is_installed "$TOOL_SEARCH_ENABLED"; then
  printf 'The matching managed preference is already installed; no replacement is needed.\n'
  print_profile_management
  exit 0
fi

if ! open "$PROFILE_PATH"; then
  printf 'ERROR: Unable to open the Claude Desktop profile.\n' >&2
  exit 1
fi
printf 'Approve the profile in System Settings > General > Device Management.\n'

if [[ -t 0 ]]; then
  printf 'After approval, press Return to verify it and restart Claude Desktop: '
  if ! IFS= read -r; then
    printf '\nERROR: Unable to wait for profile approval.\n' >&2
    exit 1
  fi
  if ! profile_is_installed "$TOOL_SEARCH_ENABLED"; then
    printf 'ERROR: The managed preference is not installed or does not match the generated profile.\n' >&2
    exit 1
  fi
  restart_claude_desktop
  printf 'Claude Desktop was fully quit and reopened with the managed gateway configuration.\n'
else
  printf 'After approval, fully quit and reopen Claude Desktop, then run %s --check.\n' "$0"
fi
print_profile_management
