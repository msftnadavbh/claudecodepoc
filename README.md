# Claude Code on Azure with Microsoft Foundry

Run local Claude Code through Azure API Management (APIM) and Microsoft Foundry while preserving the native Anthropic Messages API.

![Claude Code on Azure architecture](docs/claude-arch.png)

The diagram shows the brownfield path. Greenfield also creates the resource group, Foundry account, project, and Claude deployment.

## Deployment Modes

- **Greenfield (default):** creates the full stack: resource group, Foundry account/project/model, APIM Standard v2, RBAC, Log Analytics, and Application Insights.
- **Brownfield:** reuses an existing Foundry account/project/model and deploys only the gateway, observability, and APIM RBAC.

Set `DEPLOYMENT_MODE=greenfield` or `brownfield` in `.env.azure.local`.

## Model Choice

| `CLAUDE_MODEL_FAMILY` | Default Hosted-on-Azure model |
|---|---|
| `opus` | `claude-opus-5` v2 |
| `sonnet` | `claude-sonnet-5` v2 |
| `haiku` | `claude-haiku-4-5` v2 |

Greenfield defaults to Sonnet at 25K TPM. The preflight checks the live regional catalog and the Hosted-on-Azure quota pool before deployment.

## Quickstart

Prerequisites: Azure CLI, `jq`, Git, Bash/Zsh, and current Claude Code (`2.1.203+`).

```bash
git clone https://github.com/msftnadavbh/claudecodepoc.git
cd claudecodepoc
cp .env.azure.example .env.azure.local
# Edit .env.azure.local

./scripts/login-azure.sh
./scripts/register-providers.sh
./scripts/preflight-model.sh
./scripts/validate-infra.sh --gateway
./scripts/deploy.sh
./scripts/configure-claude.sh
```

Restart the shell, or source the profile printed by the setup script, then run:

```bash
claude
```

For one-off use without changing the shell profile:

```bash
./scripts/claude-apim.sh
```

## Automatic Claude Code Setup

`./scripts/configure-claude.sh` makes plain `claude` use Foundry through APIM automatically:

1. Writes a small launcher to `~/.config/claudecodepoc/claude.sh`.
2. Sources it from `~/.bashrc` or `~/.zshrc`.
3. Routes `claude` to `scripts/claude-apim.sh`.
4. On every launch, fetches the APIM subscription key from Azure without saving it.
5. Sets Foundry mode, the APIM base URL, skipped local Foundry auth, the APIM key header, and model deployment aliases.

Result: after one shell reload, users run normal `claude`; all model traffic goes Claude Code → APIM → Foundry.

## Greenfield Configuration

Greenfield requires globally unique Foundry/APIM names and accurate Marketplace attestation values:

```bash
DEPLOYMENT_MODE=greenfield
CLAUDE_MODEL_FAMILY=sonnet
CLAUDE_MODEL_CAPACITY=25
CLAUDE_ORGANIZATION_NAME="Your legal organization name"
CLAUDE_COUNTRY_CODE=US
CLAUDE_INDUSTRY=technology
```

Deploying accepts the applicable Anthropic Marketplace terms through `modelProviderData`. Review the legal links below and never use placeholder attestation values.

## Brownfield Configuration

Set `DEPLOYMENT_MODE=brownfield` and provide the exact existing resource group, Foundry resource, project, deployment, model, and version. Validation confirms the live resources and Bicep keeps them external and read-only.

## macOS

```bash
brew install --cask claude-code
brew install azure-cli jq
```

Then follow the Quickstart. `scripts/configure-claude.sh` detects Zsh and updates `~/.zshrc`. Homebrew Claude Code does not auto-update; use `brew upgrade --cask claude-code`.

## How Authentication Works

- Claude Code fetches an APIM subscription key at launch and keeps it only in the process environment.
- APIM strips client credentials and authenticates to Foundry with its system-assigned managed identity.
- APIM receives `Cognitive Services User` at the Foundry account scope.
- Requests stay in native Anthropic Messages format, including SSE and token counting.
- Diagnostics log metadata and safe headers only; request/response bodies are logged as zero bytes.

## Useful Commands

```bash
./scripts/discover-foundry.sh          # Preview greenfield or verify brownfield
./scripts/validate-infra.sh --gateway  # ARM validation and what-if
./scripts/run-claude-code-smoke.sh     # End-to-end coding-agent test
./tests/test-config.sh                 # Local configuration test
```

Local identifiers, Azure CLI state, generated environment files, deployment evidence, and Claude state are gitignored.

## Sources And Terms

- [Anthropic: Claude Code on Microsoft Foundry](https://code.claude.com/docs/en/microsoft-foundry)
- [Anthropic: connect Claude Code to an LLM gateway](https://code.claude.com/docs/en/llm-gateway-connect)
- [Microsoft Learn: deploy Claude with Bicep or Terraform](https://learn.microsoft.com/azure/developer/ai/how-to/deploy-claude-foundry)
- [Microsoft Learn: Claude models in Microsoft Foundry](https://learn.microsoft.com/azure/foundry/foundry-models/concepts/claude-models)
- [Anthropic Commercial Terms](https://www.anthropic.com/legal/commercial-terms)
- [Anthropic Usage Policy](https://www.anthropic.com/legal/aup)
- [Anthropic Supported Regions Policy](https://aka.ms/supported_anthropic_regions)
- [Microsoft Product Terms](https://www.microsoft.com/licensing/terms/)

See [`docs/design.md`](docs/design.md) for protocol and security details.
