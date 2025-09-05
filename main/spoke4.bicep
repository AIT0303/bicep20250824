targetScope = 'subscription'

// パラメータ定義
param development string = 'poc'
param role string = 'spoke4'
param location string = 'japaneast'
param rgName string = '${development}-${role}-rg'

// 変数定義
var networkPrefix = '10.4'

// 既存のリソースグループを参照
resource existingRg 'Microsoft.Resources/resourceGroups@2023-07-01' existing = {
  name: rgName
}

// Spoke4のリソースグループを参照（または作成）
resource spoke4Rg 'Microsoft.Resources/resourceGroups@2023-07-01' existing = {
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
  { name: '${development}-spoke4-pe-snet01',  prefix: '${networkPrefix}.0.0/24', pePolicies: 'Disabled', nsgType: 'none', delegations: [] }
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

// Storage Account (Private Endpoint接続対象の例)
module logst '../modules/logst.bicep' = {
  name: '${role}-logst'
  scope: spoke4Rg
  params: {
    storageAccountName: '${development}${role}logst01'
    location: location
    enableBlobService: true
    enableFileService: false
    enableTableService: false
  }
}

// Private Endpoint作成
module logst_privateEndpoint '../modules/private_endpoint.bicep' = {
  name: '${role}-logst-pe'
  scope: spoke4Rg
  params: {
    privateEndpointName: '${development}${role}logst01-pe01'
    location: location
    vnetId: vnet.outputs.vnetId
    subnetId: subnetsMod[0].outputs.subnetId
    targetResourceId: logst.outputs.logstId
    groupIds: [ 'blob' ]
    privateDnsZoneName: 'privatelink.blob.${environment().suffixes.storage}'  
  }
}
/*
// Key Vault用の追加パラメータ
param tenantId string = tenant().tenantId
param objectId string ='95dad140-2422-4cd5-a2e7-2143de1f53d3'
param allowedIPs array = [] // 必要に応じて許可するIPアドレス


// Key Vault作成
module keyVault '../modules/keyvault.bicep' = {
  name: '${role}-keyvault'
  scope: spoke4Rg
  params: {
    name: '${development}-${role}-kv03'
    location: location
    tenantId: tenantId
    objectId: objectId
    allowedIPs: allowedIPs
    logAnalyticsWorkspaceId: logAnalytics.outputs.logAnalyticsWorkspaceId
    storageAccountId: logst.outputs.logstId
  }
}

// Key Vault用プライベートエンドポイント作成
module keyVaultPrivateEndpoint '../modules/private_endpoint.bicep' = {
  name: '${role}-keyvault-pe'
  scope: spoke4Rg
  params: {
    privateEndpointName: '${development}-${role}-kv01-pe01'
    location: location
    vnetId: vnet.outputs.vnetId
    subnetId: subnetsMod[0].outputs.subnetId
    targetResourceId: keyVault.outputs.keyVaultId
    groupIds: ['vault']
    privateDnsZoneName: 'privatelink.vaultcore.azure.net'
  }
}
*/

// Azure Container Registry作成
module acr '../modules/acr.bicep' = {
  name: '${role}-acr'
  scope: spoke4Rg
  params: {
    name: '${development}${role}acr01'
    location: location
    sku: 'Premium'
    allowedIpRanges: []
    logAnalyticsWorkspaceId: logAnalytics.outputs.logAnalyticsWorkspaceId
    storageAccountId: logst.outputs.logstId
  }
}

// ACR用プライベートエンドポイント作成
module acrPrivateEndpoint '../modules/private_endpoint.bicep' = {
  name: '${role}-acr-pe'
  scope: spoke4Rg
  params: {
    privateEndpointName: '${development}${role}acr01-pe01'
    location: location
    vnetId: vnet.outputs.vnetId
    subnetId: subnetsMod[0].outputs.subnetId
    targetResourceId: acr.outputs.acrId
    groupIds: ['registry']
    privateDnsZoneName: 'privatelink.azurecr.io'
  }
}

module logAnalytics '../modules/loganalytics.bicep' = {
  name: '${role}-loganalytics'
  scope: spoke4Rg
  params: {
    name: '${development}-${role}-log01'
    location: location
  }
}

module appInsights '../modules/appinsights.bicep' = {
  name: '${role}-appi'
  scope: spoke4Rg
  params: {
    name: '${development}-${role}-appi01'
    location: location
    logAnalyticsid:logAnalytics.outputs.logAnalyticsWorkspaceId
    }
}

// Azure Monitor Private Link Scope (共有) + Private Endpoint
module ampls '../modules/ampls.bicep' = {
  name: '${role}-ampls'
  scope: spoke4Rg
  params: {
    privateLinkScopeName: '${development}-${role}-ampls01'
    privateEndpointLocation: location
    vnetId: vnet.outputs.vnetId
    subnetId: subnetsMod[0].outputs.subnetId
    logAnalyticsWorkspaceId: logAnalytics.outputs.logAnalyticsWorkspaceId
    appInsightsId: appInsights.outputs.applicationInsightsId
    privateEndpointName: '${development}-${role}-ampls01-pe01'
  }
}
