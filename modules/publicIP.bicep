param publicIpName string
param location string
param allocationMethod string = 'Static'
param sku string = 'Standard'
param zones array = []
param tags object = {}

resource publicIp 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
  name: publicIpName
  location: location
  sku: {
    name: sku
  }
  zones: zones
  properties: {
    publicIPAllocationMethod: allocationMethod
    publicIPAddressVersion: 'IPv4'
  }
  tags: tags
}

output publicIpId string = publicIp.id
output publicIpName string = publicIp.name
output publicIpAddress string = publicIp.properties.ipAddress
