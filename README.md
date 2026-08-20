# Claude Code on Microsoft Foundry through Azure API Management

This repository deploys Claude on Microsoft Foundry behind Azure API Management (APIM), then configures local Claude Code to use the gateway.

```text
Claude Code
  -> APIM subscription authentication
  -> APIM system-assigned managed identity
  -> Microsoft Foundry native Anthropic Messages API
  -> your Claude deployment
```

The gateway preserves the native Anthropic Messages contract. It does not translate requests to OpenAI formats.

## Deployment Modes

### Greenfield (Default)

Greenfield starts with an otherwise empty subscription and creates:

- A resource group.
- A Microsoft Foundry AIServices account and project.
- One selected Claude model deployment.
- APIM Standard v2 with a system-assigned managed identity.
- Native `POST /v1/messages` and `POST /v1/messages/count_tokens` routes.
- Log Analytics and Application Insights with zero-byte body logging.
- Resource-scoped APIM RBAC and an APIM subscription for local Claude Code.

### Brownfield

Brownfield reuses an existing resource group, Foundry account, project, and Claude deployment. Bicep treats those resources as external and creates or updates only APIM, observability, API configuration, and APIM RBAC.

Set `DEPLOYMENT_MODE=brownfield` and provide the exact existing names in `.env.azure.local`.

## Model Selection

Set `CLAUDE_MODEL_FAMILY` to one of:

| Family | Default Hosted-on-Azure model | Default version |
|--------|-------------------------------|-----------------|
| `opus` | `claude-opus-5` | `2` |
| `sonnet` | `claude-sonnet-5` | `2` |
| `haiku` | `claude-haiku-4-5` | `2` |

Greenfield defaults to Sonnet with 25K TPM. Override `CLAUDE_MODEL_NAME`, `CLAUDE_MODEL_VERSION`, `CLAUDE_MODEL_CAPACITY`, or `CLAUDE_DEPLOYMENT_NAME` when needed.

Before validation or deployment, `scripts/preflight-model.sh` checks:

- The exact model/version appears in the live regional catalog with `hostedOn=azure`.
- The subscription exposes the Hosted-on-Azure quota row `AIServices.GlobalStandard.<model>.Azure`.
- Available quota is at least the requested capacity.
- The greenfield target resource group does not already exist.

Brownfield validates the live catalog and the existing deployment but does not require unused quota for capacity already allocated.

## What The Gateway Deploys

- APIM Standard v2 with a system-assigned managed identity.
- Native `POST /v1/messages` and `POST /v1/messages/count_tokens` routes.
- A Foundry backend using Microsoft Entra authentication.
- A resource-scoped `Cognitive Services User` assignment for APIM.
- Log Analytics and Application Insights with zero-byte request and response body logging.
- An APIM subscription used by local Claude Code.

In greenfield these gateway resources are deployed with the new Foundry resources. In brownfield only the gateway side is managed by this repository.

## Prerequisites

- Greenfield: an Azure subscription eligible for Anthropic Claude through Azure Marketplace.
- Brownfield: an existing Microsoft Foundry account, project, and deployed Claude model.
- Owner or equivalent deployment and role-assignment permissions on the target scope.
- Azure CLI, `jq`, `curl`, Git, and Python 3.
- Claude Code installed with Anthropic's native installer or Homebrew.
- Bash on Linux/WSL, or Bash/Zsh on macOS.

Claude Code versions before `2.1.203` do not fully support skipped Foundry authentication without a Foundry API key. Use a current release.

## Configure The Target

Clone the public repository:

```bash
git clone https://github.com/msftnadavbh/claudecodepoc.git
cd claudecodepoc
```

Create the ignored local configuration:

```bash
cp .env.azure.example .env.azure.local
```

Edit `.env.azure.local` with your tenant, subscription, resource names, model choice, globally unique APIM name, and publisher details.

For greenfield, also provide accurate Marketplace attestation values:

- `CLAUDE_ORGANIZATION_NAME`: legal organization name.
- `CLAUDE_COUNTRY_CODE`: two-letter country code.
- `CLAUDE_INDUSTRY`: one of the values listed in `.env.azure.example`.

Deploying greenfield sends these values as `modelProviderData` and accepts the Anthropic Marketplace terms on the represented organization's behalf. Review the linked terms before deployment; do not use placeholder values.

The required values are documented in `.env.azure.example`. No Azure target identifiers or credentials need to be committed.

## Authenticate To Azure

```bash
./scripts/login-azure.sh
```

The repository uses an isolated Azure CLI context and refuses to continue when the authenticated tenant or subscription differs from `.env.azure.local`.

### WSL And Managed Windows Devices

When Windows Azure CLI is installed, the scripts automatically invoke it from WSL. Authentication then uses Windows Web Account Manager (WAM), which supports Windows Hello and managed-device Conditional Access. The token cache remains on the Windows filesystem under `%LOCALAPPDATA%\<AZURE_CLI_CACHE_NAME>\azure-cli`.

If Windows Azure CLI is unavailable, the scripts use the Linux Azure CLI with a repository-local cache under `.azure/cli`.

### macOS

Install Azure CLI and sign in with the browser:

```bash
brew update
brew install azure-cli
./scripts/login-azure.sh
```

macOS uses the native Azure CLI and an ignored repository-local cache. If your organization requires a broker or compliant-device flow, follow its approved macOS Company Portal and Azure CLI authentication policy.

## Preflight

```bash
./scripts/check-prereqs.sh
./scripts/register-providers.sh
./scripts/preflight-model.sh
./scripts/discover-foundry.sh
```

In greenfield, discovery prints the resources that will be created. In brownfield, it fails unless configured names and model metadata match live Azure state.

## Deploy The Gateway

Preview the exact changes:

```bash
./scripts/validate-infra.sh --gateway
```

Review the what-if output. Greenfield should show resource-group, Foundry, model, gateway, and observability creates. Brownfield should show existing Foundry resources as ignored references, never updates or deletions.

Deploy:

```bash
./scripts/deploy.sh
```

The deployment is incremental. It may register the `Microsoft.CognitiveServices`, `Microsoft.ApiManagement`, `Microsoft.Insights`, and `Microsoft.OperationalInsights` resource providers.

## Configure Local Claude Code Automatically

The setup command configures plain `claude` for the current Bash or Zsh user:

```bash
./scripts/configure-claude.sh
```

Restart the shell, or source the profile named by the script. Then run:

```bash
claude
```

The setup writes a small loader under `${XDG_CONFIG_HOME:-~/.config}/claudecodepoc/` and sources it from `~/.bashrc` or `~/.zshrc`. The loader calls this clone's `scripts/claude-apim.sh`. It does not copy or persist the APIM key.

Check the setup at any time:

```bash
./scripts/configure-claude.sh --check
```

### macOS Automatic Setup

For the default macOS Zsh shell:

```bash
brew install --cask claude-code
brew install azure-cli jq
cp .env.azure.example .env.azure.local
# Edit .env.azure.local
./scripts/login-azure.sh
./scripts/register-providers.sh
./scripts/preflight-model.sh
./scripts/discover-foundry.sh
./scripts/validate-infra.sh --gateway
./scripts/deploy.sh
./scripts/configure-claude.sh
source ~/.zshrc
claude
```

Homebrew installations do not auto-update Claude Code. Update periodically with:

```bash
brew upgrade --cask claude-code
```

### Portable One-Off Use

Without modifying a shell profile:

```bash
./scripts/claude-apim.sh
```

## How Claude Code Is Configured

At runtime, `scripts/activate-apim.sh`:

- Sets `CLAUDE_CODE_USE_FOUNDRY=1`.
- Sets `ANTHROPIC_FOUNDRY_BASE_URL` to the APIM API base path.
- Sets `CLAUDE_CODE_SKIP_FOUNDRY_AUTH=1` because APIM injects backend authorization.
- Retrieves the APIM subscription key from Azure and sends it through `ANTHROPIC_CUSTOM_HEADERS` as `Ocp-Apim-Subscription-Key`.
- Maps Claude Code's Opus, Sonnet, and Haiku roles to the configured deployment so background work never targets a missing deployment.
- Unsets direct Foundry API-key and bearer-token variables.

Claude Code appends `/v1/messages` and `/v1/messages/count_tokens`. APIM removes client `Authorization`, `x-api-key`, and subscription-key headers before obtaining a Microsoft Entra token for `https://ai.azure.com`.

The APIM subscription key is fetched for each launcher invocation and exists only in the process environment. It is never written to the repository.

## Verify Claude Code

```bash
./scripts/claude-apim.sh \
  --model opus \
  --print \
  --tools "" \
  --no-session-persistence \
  "Reply with exactly: APIM_OK"
```

Inside an interactive session, run `/status`. The provider should be Microsoft Foundry, the base URL should be your APIM endpoint, and the selected model should resolve to your deployment name.

Run the deterministic coding-agent smoke test:

```bash
./scripts/run-claude-code-smoke.sh
```

## Operations

| Task | Command |
|------|---------|
| Authenticate isolated Azure CLI | `./scripts/login-azure.sh` |
| Check prerequisites and context | `./scripts/check-prereqs.sh` |
| Register required Azure providers | `./scripts/register-providers.sh` |
| Check model catalog and quota | `./scripts/preflight-model.sh` |
| Preview resources or verify brownfield target | `./scripts/discover-foundry.sh` |
| Refresh generated non-secret values | `./scripts/write-generated-env.sh` |
| Preview gateway changes | `./scripts/validate-infra.sh --gateway` |
| Deploy greenfield or update brownfield | `./scripts/deploy.sh` |
| Configure plain `claude` | `./scripts/configure-claude.sh` |
| Run Claude Code through APIM | `./scripts/claude-apim.sh` |
| Confirm the intentionally failing demo fixture | `cd demo-repo && python3 -m unittest discover -s tests -v` |

## Security Boundary

- Never commit `.env.azure.local`, `.env.azure.generated`, `.azure/`, `.claude-runtime/`, `CLAUDE.local.md`, or local Bicep parameter files.
- Never print or persist APIM keys, Azure tokens, API keys, or bearer tokens.
- Request and response bodies are not logged by APIM diagnostics.
- APIM receives only resource-scoped data-plane roles.
- Brownfield Foundry account, project, and model deployment remain unmanaged existing resources.
- The API accepts native Anthropic Messages and preserves upstream headers, streaming, and errors.

For restricted egress, source `scripts/activate-apim-restricted.sh`. It disables nonessential Claude Code traffic; WebFetch domain checks require separate handling.

## Sources

- [Anthropic: Claude Code on Microsoft Foundry](https://code.claude.com/docs/en/microsoft-foundry)
- [Anthropic: connect Claude Code to an LLM gateway](https://code.claude.com/docs/en/llm-gateway-connect)
- [Anthropic: gateway protocol reference](https://code.claude.com/docs/en/llm-gateway-protocol)
- [Microsoft Learn: configure Claude Code for Microsoft Foundry](https://learn.microsoft.com/azure/foundry/foundry-models/how-to/configure-claude-code)
- [Microsoft Learn: Claude models in Microsoft Foundry](https://learn.microsoft.com/azure/foundry/foundry-models/concepts/claude-models)
- [Microsoft Learn: deploy Claude with Bicep or Terraform](https://learn.microsoft.com/azure/developer/ai/how-to/deploy-claude-foundry)
- [Microsoft Learn: APIM generative AI gateway capabilities](https://learn.microsoft.com/azure/api-management/genai-gateway-capabilities)

The implementation was checked against Anthropic documentation through Context7 and against current Microsoft Learn guidance.

Greenfield deployment accepts the applicable Marketplace terms through `modelProviderData`. Review [Anthropic Commercial Terms](https://www.anthropic.com/legal/commercial-terms), [Anthropic Usage Policy](https://www.anthropic.com/legal/aup), [Anthropic Supported Regions Policy](https://aka.ms/supported_anthropic_regions), and [Microsoft Product Terms](https://www.microsoft.com/licensing/terms/) before deploying.
