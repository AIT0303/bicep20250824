param name string
param location string
param sku string
//param allowedIpRanges array
param logAnalyticsWorkspaceId string
param storageAccountId string

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' = {
  name: name
  location: location
  sku: {
    name: sku
  }
  properties: {
    adminUserEnabled: true
   // skuがPremium以外はコメントアウト
    networkRuleSet: {
      defaultAction: 'Allow'
      /*
      ipRules: [
        for ip in allowedIpRanges: {
          action: 'Allow'
          value: ip
        }
      ]
        */
  }
}
}

//診断設定
resource diagnosticSetting 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'DiagnosticSetting'
  scope: containerRegistry
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    storageAccountId: storageAccountId
    logs: [
      {
        category: 'ContainerRegistryLoginEvents'
        enabled: true
      }
      {
        category: 'ContainerRegistryRepositoryEvents'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}


output acrId string = containerRegistry.id
output acrName string = containerRegistry.name
output acrLoginServer string = containerRegistry.properties.loginServer
