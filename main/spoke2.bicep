targetScope = 'subscription'

// パラメータ定義
param development string = 'poc'
param role string = 'spoke2'
param location string = 'japaneast'
param rgName string = '${development}-${role}-rg'
param acrName string = '${development}spoke4acr01'
param acrRg string = '${development}-spoke4-rg'
param containerImage string
param logAnalyticsName string = '${development}spoke4logst01'


// 変数定義
var networkPrefix = '10.2'

// 既存のリソースグループを参照
resource spoke2Rg 'Microsoft.Resources/resourceGroups@2023-07-01' existing = {
  name: rgName
}

// VNet 作成
module vnet '../modules/vnet.bicep' = {
  name: '${role}-vnet'
  scope: resourceGroup(spoke2Rg.name)
  params: {
    vnetName: '${development}-${role}-vnet01'
    location: location
    addressSpace: '${networkPrefix}.0.0/16'
  }
}

// container apps用 NSG作成
module caNsg '../modules/nsg/ca_nsg.bicep' = {
  name: '${role}-ca-nsg'
  scope: resourceGroup(spoke2Rg.name)
  params: {
    nsgName: '${development}-${role}-ca-nsg01'
    location: location
  }
}

// ルートテーブル作成
module sqlRt '../modules/routeTable.bicep' = {
  name: '${role}-sql-rt'
  scope: resourceGroup(spoke2Rg.name)
  params: {
    routeTableName: '${development}-${role}-sql-rt'
    location: location
  }
}

//プライベートエンドポイント用 NSG作成
module sqlNsg '../modules/nsg/sql_nsg.bicep' = {
  name: '${role}-sql-nsg'
  scope: resourceGroup(spoke2Rg.name)
  params: {
    nsgName: '${development}-${role}-sql-nsg01'
    location: location
  }
}

var subnets = [
  { name: '${development}-spoke2-pe-snet01',  prefix: '${networkPrefix}.0.0/24', pePolicies: 'Disabled', nsgType: 'none', delegations: [] }
  { 
    name: '${development}-spoke2-sql-snet01'
    prefix: '${networkPrefix}.1.0/24'
    nsgType: 'sql'
    delegations: [
      {
        name: 'Microsoft.Sql.managedInstances'
        properties: {
          serviceName: 'Microsoft.Sql/managedInstances'
        }
      }
    ]
  }
  { name: '${development}-spoke2-ca-snet01',  prefix: '${networkPrefix}.2.0/23', nsgType: 'ca', delegations: [] }
]

// VNet モジュールが完了してから各サブネットを作成
@batchSize(1)
module subnetsMod '../modules/subnet.bicep' = [for (sn, i) in subnets: {
  name: 'subnet-${i}-${sn.name}'
  scope: resourceGroup(spoke2Rg.name)
  dependsOn: [ vnet ]
  params: {
    vnetName: '${development}-${role}-vnet01'
    subnetName: sn.name
    addressPrefix: sn.prefix
    networkSecurityGroupId: sn.nsgType == 'ca' ? caNsg.outputs.nsgId : sn.nsgType == 'sql' ? sqlNsg.outputs.nsgId : ''
    routeTableId: sn.nsgType == 'sql' ? sqlRt.outputs.routeTableId : ''
    serviceEndpoints: []
    privateLinkServiceNetworkPolicies: 'Enabled'
    delegations: sn.delegations
  }
}]

// 既存のリソースグループを参照
resource spoke4Rg 'Microsoft.Resources/resourceGroups@2023-07-01' existing = {
  name: rgName
}

// Spoke4のLog Analyticsワークスペースを参照
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: logAnalyticsName  // パラメータで受け取る必要があります
  scope: spoke4Rg
}


// 既存のPrivate DNS Zoneを参照（spoke4で作成されたもの）
resource existingBlobPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: 'privatelink.blob.${environment().suffixes.storage}'
  scope: resourceGroup('${development}-spoke4-rg')
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
    logAnalyticsWorkspaceId:logAnalytics.id
  }
}

// Private Endpoint作成
module privateEndpoint '../modules/private_endpoint.bicep' = {
  name: '${role}-storage-pe'
  scope: spoke2Rg
  params: {
    privateEndpointName: '${development}${role}datast01-pe01'
    location: location
    vnetId: vnet.outputs.vnetId
    subnetId: subnetsMod[0].outputs.subnetId
    targetResourceId: storageAccount.outputs.storageAccountId
    groupIds: [ 'blob' ]
    privateDnsZoneName: existingBlobPrivateDnsZone.id  
  }
}

module sqlMi '../modules/sql_managedInstance.bicep' = {
  name: '${role}-sql-mi'
  scope: spoke2Rg
  params: {
    managedInstanceName: '${development}-${role}-mi01'
    location: location
        subnetId: subnetsMod[1].outputs.subnetId
    administratorLogin: 'sqladmin'
    administratorLoginPassword: 'Headwaters202508' 

  }
}

// Container Apps のマネージド環境
module caEnv '../modules/container_apps_environment.bicep' = {
  name: '${role}-ca-env'
  scope: spoke2Rg
  params: {
    name: '${development}-${role}-cae01'
    location: location
    infrastructureSubnetId: subnetsMod[2].outputs.subnetId
  }
}

//  Container App 作成 
module webca01 '../modules/container_app.bicep' = {
  name: '${role}-container-app01'
  scope: spoke2Rg
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
  scope: spoke2Rg
  params: {
    containerAppName: '${development}-${role}-ca02'
    location: location
    environmentId: caEnv.outputs.environmentId
    containerImage: containerImage
    acrName: acrName
    acrResourceGroupName: acrRg
  }
}

// ACR ロール割り当て
module acrRole01 '../modules/acr_role_assignment.bicep' = {
  name: '${role}-acr-role01'
  scope: resourceGroup(acrRg)
  params: {
    acrName: acrName
    principalId: webca01.outputs.systemAssignedIdentityPrincipalId
    acrResourceGroupName: acrRg
  }
}

// ACR ロール割り当て
module acrRole02 '../modules/acr_role_assignment.bicep' = {
  name: '${role}-acr-role02'
  scope: resourceGroup(acrRg)
  params: {
    acrName: acrName
    principalId: webca02.outputs.systemAssignedIdentityPrincipalId
    acrResourceGroupName: acrRg
  }
}
