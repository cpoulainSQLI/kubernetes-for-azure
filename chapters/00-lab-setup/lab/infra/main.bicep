// Chapter 0: lab environment.
// Creates the lab resource group, a monthly budget for the subscription and the lab VM.
// Deploy it with chapters/00-lab-setup/lab/setup.sh, which fills in every parameter from .env.
targetScope = 'subscription'

@description('Short name used in every resource name.')
@minLength(3)
@maxLength(12)
param prefix string

@description('Azure region for the lab.')
param location string

@description('Chapter that owns these resources. Used in the chapter tag.')
param chapter string = '00'

@description('Monthly budget amount in the billing currency of the subscription.')
@minValue(1)
param budgetAmount int

@description('First day of the month when the budget starts, in yyyy-MM-dd format.')
param budgetStartDate string = '${utcNow('yyyy-MM')}-01'

@description('Create the budget. The setup script sets this to false when the budget already exists.')
param deployBudget bool = true

@description('E-mail addresses that receive budget alerts.')
param budgetContactEmails array

@description('Public IPv4 address allowed to reach the lab VM over SSH, without /32.')
param learnerIp string

@description('SSH public key of the admin user. Never a private key.')
param sshPublicKey string

@description('Admin user name on the lab VM.')
param adminUsername string = 'azureuser'

@description('Size of the lab VM.')
param vmSize string = 'Standard_D2as_v5'

@description('Marketplace image of the lab VM.')
param imagePublisher string = 'Canonical'
param imageOffer string = 'ubuntu-26_04-lts'
param imageSku string = 'server'
param imageVersion string = 'latest'

@description('Size of the OS disk in GiB.')
@allowed([
  32
  64
  128
])
param osDiskSizeGB int = 64

@description('Daily shutdown time of the lab VM, in hhmm format.')
param autoShutdownTime string = '1900'

@description('Windows time zone ID for the shutdown time, for example UTC or W. Europe Standard Time.')
param autoShutdownTimeZone string = 'UTC'

@description('E-mail address warned 30 minutes before the daily shutdown. Empty turns the warning off.')
param shutdownNotificationEmail string = ''

var tags = {
  course: 'aro-k8s'
  chapter: chapter
}

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: '${prefix}-lab-rg'
  location: location
  tags: tags
}

// untaggable: Cost Management budgets do not accept tags. The name carries the prefix instead.
resource budget 'Microsoft.Consumption/budgets@2023-05-01' = if (deployBudget) {
  name: '${prefix}-monthly-budget'
  properties: {
    category: 'Cost'
    amount: budgetAmount
    timeGrain: 'Monthly'
    timePeriod: {
      startDate: budgetStartDate
    }
    notifications: {
      actual50: {
        enabled: true
        operator: 'GreaterThanOrEqualTo'
        threshold: 50
        thresholdType: 'Actual'
        contactEmails: budgetContactEmails
      }
      actual80: {
        enabled: true
        operator: 'GreaterThanOrEqualTo'
        threshold: 80
        thresholdType: 'Actual'
        contactEmails: budgetContactEmails
      }
      actual100: {
        enabled: true
        operator: 'GreaterThanOrEqualTo'
        threshold: 100
        thresholdType: 'Actual'
        contactEmails: budgetContactEmails
      }
      forecast100: {
        enabled: true
        operator: 'GreaterThanOrEqualTo'
        threshold: 100
        thresholdType: 'Forecasted'
        contactEmails: budgetContactEmails
      }
    }
  }
}

module lab 'lab.bicep' = {
  name: '${prefix}-lab-vm'
  scope: rg
  params: {
    prefix: prefix
    location: location
    tags: tags
    learnerIp: learnerIp
    sshPublicKey: sshPublicKey
    adminUsername: adminUsername
    vmSize: vmSize
    imagePublisher: imagePublisher
    imageOffer: imageOffer
    imageSku: imageSku
    imageVersion: imageVersion
    osDiskSizeGB: osDiskSizeGB
    autoShutdownTime: autoShutdownTime
    autoShutdownTimeZone: autoShutdownTimeZone
    shutdownNotificationEmail: shutdownNotificationEmail
  }
}

output resourceGroupName string = rg.name
output vmName string = lab.outputs.vmName
output publicIpAddress string = lab.outputs.publicIpAddress
