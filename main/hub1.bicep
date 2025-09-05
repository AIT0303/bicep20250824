targetScope = 'subscription'

// パラメータ定義（デフォルト値なし）
param development string = 'poc'
param role string        = 'hub1'
param location string    = 'japaneast'
param rgName string = '${development}-${role}-rg'

// 変数定義
var networkPrefix = '10.0'

// 既存のリソースグループを参照
resource existingRg 'Microsoft.Resources/resourceGroups@2023-07-01' existing = {
  name: rgName
}

// VNet 作成
module vnet '../modules/vnet.bicep' = {
  name: '${role}-vnet'
  scope: resourceGroup(existingRg.name)
  params: {
    vnetName: '${development}-${role}-vnet01'
    location: location
    addressSpace: '${networkPrefix}.0.0/16'
  }
}

var subnets = [
  { name: '${development}-hub1-appgw-snet01', prefix: '${networkPrefix}.0.0/24', nsgType: 'none', delegations: [] }
  { name: 'AzureFirewallSubnet',              prefix: '${networkPrefix}.1.0/26', nsgType: 'none', delegations: [] }
]

// VNet モジュールが完了してから各サブネットを作成
@batchSize(1)
module subnetsMod '../modules/subnet.bicep' = [for (sn, i) in subnets: {
  name: 'subnet-${i}-${sn.name}'
  scope: resourceGroup(existingRg.name)
  dependsOn: [ vnet ]
  params: {
    vnetName: '${development}-${role}-vnet01'
    subnetName: sn.name
    addressPrefix: sn.prefix
    serviceEndpoints: []
    privateLinkServiceNetworkPolicies: 'Enabled'
    delegations: sn.delegations
  }
}]

// WAFポリシー作成
module wafPolicy '../modules/waf.bicep' = {
  name: '${role}-waf-policy'
  scope: resourceGroup(existingRg.name)
  params: {
    name: '${development}-${role}-waf'
    location: location
  }
}

module appgwPublicIp '../modules/publicip.bicep' = {
  name: '${role}-appgw-pip'
  scope: resourceGroup(existingRg.name)
  params: {
    publicIpName: '${development}-${role}-appgw-pip01'
    location: location
  }
}

// Application Gateway作成
module applicationGateway '../modules/application_gateway.bicep' = {
  name: '${role}-appgw'
  scope: resourceGroup(existingRg.name)
  params: {
    applicationGatewayName: '${development}-${role}-appgw01'
    location: location
    subnetId: subnetsMod[0].outputs.subnetId
    publicIpid: appgwPublicIp.outputs.publicIpId
    backendTargets: [
      'example.com'
    ]
  }
}

module firewallPublicIp '../modules/publicip.bicep' = {
  name: '${role}-firewall-pip'
  scope: resourceGroup(existingRg.name)
  params: {
    publicIpName: '${development}-${role}-firewall-pip01'
    location: location
  }
}

module azureFirewall '../modules/firewall.bicep' = {
  name: '${role}-firewall'
  scope: resourceGroup(existingRg.name)
  params: {
    firewallName: '${development}-${role}-firewall01'
    location: location
    subnetId: subnetsMod[1].outputs.subnetId
    publicIpId: firewallPublicIp.outputs.publicIpId
    skuTier: 'Standard'  // または 'Premium'
    FirewallPublicIP:firewallPublicIp.outputs.publicIpAddress
  }
}
