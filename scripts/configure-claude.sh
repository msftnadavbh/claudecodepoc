#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
shell_name="$(basename -- "${SHELL:-/bin/bash}")"

case "$shell_name" in
  zsh) rc_file="${HOME}/.zshrc" ;;
  bash) rc_file="${HOME}/.bashrc" ;;
  *)
    printf 'ERROR: Unsupported shell %s. Use scripts/claude-apim.sh directly.\n' "$shell_name" >&2
    exit 1
    ;;
esac

config_dir="${XDG_CONFIG_HOME:-${HOME}/.config}/claudecodepoc"
loader="${config_dir}/claude.sh"
source_line=". \"${loader}\""

if [[ "${1:-}" == '--check' ]]; then
  if [[ ! -f "$loader" || ! -f "$rc_file" ]] || ! grep -Fqx "$source_line" "$rc_file"; then
    printf 'ERROR: Claude Code Foundry launcher is not configured for %s.\n' "$shell_name" >&2
    exit 1
  fi
  printf 'Claude Code Foundry launcher is configured in %s.\n' "$rc_file"
  exit 0
elif [[ $# -gt 0 ]]; then
  printf 'Usage: %s [--check]\n' "$0" >&2
  exit 2
fi

if [[ ! -f "${REPO_ROOT}/.env.azure.local" ]]; then
  printf 'ERROR: Copy .env.azure.example to .env.azure.local and configure it first.\n' >&2
  exit 1
fi
if ! command -v claude >/dev/null 2>&1; then
  printf 'ERROR: Claude Code is not installed. See README.md.\n' >&2
  exit 1
fi

"${SCRIPT_DIR}/write-generated-env.sh" >/dev/null

mkdir -p "$config_dir"
escaped_root="${REPO_ROOT//\\/\\\\}"
escaped_root="${escaped_root//\"/\\\"}"
printf 'unalias claude 2>/dev/null || true\nclaude() {\n  "%s/scripts/claude-apim.sh" "$@"\n}\n' "$escaped_root" > "$loader"

touch "$rc_file"
if ! grep -Fqx "$source_line" "$rc_file"; then
  printf '\n# Claude Code through Microsoft Foundry and APIM\n%s\n' "$source_line" >> "$rc_file"
fi

printf 'Configured plain claude in %s. Restart the shell or run: source %s\n' "$rc_file" "$rc_file"
