targetScope = 'subscription'

// パラメータ定義
param development string = 'poc'
param location string = 'japaneast'

// 変数定義 - 作成するリソースグループのロール一覧（作成しないものはコメントアウトする）
var roles = [
  'hub1'
  'spoke1'
  'spoke2'
  'spoke3'
  'spoke4'
  //'spoke5' 追加するリソースのロールを記載
]

// リソースグループを複数作成
resource resourceGroups 'Microsoft.Resources/resourceGroups@2023-07-01' = [for role in roles: {
  name: '${development}-${role}-rg'
  location: location

}]

// 出力値
output resourceGroupNames array = [for (role, i) in roles: resourceGroups[i].name]
output resourceGroupIds array = [for (role, i) in roles: resourceGroups[i].id]
output hub1RgName string = resourceGroups[0].name
output spoke1RgName string = resourceGroups[1].name
output spoke2RgName string = resourceGroups[2].name
output spoke3RgName string = resourceGroups[3].name
output spoke4RgName string = resourceGroups[4].name
