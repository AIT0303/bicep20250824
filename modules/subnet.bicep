param vnetName string
param subnetName string
param addressPrefix string
param networkSecurityGroupId string = ''
param routeTableId string = ''
param serviceEndpoints array = []
param privateEndpointNetworkPolicies string = 'Disabled'
param privateLinkServiceNetworkPolicies string = 'Enabled'
param delegations array = []

// 既存のVNetを参照
resource existingVnet 'Microsoft.Network/virtualNetworks@2023-04-01' existing = {
  name: vnetName
}

// サブネット リソースの作成
resource subnet 'Microsoft.Network/virtualNetworks/subnets@2023-04-01' = {
  parent: existingVnet
  name: subnetName
  properties: {
    addressPrefix: addressPrefix
    networkSecurityGroup: !empty(networkSecurityGroupId) ? {
      id: networkSecurityGroupId
    } : null
    routeTable: !empty(routeTableId) ? {
      id: routeTableId
    } : null
    serviceEndpoints: serviceEndpoints
    privateEndpointNetworkPolicies: privateEndpointNetworkPolicies
    privateLinkServiceNetworkPolicies: privateLinkServiceNetworkPolicies
    delegations: delegations
  }
}

output subnetId string = subnet.id
output subnetName string = subnet.name
output addressPrefix string = addressPrefix
