param location string
param name string
param tags object = {}

// Log Analytics Workspace
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    publicNetworkAccessForIngestion: 'Disabled'
    publicNetworkAccessForQuery: 'Disabled'
    features: {
      enableDataExport: true
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
}

// Solutions（必要に応じて追加）
resource securityCenterFreeSolution 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = {
  name: 'SecurityCenterFree(${logAnalyticsWorkspace.name})'
  location: location
  tags: tags
  plan: {
    name: 'SecurityCenterFree(${logAnalyticsWorkspace.name})'
    promotionCode: ''
    product: 'OMSGallery/SecurityCenterFree'
    publisher: 'Microsoft'
  }
  properties: {
    workspaceResourceId: logAnalyticsWorkspace.id
  }
}

// アウトプット
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id
output logAnalyticsWorkspaceName string = logAnalyticsWorkspace.name
output logAnalyticsCustomerId string = logAnalyticsWorkspace.properties.customerId
output logAnalyticsResourceId string = logAnalyticsWorkspace.id
