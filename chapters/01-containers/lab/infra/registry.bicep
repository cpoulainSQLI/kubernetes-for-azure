// Chapter 1: a Basic container registry in the lab resource group.
// Deployed from the lab VM by chapters/01-containers/lab/setup.sh and deleted by teardown.sh.
targetScope = 'resourceGroup'

@description('Short name used in resource names: lowercase letters and digits only.')
@minLength(3)
@maxLength(12)
param prefix string

@description('Azure region of the registry.')
param location string = resourceGroup().location

@description('Chapter that owns this resource. Used in the chapter tag.')
param chapter string = '01'

var tags = {
  course: 'aro-k8s'
  chapter: chapter
}

// Registry names are global, so a hash of the resource group ID keeps them unique.
resource registry 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: '${prefix}acr${uniqueString(resourceGroup().id)}'
  location: location
  tags: tags
  sku: {
    name: 'Basic'
  }
  properties: {
    // Sign-in goes through Microsoft Entra ID (az acr login), never through a shared admin password.
    adminUserEnabled: false
    publicNetworkAccess: 'Enabled'
  }
}

output name string = registry.name
output loginServer string = registry.properties.loginServer
