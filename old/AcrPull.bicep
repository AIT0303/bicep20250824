@description('ACR があるサブスクリプション ID（同一サブスクなら省略可）')
param acrSubscriptionId string = subscription().subscriptionId
param acrResourceGroup string
param acrName string
param principalId string
param roleDefinitionId string
param roleAssignmentName string = guid('${acrSubscriptionId}/${acrResourceGroup}/${acrName}', principalId, roleDefinitionId, 'acr-pull')


resource acr 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' existing = {
  scope: resourceGroup(acrResourceGroup)
  name: acrName
}

/* --- AcrPull を付与（スコープ=ACR） --- */
resource acrPullAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: roleAssignmentName
  properties: {
    roleDefinitionId: roleDefinitionId
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}

output roleAssignmentId string = acrPullAssignment.id
output acrId string = acr.id
