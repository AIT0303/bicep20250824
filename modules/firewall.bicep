param firewallName string
param location string
param subnetId string
param publicIpId string
param skuTier string = 'Standard'
param threatIntelMode string = 'Alert'
param tags object = {}
param FirewallPublicIP string

// NAT Rules用のパラメータ
param natRules array = [
  {
    name: 'SSH-NAT'
    description: '外部からVMへのSSH接続用'
    sourceAddresses: ['*']  // 任意の送信元
    destinationAddresses: [FirewallPublicIP]
    destinationPorts: ['22']
    protocols: ['TCP']
    translatedAddress: '10.0.1.4'   // 内部VMのPrivate IP
    translatedPort: '22'
  }
  {
    name: 'HTTP-NAT'
    description: 'WebサーバーHTTP公開用'
    sourceAddresses: ['*']
    destinationAddresses: [FirewallPublicIP]
    destinationPorts: ['80']
    protocols: ['TCP']
    translatedAddress: '10.0.1.5'   // 内部WebサーバーのPrivate IP
    translatedPort: '80'
  }
  {
    name: 'HTTPS-NAT'
    description: 'WebサーバーHTTPS公開用'
    sourceAddresses: ['*']
    destinationAddresses: [FirewallPublicIP]
    destinationPorts: ['443']
    protocols: ['TCP']
    translatedAddress: '10.0.1.5'   // 同じWebサーバーでもOK
    translatedPort: '443'
  }
]


// Azure Firewall Policy作成（NATルール含む）
resource firewallPolicy 'Microsoft.Network/firewallPolicies@2023-11-01' = {
  name: '${firewallName}-policy'
  location: location
  properties: {
    sku: {
      tier: skuTier
    }
    threatIntelMode: threatIntelMode
    threatIntelWhitelist: {
      fqdns: []
      ipAddresses: []
    }
  }
  tags: tags
}

// NAT Rule Collection Group (NATルールが指定されている場合のみ作成)
resource natRuleCollectionGroup 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2023-11-01' = if (length(natRules) > 0) {
  parent: firewallPolicy
  name: 'DefaultNatRuleCollectionGroup'
  properties: {
    priority: 100
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyNatRuleCollection'
        name: 'NatRules'
        priority: 100
        action: {
          type: 'Dnat'
        }
        rules: [for (rule, index) in natRules: {
          ruleType: 'NatRule'
          name: rule.name
          description: rule.?description ?? ''
          sourceAddresses: rule.sourceAddresses
          destinationAddresses: rule.destinationAddresses
          destinationPorts: rule.destinationPorts
          ipProtocols: rule.protocols
          translatedAddress: rule.translatedAddress
          translatedPort: rule.translatedPort
        }]
      }
    ]
  }
}

// Azure Firewall本体
resource azureFirewall 'Microsoft.Network/azureFirewalls@2023-11-01' = {
  name: firewallName
  location: location
  properties: {
    sku: {
      name: 'AZFW_VNet'
      tier: skuTier
    }
    ipConfigurations: [
      {
        name: 'FirewallIpConfiguration'
        properties: {
          subnet: {
            id: subnetId
          }
          publicIPAddress: {
            id: publicIpId
          }
        }
      }
    ]
    firewallPolicy: {
      id: firewallPolicy.id
    }
  }
  tags: tags
  dependsOn: [
    natRuleCollectionGroup
  ]
}

// Outputs
output firewallId string = azureFirewall.id
output firewallName string = azureFirewall.name
output firewallPolicyId string = firewallPolicy.id
output firewallPrivateIp string = azureFirewall.properties.ipConfigurations[0].properties.privateIPAddress
output publicIpAddress string = reference(publicIpId, '2023-11-01').ipAddress
