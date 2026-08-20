#!/usr/bin/env bash

BICEP_PARAMETERS=(
  --parameters
  deploymentMode="$DEPLOYMENT_MODE"
  location="$AZURE_LOCATION"
  resourceGroupName="$FOUNDRY_RESOURCE_GROUP"
  foundryName="$FOUNDRY_RESOURCE_NAME"
  foundryProjectName="$FOUNDRY_PROJECT_NAME"
  claudeDeploymentName="$CLAUDE_DEPLOYMENT_NAME"
  expectedClaudeModelName="$CLAUDE_MODEL_NAME"
  expectedClaudeModelVersion="$CLAUDE_MODEL_VERSION"
  claudeModelCapacity="$CLAUDE_MODEL_CAPACITY"
  claudeOrganizationName="$CLAUDE_ORGANIZATION_NAME"
  claudeCountryCode="$CLAUDE_COUNTRY_CODE"
  claudeIndustry="$CLAUDE_INDUSTRY"
  apimName="$APIM_RESOURCE_NAME"
  workspaceName="$LOG_ANALYTICS_WORKSPACE_NAME"
  appInsightsName="$APP_INSIGHTS_NAME"
  apimSubscriptionName="$APIM_SUBSCRIPTION_NAME"
  publisherName="$PUBLISHER_NAME"
  publisherEmail="$PUBLISHER_EMAIL"
)
