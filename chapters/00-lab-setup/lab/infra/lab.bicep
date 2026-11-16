// Chapter 0: the lab VM and its network, deployed into the lab resource group by main.bicep.
targetScope = 'resourceGroup'

param prefix string
param location string
param tags object
param learnerIp string
param sshPublicKey string
param adminUsername string
param vmSize string
param imagePublisher string
param imageOffer string
param imageSku string
param imageVersion string
param osDiskSizeGB int
param autoShutdownTime string
param autoShutdownTimeZone string
param shutdownNotificationEmail string

var vmName = '${prefix}-lab-vm'
var cloudInit = replace(loadTextContent('cloud-init.yaml'), '__ADMIN_USER__', adminUsername)

// Built-in role definition IDs, identical in every Azure tenant.
var contributorRoleId = 'b24988ac-6180-42a0-ab88-20f7382dd24c'
var acrPushRoleId = '8311e382-0749-4cb8-b61a-304f252e45ec'

resource nsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: '${vmName}-nsg'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'allow-ssh-from-learner'
        properties: {
          description: 'SSH from the learner public IP only. Every other inbound connection hits the default deny rule.'
          priority: 1000
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: '${learnerIp}/32'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: '${prefix}-lab-vnet'
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.20.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'lab'
        properties: {
          addressPrefix: '10.20.1.0/24'
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ]
  }
}

resource pip 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: '${vmName}-pip'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: '${vmName}-nic'
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: vnet.properties.subnets[0].id
          }
          publicIPAddress: {
            id: pip.id
            properties: {
              deleteOption: 'Delete'
            }
          }
        }
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: vmName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      customData: base64(cloudInit)
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: sshPublicKey
            }
          ]
        }
      }
    }
    storageProfile: {
      imageReference: {
        publisher: imagePublisher
        offer: imageOffer
        sku: imageSku
        version: imageVersion
      }
      osDisk: {
        name: '${vmName}-osdisk'
        createOption: 'FromImage'
        diskSizeGB: osDiskSizeGB
        deleteOption: 'Delete'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
          properties: {
            deleteOption: 'Delete'
          }
        }
      ]
    }
    securityProfile: {
      securityType: 'TrustedLaunch'
      uefiSettings: {
        secureBootEnabled: true
        vTpmEnabled: true
      }
    }
  }
}

// The portal only shows this schedule if the name is exactly shutdown-computevm-<VM name>.
resource autoShutdown 'Microsoft.DevTestLab/schedules@2018-09-15' = {
  name: 'shutdown-computevm-${vmName}'
  location: location
  tags: tags
  properties: {
    status: 'Enabled'
    taskType: 'ComputeVmShutdownTask'
    dailyRecurrence: {
      time: autoShutdownTime
    }
    timeZoneId: autoShutdownTimeZone
    targetResourceId: vm.id
    notificationSettings: empty(shutdownNotificationEmail)
      ? {
          status: 'Disabled'
        }
      : {
          status: 'Enabled'
          timeInMinutes: 30
          emailRecipient: shutdownNotificationEmail
          notificationLocale: 'en'
        }
  }
}

// untaggable: role assignments do not accept tags.
// Lets scripts on the lab VM create and delete chapter resources in this resource group only.
resource vmContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, vm.id, contributorRoleId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', contributorRoleId)
    principalId: vm.identity.principalId
    principalType: 'ServicePrincipal'
    description: 'Lab VM manages chapter resources in the lab resource group.'
  }
}

// untaggable: role assignments do not accept tags.
// Lets the lab VM push images to registries in this resource group (chapter 1).
resource vmAcrPush 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, vm.id, acrPushRoleId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', acrPushRoleId)
    principalId: vm.identity.principalId
    principalType: 'ServicePrincipal'
    description: 'Lab VM pushes images to course registries in the lab resource group.'
  }
}

output vmName string = vm.name
output publicIpAddress string = pip.properties.ipAddress
