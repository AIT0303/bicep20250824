targetScope = 'subscription'
param rgName string
param location string

resource RG 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: rgName
  location: location
}

output rgName string = RG.name
