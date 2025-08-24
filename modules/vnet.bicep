param vnetName string
param location string 
param addressSpace string
param additionalAddressSpaces array = []
param dnsServers array = []
param tags object = {}

// VNet リソースの作成
resource vnet 'Microsoft.Network/virtualNetworks@2023-04-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: union([addressSpace], additionalAddressSpaces)
    }
    dhcpOptions: empty(dnsServers) ? null : {
      dnsServers: dnsServers
    }
  }
}

output vnetId string = vnet.id
output vnetName string = vnet.name
output addressSpace string = addressSpace
output location string = location
