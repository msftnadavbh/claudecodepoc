#!/usr/bin/env bash
set -euo pipefail

SOURCE_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/claudecodepoc-test.XXXXXX")"
temp_env="${temp_dir}/azure.env"

cleanup() {
  rm -rf "$temp_dir"
}
trap cleanup EXIT

mkdir -p "${temp_dir}/repo"
REPO_ROOT="$(cd -- "${temp_dir}/repo" && pwd)"
cp -R "${SOURCE_ROOT}/scripts" "${REPO_ROOT}/scripts"
cp -R "${SOURCE_ROOT}/demo-repo" "${REPO_ROOT}/demo-repo"

sed \
  -e 's/^AZURE_TENANT_ID=.*/AZURE_TENANT_ID=22222222-2222-2222-2222-222222222222/' \
  -e 's/^AZURE_SUBSCRIPTION_ID=.*/AZURE_SUBSCRIPTION_ID=11111111-1111-1111-1111-111111111111/' \
  -e 's/your-globally-unique-foundry-name/claudecodepoc-test-foundry/' \
  -e 's/your-globally-unique-apim-name/claudecodepoc-test-apim/' \
  -e 's/Your legal organization name/Test Organization/' \
  "${SOURCE_ROOT}/.env.azure.example" > "$temp_env"

(
  AZURE_ENV_FILE="$temp_env" source "${REPO_ROOT}/scripts/azure-context.sh"
  [[ "$DEPLOYMENT_MODE" == greenfield ]]
  [[ "$CLAUDE_MODEL_FAMILY" == sonnet ]]
  [[ "$CLAUDE_MODEL_NAME" == claude-sonnet-5 ]]
  [[ "$CLAUDE_DEPLOYMENT_NAME" == claude-sonnet-5 ]]
  [[ "$AZURE_TENANT_ID" == 22222222-2222-2222-2222-222222222222 ]]
  [[ "$AZURE_SUBSCRIPTION_ID" == 11111111-1111-1111-1111-111111111111 ]]
)

if [[ "$(uname -s)" != 'Darwin' ]] || ! command -v plutil >/dev/null 2>&1; then
  printf 'Configuration tests passed; Claude Desktop profile checks require macOS with plutil.\n'
  exit 0
fi

fake_bin="${temp_dir}/bin"
fake_app="${temp_dir}/Claude.app"
state_dir="${temp_dir}/state"
managed_preferences_dir="${temp_dir}/managed-preferences"
managed_user="${USER:-$(id -un)}"
machine_preferences="${managed_preferences_dir}/com.anthropic.claudefordesktop.plist"
user_preferences="${managed_preferences_dir}/${managed_user}/com.anthropic.claudefordesktop.plist"
mock_az_log="${temp_dir}/az.log"
mock_az_path_log="${temp_dir}/az-path.log"
mock_open_log="${temp_dir}/open.log"
mock_key='mock-apim-subscription-key-not-secret'
mock_access_token='mock-azure-access-token-not-secret'
mkdir -p "$fake_bin" "${fake_app}/Contents"
: > "$mock_az_log"
: > "$mock_open_log"

cat > "${fake_bin}/az" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >> "$MOCK_AZ_LOG"
printf '%s\n' "$PATH" > "$MOCK_AZ_PATH_LOG"
if [[ "${MOCK_AZ_FORBID:-false}" == 'true' ]]; then
  printf 'ERROR: Azure CLI was invoked unexpectedly.\n' >&2
  exit 90
fi

if [[ "${1:-}" == 'account' && "${2:-}" == 'show' ]]; then
  printf '{"tenantId":"%s","id":"%s","accessToken":"%s"}\n' \
    "$MOCK_TENANT_ID" "$MOCK_SUBSCRIPTION_ID" "$MOCK_ACCESS_TOKEN"
elif [[ "${1:-}" == 'cognitiveservices' && "${2:-}" == 'account' && "${3:-}" == 'show' ]]; then
  printf '/subscriptions/%s/resourceGroups/test/providers/Microsoft.CognitiveServices/accounts/test-foundry\n' \
    "$MOCK_SUBSCRIPTION_ID"
elif [[ "${1:-}" == 'apim' && "${2:-}" == 'show' ]]; then
  printf 'https://claudecodepoc-test-apim.azure-api.net\n'
elif [[ "${1:-}" == 'rest' ]]; then
  if [[ "${MOCK_AZ_FAIL_REST:-false}" == 'true' ]]; then
    printf 'simulated failure containing %s\n' "$MOCK_APIM_KEY" >&2
    exit 1
  fi
  printf '%s\n' "$MOCK_APIM_KEY"
else
  printf 'ERROR: Unexpected mocked Azure CLI call: %s\n' "$*" >&2
  exit 2
fi
EOF

cat > "${fake_bin}/open" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$MOCK_OPEN_LOG"
EOF

chmod +x "${fake_bin}/az" "${fake_bin}/open"
jq -n \
  --arg bundle_id 'com.anthropic.claudefordesktop' \
  --arg version '1.21459.0' \
  '{CFBundleIdentifier: $bundle_id, CFBundleShortVersionString: $version}' |
  plutil -convert xml1 -o "${fake_app}/Contents/Info.plist" -- -

export AZURE_ENV_FILE="$temp_env"
export AZURE_CLI_NATIVE="${fake_bin}/az"
export CLAUDE_DESKTOP_APP_PATH="$fake_app"
export CLAUDE_DESKTOP_STATE_DIR="$state_dir"
export MOCK_AZ_LOG="$mock_az_log"
export MOCK_AZ_PATH_LOG="$mock_az_path_log"
export MOCK_OPEN_LOG="$mock_open_log"
export MOCK_TENANT_ID='22222222-2222-2222-2222-222222222222'
export MOCK_SUBSCRIPTION_ID='11111111-1111-1111-1111-111111111111'
export MOCK_APIM_KEY="$mock_key"
export MOCK_ACCESS_TOKEN="$mock_access_token"
export PATH="${fake_bin}:${PATH}"

"${REPO_ROOT}/scripts/configure-claude-desktop.sh" </dev/null >"${temp_dir}/configure.out"

profile="${state_dir}/claudecodepoc-claude-desktop.mobileconfig"
helper="${REPO_ROOT}/scripts/claude-desktop-credential-helper.sh"
[[ -x "$helper" ]]
grep -Fqx 'CLAUDE_MODEL_FAMILY=sonnet' "${REPO_ROOT}/.env.azure.generated"
plutil -lint "$profile" >/dev/null
[[ "$(cat "$mock_open_log")" == "$profile" ]]
! grep -Fq 'rest --method' "$mock_az_log"

profile_json="$(plutil -convert json -o - "$profile")"
jq -e \
  --arg base_url 'https://claudecodepoc-test-apim.azure-api.net/claude' \
  --arg helper "$helper" \
  --arg deployment 'claude-sonnet-5' '
    .PayloadIdentifier == "com.github.msftnadavbbh.claudecodepoc.claude-desktop-gateway"
    and (
      .PayloadContent[0].PayloadContent["com.anthropic.claudefordesktop"]
        .Forced[0].mcx_preference_settings
    ) as $settings
    | $settings.inferenceProvider == "gateway"
      and $settings.inferenceGatewayBaseUrl == $base_url
      and $settings.inferenceCredentialKind == "helper-script"
      and $settings.inferenceCredentialHelper == $helper
      and $settings.inferenceCredentialHelperTtlSec == "3600"
      and $settings.modelDiscoveryEnabled == "false"
      and $settings.toolSearchEnabled == "false"
      and $settings.chatTabEnabled == "true"
      and (($settings.inferenceModels | fromjson) == [{
        name: $deployment,
        anthropicFamilyTier: "sonnet",
        isFamilyDefault: true,
        labelOverride: ($deployment + " via Microsoft Foundry")
      }])
  ' <<<"$profile_json" >/dev/null
! grep -Fq "$mock_key" "$profile"
! grep -Fq "$mock_access_token" "$profile"

helper_stderr="${temp_dir}/helper.err"
: > "$mock_az_path_log"
helper_output="$(PATH='/usr/bin:/bin' "$helper" 2>"$helper_stderr")"
[[ ! -s "$helper_stderr" ]]
helper_runtime_path="$(cat "$mock_az_path_log")"
[[ ":${helper_runtime_path}:" == *':/opt/homebrew/bin:'* ]]
[[ ":${helper_runtime_path}:" == *':/usr/local/bin:'* ]]
jq -e -s --arg key "$mock_key" '
  length == 1
  and .[0] == {
    token: "unused",
    headers: {"Ocp-Apim-Subscription-Key": $key}
  }
' <<<"$helper_output" >/dev/null

activation_output="$(
  source "${REPO_ROOT}/scripts/activate-apim.sh"
  [[ "$ANTHROPIC_FOUNDRY_BASE_URL" == 'https://claudecodepoc-test-apim.azure-api.net/claude' ]]
  [[ "$ANTHROPIC_CUSTOM_HEADERS" == "Ocp-Apim-Subscription-Key: ${mock_key}" ]]
)"
! grep -Fq "$mock_key" <<<"$activation_output"

if MOCK_AZ_FAIL_REST=true "$helper" >"${temp_dir}/helper-failure.out" 2>"${temp_dir}/helper-failure.err"; then
  printf 'ERROR: Credential helper unexpectedly succeeded when Azure failed.\n' >&2
  exit 1
fi
[[ ! -s "${temp_dir}/helper-failure.out" ]]
! grep -Fq "$mock_key" "${temp_dir}/helper-failure.err"
grep -Fq 'Unable to retrieve the APIM subscription key' "${temp_dir}/helper-failure.err"

mkdir -p "$managed_preferences_dir" "$(dirname -- "$user_preferences")"
jq -c '
  .PayloadContent[0].PayloadContent["com.anthropic.claudefordesktop"]
    .Forced[0].mcx_preference_settings
' <<<"$profile_json" |
  plutil -convert xml1 -o "$machine_preferences" -- -
printf '%s\n' '{"unrelatedManagedSetting":"per-user"}' |
  plutil -convert xml1 -o "$user_preferences" -- -

: > "$mock_az_log"
CLAUDE_DESKTOP_MANAGED_PREFERENCES_DIR="$managed_preferences_dir" \
  "${REPO_ROOT}/scripts/configure-claude-desktop.sh" </dev/null >"${temp_dir}/configure-again.out"
[[ "$(cat "$mock_open_log")" == "$profile" ]]
! grep -Fq 'rest --method' "$mock_az_log"

: > "$mock_az_log"
CLAUDE_DESKTOP_MANAGED_PREFERENCES_DIR="$managed_preferences_dir" \
  MOCK_AZ_FORBID=true \
  "${REPO_ROOT}/scripts/configure-claude-desktop.sh" --check >"${temp_dir}/check.out"
[[ ! -s "$mock_az_log" ]]

mock_claude_args="${temp_dir}/claude.args"
mock_python_count="${temp_dir}/python.count"
smoke_tmp="${temp_dir}/smoke"
mkdir -p "$smoke_tmp"

cat > "${fake_bin}/claude" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" > "$MOCK_CLAUDE_ARGS"
if [[ "${ENABLE_TOOL_SEARCH:-}" != 'true' ]]; then
  printf 'ERROR: Tool search was not exported to Claude Code.\n' >&2
  exit 1
fi
printf '%s\n' \
  '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"ToolSearch","input":{"query":"repository inspection"}}]}}' \
  '{"type":"result","result":"Mock tool-search smoke completed."}'
EOF

cat > "${fake_bin}/python3" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

count=0
if [[ -f "$MOCK_PYTHON_COUNT" ]]; then
  count="$(cat "$MOCK_PYTHON_COUNT")"
fi
count=$((count + 1))
printf '%s\n' "$count" > "$MOCK_PYTHON_COUNT"
if [[ "$count" -eq 1 ]]; then
  exit 1
fi
EOF

chmod +x "${fake_bin}/claude" "${fake_bin}/python3"
export MOCK_CLAUDE_ARGS="$mock_claude_args"
export MOCK_PYTHON_COUNT="$mock_python_count"

ENABLE_TOOL_SEARCH=true TMPDIR="$smoke_tmp" \
  "${REPO_ROOT}/scripts/run-claude-code-smoke.sh" >"${temp_dir}/smoke.out"
grep -Fq -- '--tools Read,Edit,Bash,ToolSearch' "$mock_claude_args"
grep -Fq -- '--allowed-tools Read,Edit,Bash(python3 -m unittest discover -s tests -v),ToolSearch' \
  "$mock_claude_args"
grep -Fq -- '--output-format stream-json' "$mock_claude_args"
grep -Fq 'Mock tool-search smoke completed.' "${temp_dir}/smoke.out"

printf 'Configuration tests passed.\n'
