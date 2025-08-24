param name string
param location string 
param infrastructureSubnetId string
param internalOnly bool = false
param logAnalyticsCustomerId string = ''
@secure()
param logAnalyticsSharedKey string = ''

param tags object = {}

resource env 'Microsoft.App/managedEnvironments@2023-05-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    vnetConfiguration: {
      infrastructureSubnetId: infrastructureSubnetId
      internal: internalOnly
    }

    // Log Analytics 連携は両方の値があるときだけ有効化
    ...((length(logAnalyticsCustomerId) > 0 && length(logAnalyticsSharedKey) > 0) ? {
      appLogsConfiguration: {
        destination: 'log-analytics'
        logAnalyticsConfiguration: {
          customerId: logAnalyticsCustomerId
          sharedKey: logAnalyticsSharedKey
        }
      }
    } : {})
  }
}

output environmentId string = env.id
output environmentName string = env.name
