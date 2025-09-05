param location string
param fileSystemName string
param workspaceName string
param managedResourceGroupName string
param storageAccountId string
param storageAccountName string
@secure()
param sqlAdministratorLogin string
@secure()
param sqlAdministratorPassword string
param publicNetworkAccess string = 'Disabled'
param managedVirtualNetwork string = 'default'
param isDoubleEncryptionEnabled bool = false
param preventDataExfiltration bool = false

// 既存のData Lake Storage Gen2アカウントを参照
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: storageAccountName
}

// accountUrlを動的に構築
var accountUrl = 'https://${storageAccountName}.dfs.${environment().suffixes.storage}'

// Synapse Analytics ワークスペース
resource synapseWorkspace 'Microsoft.Synapse/workspaces@2021-06-01' = {
  name: workspaceName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    // Data Lake Storage Gen2 設定
    defaultDataLakeStorage: {
      accountUrl: accountUrl
      filesystem: fileSystemName
      createManagedPrivateEndpoint: true
      resourceId: storageAccountId
    }
    
    // SQL 管理者設定
    sqlAdministratorLogin: sqlAdministratorLogin
    sqlAdministratorLoginPassword: sqlAdministratorPassword
    
    // ネットワーク設定
    publicNetworkAccess: publicNetworkAccess
    managedVirtualNetwork: managedVirtualNetwork
    managedVirtualNetworkSettings: {
      preventDataExfiltration: preventDataExfiltration
      linkedAccessCheckOnTargetResource: false
      allowedAadTenantIdsForLinking: []
    }
    
    // マネージドリソースグループ
    managedResourceGroupName: managedResourceGroupName
    // 暗号化設定
    encryption: {
      doubleEncryptionEnabled: isDoubleEncryptionEnabled
    }
    // 認証設定（ローカル認証とMicrosoft Entra ID認証の両方を使用）
    azureADOnlyAuthentication: false
  }
}

// Storage Blob Data Contributor ロールの定義ID
var storageBlobDataContributorRoleId = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'

resource workspaceRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, synapseWorkspace.id, storageBlobDataContributorRoleId)
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataContributorRoleId)
    principalId: synapseWorkspace.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// 現在のユーザーに Storage Blob Data Contributor ロールを割り当て
param currentUserObjectId string = ''
resource currentUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(currentUserObjectId)) {
  name: guid(storageAccount.id, currentUserObjectId, storageBlobDataContributorRoleId)
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataContributorRoleId)
    principalId: currentUserObjectId
    principalType: 'User'
  }
}

// マネージドプライベートエンドポイント
resource managedPrivateEndpoint 'Microsoft.Synapse/workspaces/managedPrivateEndpoints@2021-06-01' = {
  parent: synapseWorkspace
  name: '${workspaceName}-datalake-pe'
  properties: {
    privateLinkResourceId: storageAccountId
    groupId: 'dfs'
    requestMessage: 'Created by Synapse workspace'
  }
}

// 出力
output workspaceName string = synapseWorkspace.name
output workspaceId string = synapseWorkspace.id
output workspaceUrl string = 'https://${synapseWorkspace.name}.dev.azuresynapse.net'
output managedIdentityPrincipalId string = synapseWorkspace.identity.principalId
