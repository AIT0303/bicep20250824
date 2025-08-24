param clusterName string
param location string
param clusterLoginUserName string = 'admin'
@secure()
param clusterLoginPassword string
param sshUserName string = 'sshuser'
@secure()
param sshPassword string
param storageAccountName string
param fileSystemName string = ''
param managedIdentityName string

// Data Lake Storage Gen2アカウント
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    isHnsEnabled: true // 階層型名前空間を有効化（Data Lake Gen2に必要）
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    networkAcls: {
      defaultAction: 'Allow'
    }
  }
}

// Blob Serviceの設定
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    deleteRetentionPolicy: {
      enabled: true
      days: 7
    }
  }
}

// ファイルシステム（コンテナー）
resource fileSystem 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: fileSystemName
  properties: {
    publicAccess: 'None'
  }
}

// ユーザー割り当て済みマネージドID
resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: managedIdentityName
  location: location
}

// Storage Blob Data Owner ロール定義（HDInsightに必要）
var storageBlobDataOwnerRoleId = 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
// Storage Account Contributor（追加の権限）
var storageAccountContributorRoleId = '17d1049b-9a84-46fb-8f53-869881c3d3ab'

// マネージドIDにStorage Blob Data Owner権限を付与
resource roleAssignmentOwner 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storageAccount
  name: guid(storageAccount.id, userAssignedIdentity.id, storageBlobDataOwnerRoleId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataOwnerRoleId)
    principalId: userAssignedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// マネージドIDにStorage Account Contributor権限も付与（HDInsight用）
resource roleAssignmentContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storageAccount
  name: guid(storageAccount.id, userAssignedIdentity.id, storageAccountContributorRoleId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageAccountContributorRoleId)
    principalId: userAssignedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// HDInsight Hadoop クラスター
resource hdInsightCluster 'Microsoft.HDInsight/clusters@2023-04-15-preview' = {
  name: clusterName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentity.id}': {}
    }
  }
  properties: {
    clusterVersion: '4.0'
    osType: 'Linux'
    tier: 'Standard'
    clusterDefinition: {
      kind: 'Hadoop'
      componentVersion: {
        Hadoop: '3.1'
      }
      configurations: {
        gateway: {
          'restAuthCredential.isEnabled': true
          'restAuthCredential.username': clusterLoginUserName
          'restAuthCredential.password': clusterLoginPassword
        }
      }
    }
    storageProfile: {
      storageaccounts: [
        {
          name: '${storageAccountName}.dfs.${environment().suffixes.storage}'
          isDefault: true
          fileSystem: fileSystemName
          resourceId: storageAccount.id
          msiResourceId: userAssignedIdentity.id
        }
      ]
    }
    computeProfile: {
      roles: [
        // ヘッドノード
        {
          name: 'headnode'
          targetInstanceCount: 2
          hardwareProfile: {
            vmSize: 'Standard_A4_v2' // 4コア, 8GB RAM
          }
          osProfile: {
            linuxOperatingSystemProfile: {
              username: sshUserName
              password: sshPassword
            }
          }
          scriptActions: []
        }
        // ワーカーノード
        {
          name: 'workernode'
          targetInstanceCount: 1
          hardwareProfile: {
            vmSize: 'Standard_A2m_v2' // 2コア, 16GB RAM
          }
          osProfile: {
            linuxOperatingSystemProfile: {
              username: sshUserName
              password: sshPassword
            }
          }
          scriptActions: []
        }
        // Zookeeperノード
        {
          name: 'zookeepernode'
          targetInstanceCount: 3
          hardwareProfile: {
            vmSize: 'Standard_A2_v2' // 2コア, 4GB RAM
          }
          osProfile: {
            linuxOperatingSystemProfile: {
              username: sshUserName
              password: sshPassword
            }
          }
          scriptActions: []
        }
      ]
    }
    minSupportedTlsVersion: '1.2'
//    securityProfile: {
//      directoryType: 'ActiveDirectory'
//      domain: 'example.com'
//    }
//    networkProperties: {
//      resourceProviderConnection: 'Inbound'
//      privateLink: 'Disabled'
//    }
  }
}

// 出力
output clusterName string = hdInsightCluster.name
output clusterFqdn string = hdInsightCluster.properties.connectivityEndpoints[0].location
output sshEndpoint string = '${clusterName}-ssh.azurehdinsight.net'
output storageAccountName string = storageAccount.name
output storageAccountId string = storageAccount.id
output fileSystemName string = fileSystemName
output managedIdentityName string = userAssignedIdentity.name

