#!/usr/bin/env bash

BICEP_PARAMETERS=(
  --parameters
  location="$AZURE_LOCATION"
  resourceGroupName="$FOUNDRY_RESOURCE_GROUP"
  foundryName="$FOUNDRY_RESOURCE_NAME"
  foundryProjectName="$FOUNDRY_PROJECT_NAME"
  claudeDeploymentName="$CLAUDE_DEPLOYMENT_NAME"
  expectedClaudeModelName="$CLAUDE_MODEL_NAME"
  expectedClaudeModelVersion="$CLAUDE_MODEL_VERSION"
  apimName="$APIM_RESOURCE_NAME"
  workspaceName="$LOG_ANALYTICS_WORKSPACE_NAME"
  appInsightsName="$APP_INSIGHTS_NAME"
  apimSubscriptionName="$APIM_SUBSCRIPTION_NAME"
  publisherName="$PUBLISHER_NAME"
  publisherEmail="$PUBLISHER_EMAIL"
)
