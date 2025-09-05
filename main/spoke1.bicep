targetScope = 'subscription'

// パラメータ定義
param development string = 'poc'
param role string = 'spoke1'
param location string = 'japaneast'
param rgName string = '${development}-${role}-rg'
param acrName string = '${development}spoke4acr01'
param acrRg string = '${development}-spoke4-rg'
param containerImage string


// 変数定義
var networkPrefix = '10.1'

// 既存のリソースグループを参照
resource spoke1Rg 'Microsoft.Resources/resourceGroups@2023-07-01' existing = {
  name: rgName
}

// VNet 作成
module vnet '../modules/vnet.bicep' = {
  name: '${role}-vnet'
  scope: resourceGroup(spoke1Rg.name)
  params: {
    vnetName: '${development}-${role}-vnet01'
    location: location
    addressSpace: '${networkPrefix}.0.0/16'
  }
}

// container apps用 NSG作成
module caNsg '../modules/nsg/ca_nsg.bicep' = {
  name: '${role}-ca-nsg'
  scope: resourceGroup(spoke1Rg.name)
  params: {
    nsgName: '${development}-${role}-ca-nsg01'
    location: location
  }
}

var subnets = [
  { name: '${development}-spoke1-ca-snet01',  prefix: '${networkPrefix}.0.0/23', nsgType: 'ca', delegations: [] }
]

// VNet モジュールが完了してから各サブネットを作成
@batchSize(1)
module subnetsMod '../modules/subnet.bicep' = [for (sn, i) in subnets: {
  name: 'subnet-${i}-${sn.name}'
  scope: resourceGroup(spoke1Rg.name)
  dependsOn: [ vnet ]
  params: {
    vnetName: '${development}-${role}-vnet01'
    subnetName: sn.name
    addressPrefix: sn.prefix
    networkSecurityGroupId: sn.nsgType == 'ca' ? caNsg.outputs.nsgId : ''
    serviceEndpoints: []
    privateLinkServiceNetworkPolicies: 'Enabled'
    delegations: sn.delegations
  }
}]

// Container Apps のマネージド環境
module caEnv '../modules/container_apps_environment.bicep' = {
  name: '${role}-ca-env'
  scope: spoke1Rg
  params: {
    name: '${development}-${role}-cae01'
    location: location
    infrastructureSubnetId: subnetsMod[0].outputs.subnetId
  }
}

//  Container App 作成 
module webca01 '../modules/container_app.bicep' = {
  name: '${role}-container-app01'
  scope: spoke1Rg
  params: {
    containerAppName: '${development}-${role}-ca01'
    location: location
    environmentId: caEnv.outputs.environmentId
    containerImage: containerImage
    acrName: acrName
    acrResourceGroupName: acrRg
  }
}

//  Container App 作成 
module webca02 '../modules/container_app.bicep' = {
  name: '${role}-container-app02'
  scope: spoke1Rg
  params: {
    containerAppName: '${development}-${role}-ca02'
    location: location
    environmentId: caEnv.outputs.environmentId
    containerImage: containerImage
    acrName: acrName
    acrResourceGroupName: acrRg
  }
}

// ACR ロール割り当て（Container App 01用）
module acrRole01 '../modules/acr_role_assignment.bicep' = {
  name: '${role}-acr-role01'
  scope: resourceGroup(acrRg)
  dependsOn: [webca01]
  params: {
    acrName: acrName
    principalId: webca01.outputs.systemAssignedIdentityPrincipalId
    acrResourceGroupName: acrRg
  }
}

// ACR ロール割り当て（Container App 02用）
module acrRole02 '../modules/acr_role_assignment.bicep' = {
  name: '${role}-acr-role02'
  scope: resourceGroup(acrRg)
  dependsOn: [webca02]
  params: {
    acrName: acrName
    principalId: webca02.outputs.systemAssignedIdentityPrincipalId
    acrResourceGroupName: acrRg
  }
}

