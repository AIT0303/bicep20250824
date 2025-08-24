// modules/sql_managedInstance.bicep

param managedInstanceName string
param location string
param subnetId string
param administratorLogin string = 'sqladmin'
@secure()
param administratorLoginPassword string
param tags object = {}

// SQL Managed Instance（スペックはモジュール内で固定）
resource managedInstance 'Microsoft.Sql/managedInstances@2023-08-01-preview' = {
  name: managedInstanceName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  
  sku: {
    name: 'GP_Gen5'
    tier: 'GeneralPurpose'
    family: 'Gen5'
    capacity: 8
  }

  properties: {
    // 認証（SQL 認証）
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorLoginPassword

    // コンピュート/ストレージ（固定）
    vCores: 8
    storageSizeInGB: 256
    licenseType: 'LicenseIncluded'                    // 従量課金制
    requestedBackupStorageRedundancy: 'Geo'           // Geo 冗長バックアップ
    zoneRedundant: false                              // ゾーン冗長 無効

    // ネットワーク
    subnetId: subnetId
    publicDataEndpointEnabled: false                  // パブリック エンドポイント(データ) 無効
    proxyOverride: 'Proxy'                            // 接続方式: Proxy

    // セキュリティ / 追加設定
    minimalTlsVersion: '1.2'                          // TLS 1.2
    collation: 'SQL_Latin1_General_CP1_CI_AS'         // 照合順序
    timezoneId: 'Tokyo Standard Time'                 // タイムゾーン
  }
  tags: tags
}

output managedInstanceId string = managedInstance.id
output managedInstanceName string = managedInstance.name
output location string = location
