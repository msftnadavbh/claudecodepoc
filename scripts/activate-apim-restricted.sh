#!/usr/bin/env bash

_script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${_script_dir}/activate-apim.sh" || return 1
export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1

printf 'Restricted-egress mode enabled. Auto-updates, telemetry, and discovery are disabled.\n'
printf 'WebFetch domain safety checks still contact api.anthropic.com if WebFetch is used.\n'

unset _script_dir
