
targetScope = 'subscription'

// パラメータ定義
param development string = 'poc'
param role string = 'spoke3'
param location string = 'japaneast'
param rgName string = '${development}-${role}-rg'
param hub1ResourceGroup string = '${development}-hub1-rg'
param vnetName string = '${development}-hub1-vnet01'

// Hub1のリソースグループを参照
resource hub1Rg 'Microsoft.Resources/resourceGroups@2023-07-01' existing = {
  name: hub1ResourceGroup
}

// Spoke3のリソースグループを参照（または作成）
resource spoke3Rg 'Microsoft.Resources/resourceGroups@2023-07-01' existing = {
  name: rgName
}

// Hub1のVNetを参照
resource hub1Vnet 'Microsoft.Network/virtualNetworks@2023-11-01' existing = {
  name: vnetName
  scope: hub1Rg
}

// Hub1のPrivate Endpoint用サブネットを参照
resource peSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' existing = {
  name: '${development}-spoke3-pe-snet01'
  parent: hub1Vnet
}

// Hub1のPrivate Endpoint用サブネットを参照
resource vmSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' existing = {
  name: '${development}-spoke3-vm-snet01'
  parent: hub1Vnet
}

// HDInsightクラスター作成
module dataLakeStorage '../modules/data_Lake_Storage_Gen2.bicep' = {
  name: '${role}-hadoop-cluster'
  scope: spoke3Rg
  params: {
    clusterName: '${development}${role}hdi01'
    location: location
    clusterLoginUserName: 'admin'
    clusterLoginPassword: 'Headwaters1234&'
    sshUserName: 'sshuser' 
    sshPassword: 'Headwaters1234&'
    storageAccountName: '${development}${role}datast01'
    fileSystemName: '${development}${role}filest01'
    managedIdentityName: '${development}-${role}-datalake-id'
  }
}

// Private Endpoint作成
module privateEndpoint '../modules/private_endpoint.bicep' = {
  name: '${role}-storage-pe'
  scope: spoke3Rg
  params: {
    privateEndpointName: '${development}${role}datast01-pe01'
    location: location
    vnetId: hub1Vnet.id
    subnetId: peSubnet.id
    targetResourceId: dataLakeStorage.outputs.storageAccountId
    groupIds: [ 'blob' ]
    privateDnsZoneName: 'privatelink.blob.${environment().suffixes.storage}'  
  }
}

// VM 作成
module vm '../modules/vm.bicep' = {
  name: '${role}-vm'
  scope: spoke3Rg
  params: {
    vmName: '${development}-${role}-vm01'
    location: location
    subnetId: vmSubnet.id
    adminUsername: 'vmadmin'
    adminPassword: 'Headwaters1234&'
  }
  }

// 現在のユーザーのオブジェクトID（デプロイ時に指定が必要）
param currentUserObjectId string = ''

// Synapse Analytics ワークスペース作成
module synapseWorkspace '../modules/synapse_analytics.bicep' = {
  name: '${role}-synapse-workspace'
  scope: spoke3Rg
  params: {
    location: location
    storageAccountName: dataLakeStorage.outputs.storageAccountName
    storageAccountId: dataLakeStorage.outputs.storageAccountId
    fileSystemName: dataLakeStorage.outputs.fileSystemName
    workspaceName: '${development}-${role}-synapse-ws01'
    managedResourceGroupName: '${development}-${role}-managed-rg'
    sqlAdministratorLogin: 'sqladminuser'
    sqlAdministratorPassword: 'Headwaters1234&'
    
    currentUserObjectId: currentUserObjectId
  }
}
