param routeTableName string
param location string 
param tags object = {}

resource routeTable 'Microsoft.Network/routeTables@2023-04-01' = {
  name: routeTableName
  location: location
  tags: tags
  properties: {
    // エントリは空でOK（MIのService-aided設定が必要なルートを自動投入）
    // disableBgpRoutePropagation: false // 既定のままでOK
  }
}

output routeTableId string = routeTable.id
output routeTableName string = routeTable.name
