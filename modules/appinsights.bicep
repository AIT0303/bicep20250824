param location string
param name string
param logAnalyticsid string
param tags object = {}

// Application Insights
resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: name
  location: location
  kind: 'web'
  tags: tags
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsid
    publicNetworkAccessForIngestion: 'Disabled'
    publicNetworkAccessForQuery: 'Disabled'
    SamplingPercentage: 100
    DisableIpMasking: false
    Flow_Type: 'Bluefield'
    Request_Source: 'rest'
  }
}

// アウトプット
output applicationInsightsId string = applicationInsights.id
output applicationInsightsName string = applicationInsights.name
output instrumentationKey string = applicationInsights.properties.InstrumentationKey
output connectionString string = applicationInsights.properties.ConnectionString
output appId string = applicationInsights.properties.AppId
output applicationInsightsResourceId string = applicationInsights.id
