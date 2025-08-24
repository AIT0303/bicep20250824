
targetScope = 'subscription'

// パラメータ定義
param development string = 'poc'
param role string = 'spoke1'
param location string = 'japaneast'
param rgName string = '${development}-${role}-rg'
param hub1ResourceGroup string = '${development}-hub1-rg'
param vnetName string = '${development}-hub1-vnet01'
param acrName string = '${development}spoke4acr01'
param acrRg string = '${development}-spoke4-rg'

// Hub1のリソースグループを参照
resource hub1Rg 'Microsoft.Resources/resourceGroups@2023-07-01' existing = {
  name: hub1ResourceGroup
}

// Spoke1のリソースグループを参照（または作成）
resource spoke1Rg 'Microsoft.Resources/resourceGroups@2023-07-01' existing = {
  name: rgName
}

// Hub1のVNetを参照
resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' existing = {
  name: vnetName
  scope: hub1Rg
}

// Hub1のPrivate Endpoint用サブネットを参照
resource caSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' existing = {
  name: '${development}-spoke1-ca-snet01'
  parent: vnet
}

// Spoke4のリソースグループを参照
resource spoke4Rg 'Microsoft.Resources/resourceGroups@2023-07-01' existing = {
  name: acrRg
}

// Spoke4のACRを参照
resource acr 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' existing = {
  name: acrName
  scope: spoke4Rg
}


// Container Apps のマネージド環境
module caEnv '../modules/container_apps_environment.bicep' = {
  name: '${role}-ca-env'
  scope: spoke1Rg
  params: {
    name: '${development}-${role}-ca-env01'
    location: location
    infrastructureSubnetId: caSubnet.id
  }
}

// ===== Container App 作成 =====
module webca01 '../modules/container_app.bicep' = {
  name: '${role}-container-app01'
  scope: spoke1Rg
  params: {
    containerAppName: '${development}-${role}-ca01'
    location: location
    environmentId: caEnv.outputs.environmentId
    containerImage: 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
    acrName: acrName
    acrUsername: acr.listCredentials().username
    acrPassword: acr.listCredentials().passwords[0].value
  }
}

// ===== Container App 作成 =====
module webca02 '../modules/container_app.bicep' = {
  name: '${role}-container-app02'
  scope: spoke1Rg
  params: {
    containerAppName: '${development}-${role}-ca02'
    location: location
    environmentId: caEnv.outputs.environmentId
    containerImage: 'mcr.microsoft.com/azuredocs/aci-helloworld:latest'
    acrName: acrName
    acrUsername: acr.listCredentials().username
    acrPassword: acr.listCredentials().passwords[0].value
  }
}

