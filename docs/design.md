# Design Notes

## Scope

This repository adds an APIM gateway in front of an existing Claude deployment in Microsoft Foundry. It intentionally does not provision the model plane.

## Protocol

Foundry exposes the native Anthropic Messages API. APIM forwards:

- `POST /v1/messages`
- `POST /v1/messages/count_tokens`
- Query parameters such as `?beta=true`
- `anthropic-version` and `anthropic-beta` headers
- Server-sent events without response buffering
- Native upstream errors without wrapping

Request and response bodies are not transformed.

## Authentication

Claude Code authenticates to APIM with an APIM subscription key in `Ocp-Apim-Subscription-Key`. The local launcher retrieves this key from Azure at runtime.

APIM deletes client `Authorization`, `x-api-key`, and subscription-key headers before forwarding. Its managed identity obtains a token for `https://ai.azure.com` and receives `Cognitive Services User` at the Foundry account scope.

## Claude Code

The supported client configuration uses:

```bash
CLAUDE_CODE_USE_FOUNDRY=1
ANTHROPIC_FOUNDRY_BASE_URL=https://<apim-name>.azure-api.net/claude
CLAUDE_CODE_SKIP_FOUNDRY_AUTH=1
ANTHROPIC_CUSTOM_HEADERS="Ocp-Apim-Subscription-Key: <runtime-value>"
```

Model-role variables must contain Azure deployment names, not catalog model names. This repository maps all three roles to one configured deployment by default, which is appropriate when only one Claude deployment exists.

## Observability

APIM diagnostics use Application Insights with zero body bytes. Safe metadata includes API, operation, session ID, and agent IDs. Token metrics and token limiting remain opt-in because they require separate runtime validation for the API classification and desired quota policy.

## Local State

The public repository contains only examples. Actual tenant, subscription, resource names, deployment evidence, Azure CLI caches, Claude state, and generated environment files are ignored so operators retain them locally without publishing them.

## Sources

- [Anthropic Microsoft Foundry](https://code.claude.com/docs/en/microsoft-foundry)
- [Anthropic LLM gateway connection](https://code.claude.com/docs/en/llm-gateway-connect)
- [Anthropic gateway protocol](https://code.claude.com/docs/en/llm-gateway-protocol)
- [Microsoft Learn Claude Code configuration](https://learn.microsoft.com/azure/foundry/foundry-models/how-to/configure-claude-code)
- [Microsoft Learn APIM GenAI gateway](https://learn.microsoft.com/azure/api-management/genai-gateway-capabilities)
