param apimName string
param foundryName string
param claudeDeploymentName string
param apimSubscriptionName string
param appInsightsName string
param appInsightsConnectionString string
param enableClaudeTokenMetrics bool
param enableClaudeTokenLimit bool
param claudeTokenLimitPerMinute int

resource apim 'Microsoft.ApiManagement/service@2024-05-01' existing = {
  name: apimName
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appInsightsName
}

var tokenMetricPolicy = enableClaudeTokenMetrics ? '''
        <llm-emit-token-metric namespace="ClaudeCode">
            <dimension name="API" value="@(context.Api.Id)" />
            <dimension name="Operation" value="@(context.Operation.Id)" />
            <dimension name="Subscription" value="@(context.Subscription.Id)" />
            <dimension name="ClaudeSession" value="@(context.Request.Headers.GetValueOrDefault(&quot;X-Claude-Code-Session-Id&quot;, &quot;none&quot;))" />
            <dimension name="ClaudeAgent" value="@(context.Request.Headers.GetValueOrDefault(&quot;X-Claude-Code-Agent-Id&quot;, &quot;none&quot;))" />
        </llm-emit-token-metric>''' : ''
var tokenLimitPolicy = enableClaudeTokenLimit ? '<llm-token-limit counter-key="@(context.Subscription.Id)" tokens-per-minute="${claudeTokenLimitPerMinute}" estimate-prompt-tokens="false" />' : ''
var policy = replace(replace(replace(loadTextContent('../../apim/policies/claude.xml'), '{{TOKEN_METRIC_POLICY}}', tokenMetricPolicy), '{{TOKEN_LIMIT_POLICY}}', tokenLimitPolicy), '{{CLAUDE_DEPLOYMENT_NAME}}', claudeDeploymentName)

resource backend 'Microsoft.ApiManagement/service/backends@2024-05-01' = {
  parent: apim
  name: 'foundry-claude'
  properties: {
    description: 'Native Anthropic Messages endpoint on Microsoft Foundry.'
    protocol: 'http'
    type: 'Single'
    url: 'https://${foundryName}.services.ai.azure.com/anthropic'
    tls: {
      validateCertificateChain: true
      validateCertificateName: true
    }
  }
}

resource api 'Microsoft.ApiManagement/service/apis@2024-05-01' = {
  parent: apim
  name: 'claude-api'
  properties: {
    apiType: 'http'
    description: 'Native Anthropic Messages passthrough for Claude Code.'
    displayName: 'Claude Messages'
    path: 'claude'
    protocols: [
      'https'
    ]
    serviceUrl: backend.properties.url
    subscriptionKeyParameterNames: {
      header: 'Ocp-Apim-Subscription-Key'
      query: 'subscription-key'
    }
    subscriptionRequired: true
    type: 'http'
  }
}

resource messages 'Microsoft.ApiManagement/service/apis/operations@2024-05-01' = {
  parent: api
  name: 'messages'
  properties: {
    displayName: 'Create Message'
    method: 'POST'
    urlTemplate: '/v1/messages'
  }
}

resource countTokens 'Microsoft.ApiManagement/service/apis/operations@2024-05-01' = {
  parent: api
  name: 'count-tokens'
  properties: {
    displayName: 'Count Message Tokens'
    method: 'POST'
    urlTemplate: '/v1/messages/count_tokens'
  }
}

resource apiPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-05-01' = {
  parent: api
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: policy
  }
}

resource subscription 'Microsoft.ApiManagement/service/subscriptions@2024-05-01' = {
  parent: apim
  name: apimSubscriptionName
  properties: {
    allowTracing: false
    displayName: 'Claude Code PoC'
    scope: '/apis/${api.name}'
    state: 'active'
  }
}

resource logger 'Microsoft.ApiManagement/service/loggers@2024-05-01' = {
  parent: apim
  name: 'applicationinsights'
  properties: {
    credentials: {
      connectionString: appInsightsConnectionString
      identityClientId: 'SystemAssigned'
    }
    description: 'Metadata-only gateway telemetry via managed identity.'
    isBuffered: true
    loggerType: 'applicationInsights'
    resourceId: appInsights.id
  }
}

var safeRequestHeaders = [
  'anthropic-version'
  'anthropic-beta'
  'X-Claude-Code-Session-Id'
  'X-Claude-Code-Agent-Id'
  'X-Claude-Code-Parent-Agent-Id'
]
var safeResponseHeaders = [
  'request-id'
  'retry-after'
]

resource diagnostic 'Microsoft.ApiManagement/service/apis/diagnostics@2024-05-01' = {
  parent: api
  name: 'applicationinsights'
  properties: {
    alwaysLog: 'allErrors'
    httpCorrelationProtocol: 'W3C'
    logClientIp: false
    loggerId: logger.id
    metrics: true
    operationNameFormat: 'Name'
    sampling: {
      percentage: 100
      samplingType: 'fixed'
    }
    verbosity: 'information'
    frontend: {
      request: {
        headers: safeRequestHeaders
        body: {
          bytes: 0
        }
      }
      response: {
        headers: safeResponseHeaders
        body: {
          bytes: 0
        }
      }
    }
    backend: {
      request: {
        headers: safeRequestHeaders
        body: {
          bytes: 0
        }
      }
      response: {
        headers: safeResponseHeaders
        body: {
          bytes: 0
        }
      }
    }
  }
}

output apiName string = api.name
output subscriptionName string = subscription.name
output claudeBaseUrl string = '${apim.properties.gatewayUrl}/claude'
