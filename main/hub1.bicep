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


// container apps用 NSG作成
module caNsg '../modules/nsg/ca_nsg.bicep' = {
  name: '${role}-ca-nsg'
  scope: resourceGroup(existingRg.name)
  params: {
    nsgName: '${development}-${role}-ca-nsg01'
    location: location
  }
}


// ルートテーブル作成
module sqlRt '../modules/routeTable.bicep' = {
  name: '${role}-sql-rt'
  scope: resourceGroup(existingRg.name)
  params: {
    routeTableName: '${development}-${role}-sql-rt'
    location: location
  }
}

//プライベートエンドポイント用 NSG作成
module sqlNsg '../modules/nsg/sql_nsg.bicep' = {
  name: '${role}-sql-nsg'
  scope: resourceGroup(existingRg.name)
  params: {
    nsgName: '${development}-${role}-sql-nsg01'
    location: location
  }
}

//プライベートエンドポイント用 NSG作成
module vmNsg '../modules/nsg/vm_nsg.bicep' = {
  name: '${role}-vm-nsg'
  scope: resourceGroup(existingRg.name)
  params: {
    nsgName: '${development}-${role}-vm-nsg01'
    location: location
  }
}

// サブネット定義（※アドレス重複は調整必要）
var subnets = [
  { name: '${development}-hub1-appgw-snet01', prefix: '${networkPrefix}.0.0/24', nsgType: 'none' }
  { name: 'AzureFirewallSubnet',              prefix: '${networkPrefix}.1.0/26', nsgType: 'none' }
  { name: '${development}-spoke1-ca-snet01',  prefix: '${networkPrefix}.10.0/27', nsgType: 'ca' }
  { name: '${development}-spoke2-pe-snet01',  prefix: '${networkPrefix}.20.0/24', pePolicies: 'Disabled', nsgType: 'none' }
  { name: '${development}-spoke2-sql-snet01', prefix: '${networkPrefix}.21.0/24', nsgType: 'sql'
    delegations: [
      {
        name: 'Microsoft.Sql.managedInstances'
        properties: {
          serviceName: 'Microsoft.Sql/managedInstances'
        }
      }
    ]
  }
  { name: '${development}-spoke2-ca-snet01',  prefix: '${networkPrefix}.22.0/27', nsgType: 'ca' }
  { name: '${development}-spoke3-vm-snet01',  prefix: '${networkPrefix}.30.0/24', nsgType: 'vm' }
  { name: '${development}-spoke3-pe-snet01',  prefix: '${networkPrefix}.31.0/24', pePolicies: 'Disabled', nsgType: 'none' }
  { name: '${development}-spoke4-pe-snet01',  prefix: '${networkPrefix}.40.0/24', pePolicies: 'Disabled', nsgType: 'none' }
  { name: '${development}-operation-snet01',  prefix: '${networkPrefix}.50.0/24', nsgType: 'vm' }
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
    networkSecurityGroupId: sn.nsgType == 'ca' ? caNsg.outputs.nsgId : sn.nsgType == 'sql' ? sqlNsg.outputs.nsgId : sn.nsgType == 'vm' ? vmNsg.outputs.nsgId : ''
    routeTableId: sn.nsgType == 'sql' ? sqlRt.outputs.routeTableId : ''
    serviceEndpoints: []
    privateLinkServiceNetworkPolicies: 'Enabled'
    delegations: []
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
  }
}
