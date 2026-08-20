# Claude Code Foundry Gateway

## Architecture

- Preserve native Anthropic Messages and SSE end to end.
- Do not translate requests or responses to OpenAI formats.
- Greenfield creates all resources; brownfield treats the configured Foundry account, project, and Claude deployment as read-only existing resources.
- APIM authenticates to Foundry with its system-assigned managed identity.
- Never log request/response bodies or source code.

## Local Configuration

- Environment-specific values live only in ignored `.env.azure.local` and `CLAUDE.local.md`.
- Public defaults and placeholders live in `.env.azure.example` and `infra/parameters/example.bicepparam`.
- Every Azure mutation must call `scripts/assert-azure-context.sh` first.
- Never switch tenants or subscriptions implicitly.
- Never delete a resource group or existing Foundry resource from this repository.

## Commands

- Login: `./scripts/login-azure.sh`
- Verify Foundry: `./scripts/discover-foundry.sh`
- Register providers: `./scripts/register-providers.sh`
- Preview IaC: `./scripts/validate-infra.sh --gateway`
- Deploy solution: `./scripts/deploy.sh`
- Configure Bash/Zsh: `./scripts/configure-claude.sh`
- Run Claude through APIM: `./scripts/claude-apim.sh`
- Demo tests: `python3 -m unittest discover -s tests -v` from `demo-repo/`

## Safety

- Do not expose, print, or commit credentials or local deployment identifiers.
- Fetch the APIM subscription key only at runtime.
- Keep integration tests sequential.
- Existing unrelated Azure resources are out of scope.
