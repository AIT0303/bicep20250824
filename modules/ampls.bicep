// Azure Monitor Private Link Scope + Private Endpoint モジュール
param privateLinkScopeName string
param location string = 'global'  // AMPLSは常にglobal
param logAnalyticsWorkspaceId string = ''  // オプション：既存のworkspace
param appInsightsId string = ''  // オプション：既存のapp insights

// Private Endpoint関連パラメータ
param privateEndpointName string
param privateEndpointLocation string  // PEの場所（リージョナル）
param subnetId string
param vnetId string

// Private Link Scope作成
resource privateLinkScope 'microsoft.insights/privateLinkScopes@2021-07-01-preview' = {
  name: privateLinkScopeName
  location: location
  properties: {
    accessModeSettings: {
      ingestionAccessMode: 'PrivateOnly'
      queryAccessMode: 'PrivateOnly'
    }
  }
}

// Log Analytics Workspaceをscopeに追加（IDが提供された場合）
resource logAnalyticsLink 'Microsoft.Insights/privateLinkScopes/scopedResources@2021-07-01-preview' = if (!empty(logAnalyticsWorkspaceId)) {
  name: 'loganalytics-link'
  parent: privateLinkScope
  properties: {
    linkedResourceId: logAnalyticsWorkspaceId
  }
}

// Application InsightsをScopeに追加（IDが提供された場合）
resource appInsightsLink 'Microsoft.Insights/privateLinkScopes/scopedResources@2021-07-01-preview' = if (!empty(appInsightsId)) {
  name: 'appinsights-link'
  parent: privateLinkScope
  properties: {
    linkedResourceId: appInsightsId
  }
}

// AMPLS用Private Endpoint
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-04-01' = {
  name: privateEndpointName
  location: privateEndpointLocation
  properties: {
    subnet: {
      id: subnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${privateEndpointName}-connection'
        properties: {
          privateLinkServiceId: privateLinkScope.id
          groupIds: ['azuremonitor']
          privateLinkServiceConnectionState: {
            status: 'Approved'
            actionsRequired: 'None'
          }
        }
      }
    ]
  }
  dependsOn: [
    logAnalyticsLink
    appInsightsLink
  ]
}

// 必要なPrivate DNS Zones
var dnsZones = [
  'privatelink.monitor.azure.com'
  'privatelink.oms.opinsights.azure.com'
  'privatelink.ods.opinsights.azure.com'
  'privatelink.applicationinsights.azure.com'
]

// Private DNS Zones作成
resource privateDnsZones 'Microsoft.Network/privateDnsZones@2020-06-01' = [for dnsZone in dnsZones: {
  name: dnsZone
  location: 'global'
}]

// Private DNS Zone Group（複数のDNSゾーンを含む）
resource privateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-04-01' = {
  parent: privateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [for (dnsZone, i) in dnsZones: {
      name: replace(dnsZone, '.', '-')
      properties: {
        privateDnsZoneId: privateDnsZones[i].id
      }
    }]
  }
}

// Virtual Network Links（各DNSゾーンをVNetにリンク）
resource virtualNetworkLinks 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = [for (dnsZone, i) in dnsZones: {
  parent: privateDnsZones[i]
  name: '${replace(dnsZone, '.', '-')}-${split(vnetId, '/')[8]}-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}]

// 出力
output privateLinkScopeId string = privateLinkScope.id
output privateLinkScopeName string = privateLinkScope.name
output privateEndpointId string = privateEndpoint.id
output privateDnsZoneIds array = [for i in range(0, length(dnsZones)): privateDnsZones[i].id]
