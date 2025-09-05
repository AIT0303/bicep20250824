targetScope = 'subscription'

// パラメータ定義
param development string = 'poc'
param role string = 'spoke3'
param location string = 'japaneast'
param rgName string = '${development}-${role}-rg'

// Spoke3のリソースグループを参照（または作成）
resource spoke3Rg 'Microsoft.Resources/resourceGroups@2023-07-01' existing = {
  name: rgName
}

// 変数定義
var networkPrefix = '10.3'

// VNet 作成
module vnet '../modules/vnet.bicep' = {
  name: '${role}-vnet'
  scope: resourceGroup(spoke3Rg.name)
  params: {
    vnetName: '${development}-${role}-vnet01'
    location: location
    addressSpace: '${networkPrefix}.0.0/16'
  }
}

var subnets = [
  { name: '${development}-spoke3-pe-snet01',  prefix: '${networkPrefix}.0.0/24', pePolicies: 'Disabled', nsgType: 'none', delegations: [] }
]

// VNet モジュールが完了してから各サブネットを作成
@batchSize(1)
module subnetsMod '../modules/subnet.bicep' = [for (sn, i) in subnets: {
  name: 'subnet-${i}-${sn.name}'
  scope: resourceGroup(spoke3Rg.name)
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

// 既存のPrivate DNS Zoneを参照（spoke4で作成されたもの）
resource existingBlobPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: 'privatelink.blob.${environment().suffixes.storage}'
  scope: resourceGroup('${development}-spoke4-rg')
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
module datast_privateEndpoint '../modules/private_endpoint.bicep' = {
  name: '${role}-storage-pe'
  scope: spoke3Rg
  params: {
    privateEndpointName: '${development}${role}datast01-pe01'
    location: location
    vnetId: vnet.outputs.vnetId
    subnetId: subnetsMod[0].outputs.subnetId
    targetResourceId: dataLakeStorage.outputs.storageAccountId
    groupIds: [ 'blob' ]
    privateDnsZoneName: existingBlobPrivateDnsZone.id
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
