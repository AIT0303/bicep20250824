param nsgName string
param location string 
param allowedSubnetAddressPrefixes array = []
param tags object = {}
param enableDiagnostics bool = false
param logAnalyticsWorkspaceId string = ''
param storageAccountId string = ''

// 基本のセキュリティルール
var baseSecurityRules = [
  {
    name: 'Allow-SqlServer-Management'
    properties: {
      priority: 1000
      direction: 'Inbound'
      access: 'Allow'
      protocol: 'Tcp'
      sourcePortRange: '*'
      destinationPortRange: '1433'
      sourceAddressPrefix: 'SqlManagement'
      destinationAddressPrefix: '*'
    }
  }
  {
    name: 'Allow-AzureServices'
    properties: {
      priority: 1001
      direction: 'Inbound'
      access: 'Allow'
      protocol: 'Tcp'
      sourcePortRange: '*'
      destinationPortRange: '1433'
      sourceAddressPrefix: 'AzureCloud'
      destinationAddressPrefix: '*'
    }
  }
  {
    name: 'Deny-Internet-Inbound'
    properties: {
      priority: 4000
      direction: 'Inbound'
      access: 'Deny'
      protocol: '*'
      sourcePortRange: '*'
      destinationPortRange: '*'
      sourceAddressPrefix: 'Internet'
      destinationAddressPrefix: '*'
    }
  }
  {
    name: 'Allow-SqlServer-Outbound'
    properties: {
      priority: 1000
      direction: 'Outbound'
      access: 'Allow'
      protocol: 'Tcp'
      sourcePortRange: '*'
      destinationPortRange: '443'
      sourceAddressPrefix: '*'
      destinationAddressPrefix: 'Sql'
    }
  }
  {
    name: 'Allow-Storage-Outbound'
    properties: {
      priority: 1001
      direction: 'Outbound'
      access: 'Allow'
      protocol: 'Tcp'
      sourcePortRange: '*'
      destinationPortRange: '443'
      sourceAddressPrefix: '*'
      destinationAddressPrefix: 'Storage'
    }
  }
]

// 動的に生成されるアプリサブネット用ルール
var appSubnetRules = [for (prefix, index) in allowedSubnetAddressPrefixes: {
  name: 'Allow-App-Subnet-${index + 1}'
  properties: {
    priority: 2000 + index
    direction: 'Inbound'
    access: 'Allow'
    protocol: 'Tcp'
    sourcePortRange: '*'
    destinationPortRange: '1433'
    sourceAddressPrefix: prefix
    destinationAddressPrefix: '*'
  }
}]

// 最終的なセキュリティルール
var sqlSecurityRules = union(baseSecurityRules, appSubnetRules)

// NSG リソースの作成
resource nsg 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
  name: nsgName
  location: location
  tags: tags
  properties: {
    securityRules: sqlSecurityRules
  }
}

// 診断設定
resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnostics) {
  name: '${nsgName}-diagnostics'
  scope: nsg
  properties: {
    workspaceId: !empty(logAnalyticsWorkspaceId) ? logAnalyticsWorkspaceId : null
    storageAccountId: !empty(storageAccountId) ? storageAccountId : null
    logs: [
      {
        category: 'NetworkSecurityGroupEvent'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'NetworkSecurityGroupRuleCounter'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}

output nsgId string = nsg.id
output nsgName string = nsg.name
output location string = location
