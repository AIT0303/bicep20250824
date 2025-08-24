param nsgName string
param location string
param environment string = 'dev'
param project string = 'poc'
param allowedRdpSourceAddresses array = []
param allowedSshSourceAddresses array = []
param allowHttp bool = false
param allowHttps bool = false
param customRules array = []

// NSGリソース
resource nsg 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: nsgName
  location: location
  tags: {
    Environment: environment
    Project: project
  }
  properties: {
    securityRules: concat(
      // RDPルール (Windows VM用)
      !empty(allowedRdpSourceAddresses) ? [
        {
          name: 'AllowRDP'
          properties: {
            description: 'Allow RDP from specified sources'
            protocol: 'Tcp'
            sourcePortRange: '*'
            destinationPortRange: '3389'
            sourceAddressPrefixes: allowedRdpSourceAddresses
            destinationAddressPrefix: '*'
            access: 'Allow'
            priority: 1000
            direction: 'Inbound'
          }
        }
      ] : [],
      // SSHルール (Linux VM用)
      !empty(allowedSshSourceAddresses) ? [
        {
          name: 'AllowSSH'
          properties: {
            description: 'Allow SSH from specified sources'
            protocol: 'Tcp'
            sourcePortRange: '*'
            destinationPortRange: '22'
            sourceAddressPrefixes: allowedSshSourceAddresses
            destinationAddressPrefix: '*'
            access: 'Allow'
            priority: 1100
            direction: 'Inbound'
          }
        }
      ] : [],
      // HTTPルール
      allowHttp ? [
        {
          name: 'AllowHTTP'
          properties: {
            description: 'Allow HTTP traffic'
            protocol: 'Tcp'
            sourcePortRange: '*'
            destinationPortRange: '80'
            sourceAddressPrefix: 'Internet'
            destinationAddressPrefix: '*'
            access: 'Allow'
            priority: 1200
            direction: 'Inbound'
          }
        }
      ] : [],
      // HTTPSルール
      allowHttps ? [
        {
          name: 'AllowHTTPS'
          properties: {
            description: 'Allow HTTPS traffic'
            protocol: 'Tcp'
            sourcePortRange: '*'
            destinationPortRange: '443'
            sourceAddressPrefix: 'Internet'
            destinationAddressPrefix: '*'
            access: 'Allow'
            priority: 1300
            direction: 'Inbound'
          }
        }
      ] : [],
      // カスタムルール
      customRules
    )
  }
}

// 出力
output nsgId string = nsg.id
output nsgName string = nsg.name
output nsg object = nsg
