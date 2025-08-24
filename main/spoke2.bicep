
targetScope = 'subscription'

// パラメータ定義
param development string = 'poc'
param role string = 'spoke2'
param location string = 'japaneast'
param rgName string = '${development}-${role}-rg'
param hub1ResourceGroup string = '${development}-hub1-rg'
param vnetName string = '${development}-hub1-vnet01'
param acrName string = '${development}spoke4acr01'
param acrRg string = '${development}-spoke4-rg'
param logstName string = '${development}spoke4logst01'

// Hub1のリソースグループを参照
resource hub1Rg 'Microsoft.Resources/resourceGroups@2023-07-01' existing = {
  name: hub1ResourceGroup
}

// Spoke2のリソースグループを参照（または作成）
resource spoke2Rg 'Microsoft.Resources/resourceGroups@2023-07-01' existing = {
  name: rgName
}

// Hub1のVNetを参照
resource hub1Vnet 'Microsoft.Network/virtualNetworks@2023-11-01' existing = {
  name: vnetName
  scope: hub1Rg
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

// Spoke4のストレージアカウントを参照
resource logst 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: logstName
  scope: spoke4Rg
}

// Hub1のPrivate Endpoint用サブネットを参照
resource peSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' existing = {
  name: '${development}-${role}-pe-snet01'
  parent: hub1Vnet
}

// Hub1のPrivate Endpoint用サブネットを参照
resource caSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' existing = {
  name: '${development}-${role}-ca-snet01'
  parent: hub1Vnet
}

// Hub1のPrivate Endpoint用サブネットを参照
resource sqlSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' existing = {
  name: '${development}-${role}-sql-snet01'
  parent: hub1Vnet
}

// Storage Account (Private Endpoint接続対象の例)
module storageAccount '../modules/storage_account.bicep' = {
  name: '${role}-storage'
  scope: spoke2Rg
  params: {
    storageAccountName: '${development}${role}datast01'
    location: location
    enableBlobService: true
    enableFileService: false
    enableTableService: false
    logAnalyticsWorkspaceId:logst.id
  }
}

// Private Endpoint作成
module privateEndpoint '../modules/private_endpoint.bicep' = {
  name: '${role}-storage-pe'
  scope: spoke2Rg
  params: {
    privateEndpointName: '${development}${role}datast01-pe01'
    location: location
    vnetId: hub1Vnet.id
    subnetId: peSubnet.id
    targetResourceId: storageAccount.outputs.storageAccountId
    groupIds: [ 'blob' ]
    privateDnsZoneName: 'privatelink.blob.${environment().suffixes.storage}'  
  }
}

module sqlMi '../modules/sql_managedInstance.bicep' = {
  name: '${role}-sql-mi'
  scope: spoke2Rg
  params: {
    managedInstanceName: '${development}-${role}-mi01'
    location: location
    administratorLogin: 'sqladmin'
    administratorLoginPassword: 'Headwaters202508'  // セキュアパラメータにするのが推奨
    subnetId: sqlSubnet.id
  }
}

// Container Apps のマネージド環境
module caEnv '../modules/container_apps_environment.bicep' = {
  name: '${role}-ca-env'
  scope: spoke2Rg
  params: {
    name: '${development}-${role}-ca-env01'
    location: location
    infrastructureSubnetId: caSubnet.id
  }
}

// ===== Container App 作成 =====
module webca01 '../modules/container_app.bicep' = {
  name: '${role}-container-app01'
  scope: spoke2Rg
  params: {
    containerAppName: '${development}-${role}-ca01'
    location: location
    environmentId: caEnv.outputs.environmentId
    containerImage: '${acrName}.azurecr.io/myapp:v1.0'
    acrName: acrName
    acrUsername:acr.listCredentials().username
    acrPassword:acr.listCredentials().passwords[0].value
  }
}

// ===== Container App 作成 =====
module webca02 '../modules/container_app.bicep' = {
  name: '${role}-container-app02'
  scope: spoke2Rg
  params: {
    containerAppName: '${development}-${role}-ca02'
    location: location
    environmentId: caEnv.outputs.environmentId
    containerImage: '${acrName}.azurecr.io/myapp:v1.0'
    acrName: acrName
    acrUsername:acr.listCredentials().username
    acrPassword:acr.listCredentials().passwords[0].value
  }
}
