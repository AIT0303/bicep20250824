param nsgName string
param location string
param tags object = {}
param enableDiagnostics bool = false
param logAnalyticsWorkspaceId string = ''
param storageAccountId string = ''

// Container Apps用のセキュリティルール（内部定義）
var acaSecurityRules = [
  {
    name: 'Allow-HTTP-Inbound'
    properties: {
      priority: 1000
      direction: 'Inbound'
      access: 'Allow'
      protocol: 'Tcp'
      sourcePortRange: '*'
      destinationPortRange: '80'
      sourceAddressPrefix: '*'
      destinationAddressPrefix: '*'
    }
  }
  {
    name: 'Allow-HTTPS-Inbound'
    properties: {
      priority: 1001
      direction: 'Inbound'
      access: 'Allow'
      protocol: 'Tcp'
      sourcePortRange: '*'
      destinationPortRange: '443'
      sourceAddressPrefix: '*'
      destinationAddressPrefix: '*'
    }
  }
  {
    name: 'Allow-ContainerApps-Management'
    properties: {
      priority: 1002
      direction: 'Inbound'
      access: 'Allow'
      protocol: 'Tcp'
      sourcePortRange: '*'
      destinationPortRange: '25000-25999'
      sourceAddressPrefix: 'AzureContainerRegistry'
      destinationAddressPrefix: '*'
    }
  }
  {
    name: 'Allow-AzureLoadBalancer'
    properties: {
      priority: 1003
      direction: 'Inbound'
      access: 'Allow'
      protocol: '*'
      sourcePortRange: '*'
      destinationPortRange: '*'
      sourceAddressPrefix: 'AzureLoadBalancer'
      destinationAddressPrefix: '*'
    }
  }
  {
    name: 'Allow-ContainerApps-Outbound-Internet'
    properties: {
      priority: 1000
      direction: 'Outbound'
      access: 'Allow'
      protocol: 'Tcp'
      sourcePortRange: '*'
      destinationPortRange: '443'
      sourceAddressPrefix: '*'
      destinationAddressPrefix: 'Internet'
    }
  }
  {
    name: 'Allow-ContainerApps-Outbound-Storage'
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
  {
    name: 'Allow-DNS-Outbound'
    properties: {
      priority: 1002
      direction: 'Outbound'
      access: 'Allow'
      protocol: 'Udp'
      sourcePortRange: '*'
      destinationPortRange: '53'
      sourceAddressPrefix: '*'
      destinationAddressPrefix: '*'
    }
  }
]

// NSG リソースの作成
resource nsg 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
  name: nsgName
  location: location
  tags: tags
  properties: {
    securityRules: acaSecurityRules
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
