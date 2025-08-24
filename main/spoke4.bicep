
targetScope = 'subscription'

// パラメータ定義
param development string = 'poc'
param role string = 'spoke4'
param location string = 'japaneast'
param rgName string = '${development}-${role}-rg'
param hub1ResourceGroup string = '${development}-hub1-rg'
param vnetName string = '${development}-hub1-vnet01'

// Hub1のリソースグループを参照
resource hub1Rg 'Microsoft.Resources/resourceGroups@2023-07-01' existing = {
  name: hub1ResourceGroup
}

// Spoke4のリソースグループを参照（または作成）
resource spoke4Rg 'Microsoft.Resources/resourceGroups@2023-07-01' existing = {
  name: rgName
}

// Hub1のVNetを参照
resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' existing = {
  name: vnetName
  scope: hub1Rg
}

// Hub1のPrivate Endpoint用サブネットを参照
resource peSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' existing = {
  name: '${development}-spoke4-pe-snet01'
  parent: vnet
}


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
module privateEndpoint '../modules/private_endpoint.bicep' = {
  name: '${role}-logst-pe'
  scope: spoke4Rg
  params: {
    privateEndpointName: '${development}${role}logst01-pe01'
    location: location
    vnetId: vnet.id
    subnetId: peSubnet.id
    targetResourceId: logst.outputs.logstId
    groupIds: [ 'blob' ]
    privateDnsZoneName: 'privatelink.blob.${environment().suffixes.storage}'  
  }
}

// Key Vault用の追加パラメータ
param tenantId string = tenant().tenantId
param objectId string ='95dad140-2422-4cd5-a2e7-2143de1f53d3'
param allowedIPs array = [] // 必要に応じて許可するIPアドレス


// Key Vault作成
module keyVault '../modules/keyvault.bicep' = {
  name: '${role}-keyvault'
  scope: spoke4Rg
  params: {
    name: '${development}-${role}-kv02'
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
    vnetId: vnet.id
    subnetId: peSubnet.id
    targetResourceId: keyVault.outputs.keyVaultId
    groupIds: ['vault']
    privateDnsZoneName: 'privatelink.vaultcore.azure.net'
  }
}


// Azure Container Registry作成
module acr '../modules/acr.bicep' = {
  name: '${role}-acr'
  scope: spoke4Rg
  params: {
    name: '${development}${role}acr01'
    location: location
    sku: 'Premium'
    allowedIpRanges: []
  }
}

// ACR用プライベートエンドポイント作成
module acrPrivateEndpoint '../modules/private_endpoint.bicep' = {
  name: '${role}-acr-pe'
  scope: spoke4Rg
  params: {
    privateEndpointName: '${development}${role}acr01-pe01'
    location: location
    vnetId: vnet.id
    subnetId: peSubnet.id
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
    logAnalyticsName:logAnalytics.outputs.logAnalyticsWorkspaceName
    }
}

// Azure Monitor Private Link Scope (共有) + Private Endpoint
module ampls '../modules/ampls.bicep' = {
  name: '${role}-ampls'
  scope: spoke4Rg
  params: {
    privateLinkScopeName: '${development}-${role}-ampls01'
    privateEndpointLocation: location
    vnetId: vnet.id
    subnetId: peSubnet.id
    logAnalyticsWorkspaceId: logAnalytics.outputs.logAnalyticsWorkspaceId
    appInsightsId: appInsights.outputs.applicationInsightsId
    privateEndpointName: '${development}-${role}-ampls01-pe01'
  }
}
