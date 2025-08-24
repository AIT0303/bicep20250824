param name string
param location string
param tenantId string
param objectId string
//param secrets array
param logAnalyticsWorkspaceId string
param storageAccountId string
param allowedIPs array

resource keyVault 'Microsoft.KeyVault/vaults@2021-04-01-preview' = {
  name: name
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: tenantId
    accessPolicies: [
      {
        tenantId: tenantId
        objectId: objectId
        permissions: {
          keys: ['get', 'list', 'create', 'delete', 'recover', 'backup', 'restore']
          secrets: ['get', 'list', 'set', 'delete', 'recover', 'backup', 'restore']
          certificates: ['get', 'list', 'create', 'delete', 'recover', 'backup', 'restore']
        }
      }
    ]
    enabledForDeployment: true
    enabledForTemplateDeployment: true
    enabledForDiskEncryption: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      ipRules: [
        for ip in allowedIPs: {
          value: ip
        }
      ]
    }
  }
}
/*
// シークレットを追加するループ  (他モジュールに記載しているためコメントアウト)
resource keyVaultSecrets 'Microsoft.KeyVault/vaults/secrets@2021-04-01-preview' = [
  for secret in secrets: {
    name: secret.name
    properties: {
      value: secret.value
    }
  }
]
*/
resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${name}-diagnostic'
  scope: keyVault
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    storageAccountId: storageAccountId
    logs: [
      {
        category: 'AuditEvent'
        enabled: true
      }
      {
        category: 'AzurePolicyEvaluationDetails'
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


output keyVaultId string = keyVault.id
output keyVaultUri string = keyVault.properties.vaultUri
output keyVaultName string = keyVault.name
