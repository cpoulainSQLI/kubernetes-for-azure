<#
.SYNOPSIS
Chapter 0 setup. Creates or updates the lab resource group, the monthly budget and the lab VM.

.DESCRIPTION
Run it on your own computer, from the course folder:
  .\chapters\00-lab-setup\lab\setup.ps1 [-Yes]
Safe to run again: it updates what exists and creates what is missing.
The bash version, setup.sh, does the same on macOS and Linux.

.PARAMETER Yes
Do not ask for confirmation.
#>
[CmdletBinding()]
param([switch]$Yes)

. (Join-Path $PSScriptRoot '../../../scripts/lib.ps1')
$SetupWatch = [System.Diagnostics.Stopwatch]::StartNew()

$Chapter = '00'

# step: preflight
Read-CourseSetting
Assert-Command 'az' 'Install the Azure CLI: https://learn.microsoft.com/cli/azure/install-azure-cli'
Assert-Command 'ssh' 'Install the OpenSSH client.'
Assert-Command 'scp' 'Install the OpenSSH client.'
Assert-Command 'tar' 'Windows 10 and 11 include tar. On other systems, install it.'
Assert-AzSignedIn
Assert-ExpectedSubscription

if (-not $Config.LEARNER_IP) { Exit-WithError 'Set LEARNER_IP in .env to your public IPv4 address.' }
if ($Config.LEARNER_IP -notmatch '^([0-9]{1,3}\.){3}[0-9]{1,3}$') { Exit-WithError 'LEARNER_IP must be a plain IPv4 address, without /32.' }

$keyFile = Get-SshKeyFile
if (-not (Test-Path -LiteralPath $keyFile) -or -not (Test-Path -LiteralPath "$keyFile.pub")) {
    Exit-WithError "No SSH key pair at $($Config.SSH_KEY_PATH). Create it with: ssh-keygen -t ed25519 -f `"$keyFile`" -C aro-k8s-lab"
}
$sshPublicKey = (Get-Content -LiteralPath "$keyFile.pub" -Raw).Trim()
if (-not ($sshPublicKey.StartsWith('ssh-ed25519') -or $sshPublicKey.StartsWith('ssh-rsa'))) {
    Exit-WithError "$($Config.SSH_KEY_PATH).pub is not an Ed25519 or RSA public key."
}

# step: subscription
Write-Step 'Subscription'
$account = Get-AzJson @('account', 'show')
$subId = Get-Prop $account 'id'
$subscription = Get-AzJson @('rest', '--method', 'get', '--url', "https://management.azure.com/subscriptions/${subId}?api-version=2022-12-01")
$spendingLimit = Get-Prop $subscription 'subscriptionPolicies.spendingLimit'
if (-not $spendingLimit) { $spendingLimit = 'unknown' }
Write-Info "Subscription: $(Get-Prop $account 'name') ($(Get-Prop $account 'state')), spending limit: $spendingLimit"
if ((Get-Prop $account 'state') -ne 'Enabled') {
    Exit-WithError "The subscription is $(Get-Prop $account 'state'). Wait for the next billing period or pick another subscription."
}
if ($spendingLimit -eq 'Off') {
    Write-Info 'Warning: the spending limit is off, so nothing stops charges at the credit amount. The budget alerts still work.'
}

# step: region
Write-Step 'Checking the region, the VM size and the image'
$skus = @(Get-AzJson @('vm', 'list-skus', '--location', $Config.REGION, '--size', $Config.VM_SIZE, '--resource-type', 'virtualMachines'))
$sku = $skus | Where-Object { $null -ne $_ -and $_.name -eq $Config.VM_SIZE } | Select-Object -First 1
if (-not $sku) { Exit-WithError "$($Config.VM_SIZE) is not offered in $($Config.REGION). Pick another REGION or VM_SIZE in .env." }
$restrictions = @(Get-Prop $sku 'restrictions') | Where-Object { $null -ne $_ }
if (@($restrictions).Count -gt 0) {
    Exit-WithError "$($Config.VM_SIZE) is restricted for this subscription in $($Config.REGION) ($((@($restrictions) | ForEach-Object { $_.reasonCode }) -join ', ')). Pick another REGION or VM_SIZE in .env."
}
if ((Invoke-Native -FilePath 'az' -Arguments @('vm', 'image', 'show', '--urn', $Config.VM_IMAGE, '--location', $Config.REGION, '--output', 'none')).ExitCode -ne 0) {
    Exit-WithError "The image $($Config.VM_IMAGE) is not available in $($Config.REGION). List the options with: az vm image list --publisher Canonical --offer ubuntu-26_04-lts --location $($Config.REGION) --all --output table"
}
$imageParts = $Config.VM_IMAGE.Split(':')
if ($imageParts.Count -ne 4) { Exit-WithError 'VM_IMAGE must have the form publisher:offer:sku:version.' }
Write-Info "OK: $($Config.VM_SIZE) and $($Config.VM_IMAGE) are available in $($Config.REGION)."

# step: cost
Write-Step "Estimated cost (Azure Retail Prices API, $($Config.CURRENCY), pay-as-you-go)"
$vmHour = Get-PriceVmHour
$diskMonth = Get-PriceDiskMonth
$ipHour = Get-PricePublicIpHour
Write-Info "Lab VM $($Config.VM_SIZE): $vmHour per hour, only while it runs."
Write-Info "OS disk $($Config.OS_DISK_GB) GiB Standard SSD: $diskMonth per month, even while the VM is stopped."
Write-Info "Public IPv4 address: $ipHour per hour, even while the VM is stopped."
if ($vmHour -ne 'n/a' -and $diskMonth -ne 'n/a' -and $ipHour -ne 'n/a') {
    $vm = [double]::Parse($vmHour, $Invariant)
    $disk = [double]::Parse($diskMonth, $Invariant)
    $ip = [double]::Parse($ipHour, $Invariant)
    Write-Info "About $(Format-Number ($vm * 60 + $disk + $ip * 730)) $($Config.CURRENCY) per month if the VM runs 2 hours a day (60 hours)."
    Write-Info "About $(Format-Number ($disk / 30.4 + $ip * 24)) $($Config.CURRENCY) per day while the VM is stopped (disk and IP address)."
}
Write-Info "Budget: $($Config.BUDGET_AMOUNT) $($Config.CURRENCY) per month for the whole subscription, with alerts."

# step: confirm
if (-not (Confirm-Action "Create or update the lab environment in $($Config.REGION)?" $Yes)) {
    Write-Info 'Nothing changed.'
    exit 0
}

# step: providers
Write-Step 'Registering the resource providers used by the course'
$namespaces = @('Microsoft.Compute', 'Microsoft.Network', 'Microsoft.Storage', 'Microsoft.DevTestLab',
    'Microsoft.ContainerRegistry', 'Microsoft.Consumption', 'Microsoft.ContainerService', 'Microsoft.RedHatOpenShift',
    'Microsoft.ManagedIdentity', 'Microsoft.OperationalInsights')
foreach ($namespace in $namespaces) {
    $state = Get-AzValue @('provider', 'show', '--namespace', $namespace, '--query', 'registrationState')
    if ($state -eq 'Registered') {
        Write-Info "${namespace}: already registered"
    }
    else {
        Write-Info "${namespace}: registering (this can take a few minutes)"
        Invoke-AzChange @('provider', 'register', '--namespace', $namespace, '--wait') "Registering $namespace"
    }
}

# step: budget
Write-Step 'Budget'
$budgetUrl = Get-BudgetUrl $subId
$existingBudget = Get-AzJson @('rest', '--method', 'get', '--url', $budgetUrl)
$deployBudget = $true
if ($existingBudget) {
    $existingAmount = [int][double](Get-Prop $existingBudget 'properties.amount')
    if ($existingAmount -eq [int]$Config.BUDGET_AMOUNT) {
        $deployBudget = $false
        Write-Info "Budget $(Get-BudgetName) already exists with $($Config.BUDGET_AMOUNT) $($Config.CURRENCY). Kept as it is."
    }
    else {
        Write-Info "Budget amount changes from $existingAmount to $($Config.BUDGET_AMOUNT). Replacing the budget."
        Invoke-AzChange @('rest', '--method', 'delete', '--url', $budgetUrl) 'Deleting the old budget'
    }
}
$contactEmail = $Config.BUDGET_CONTACT_EMAIL
if (-not $contactEmail) { $contactEmail = Get-Prop $account 'user.name' }
if ("$contactEmail" -notmatch '@') { Exit-WithError 'No e-mail address for budget alerts. Set BUDGET_CONTACT_EMAIL in .env.' }

# step: deploy
Write-Step 'Deploying the lab environment (about 3 minutes)'
$vmExisted = (Invoke-Native -FilePath 'az' -Arguments @('vm', 'show', '--resource-group', (Get-RgName), '--name', (Get-VmName), '--output', 'none')).ExitCode -eq 0
# Parameters go through a file: Windows PowerShell 5.1 drops the quotes of JSON values on a command line.
$parameters = [ordered]@{
    prefix                    = @{ value = $Config.PREFIX }
    location                  = @{ value = $Config.REGION }
    chapter                   = @{ value = $Chapter }
    budgetAmount              = @{ value = [int]$Config.BUDGET_AMOUNT }
    budgetStartDate           = @{ value = (Get-Date).ToUniversalTime().ToString('yyyy-MM-01', $Invariant) }
    deployBudget              = @{ value = $deployBudget }
    budgetContactEmails       = @{ value = @($contactEmail) }
    learnerIp                 = @{ value = $Config.LEARNER_IP }
    sshPublicKey              = @{ value = $sshPublicKey }
    adminUsername             = @{ value = $Config.ADMIN_USERNAME }
    vmSize                    = @{ value = $Config.VM_SIZE }
    imagePublisher            = @{ value = $imageParts[0] }
    imageOffer                = @{ value = $imageParts[1] }
    imageSku                  = @{ value = $imageParts[2] }
    imageVersion              = @{ value = $imageParts[3] }
    osDiskSizeGB              = @{ value = [int]$Config.OS_DISK_GB }
    autoShutdownTime          = @{ value = $Config.AUTO_SHUTDOWN_TIME }
    autoShutdownTimeZone      = @{ value = $Config.AUTO_SHUTDOWN_TIMEZONE }
    shutdownNotificationEmail = @{ value = $contactEmail }
}
$parameterFile = Join-Path ([System.IO.Path]::GetTempPath()) ("aro-k8s-setup-{0}.json" -f [guid]::NewGuid().ToString('N'))
try {
    $document = [ordered]@{
        '$schema'      = 'https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#'
        contentVersion = '1.0.0.0'
        parameters     = $parameters
    }
    [System.IO.File]::WriteAllText($parameterFile, ($document | ConvertTo-Json -Depth 6), (New-Object System.Text.UTF8Encoding $false))
    Invoke-AzChange @('deployment', 'sub', 'create', '--name', "$($Config.PREFIX)-lab-setup", '--location', $Config.REGION,
        '--template-file', (Join-Path $PSScriptRoot 'infra/main.bicep'), '--parameters', "@$parameterFile") 'The deployment'
}
finally {
    Remove-Item -LiteralPath $parameterFile -Force -ErrorAction SilentlyContinue
}
Write-Info 'Deployment finished.'

# step: start-vm
$powerState = Get-PowerState
if ($powerState -ne 'PowerState/running') {
    Write-Info "The lab VM is $($powerState -replace 'PowerState/', ''). Starting it."
    Invoke-AzChange @('vm', 'start', '--resource-group', (Get-RgName), '--name', (Get-VmName)) 'Starting the lab VM'
}

$vmIp = Get-VmPublicIp
if (-not $vmExisted) {
    # A new VM can reuse an old IP address with a new host key: forget the old key.
    $knownHosts = Join-Path (Join-Path $HOME '.ssh') 'aro-k8s_known_hosts'
    if (Test-Path -LiteralPath $knownHosts) { Invoke-Native -FilePath 'ssh-keygen' -Arguments @('-R', $vmIp, '-f', $knownHosts) | Out-Null }
}

# step: wait-ssh
Write-Step "Waiting for SSH on $vmIp"
$ready = $false
for ($attempt = 1; $attempt -le 30; $attempt++) {
    if (Test-TcpPort $vmIp 22) { $ready = $true; break }
    Start-Sleep -Seconds 10
}
if (-not $ready) {
    Exit-WithError 'SSH did not answer after 5 minutes. Check that LEARNER_IP in .env is still your public IP, then run setup again.'
}

# step: wait-cloud-init
Write-Step 'Waiting for cloud-init to install the tools (5 to 10 minutes on the first run)'
if ((Invoke-LabSsh 'cloud-init status --wait > /dev/null 2>&1; test -f /etc/aro-k8s/tools-ready') -ne 0) {
    Exit-WithError 'The tool installation did not finish. Connect with .\scripts\lab-vm.ps1 connect, then read the log: sudo tail -n 50 /var/log/aro-k8s-install.log'
}
Invoke-LabSsh 'cat /etc/aro-k8s/tools-ready' | Out-Null

# step: sync
Write-Step 'Copying the course files to the lab VM'
Sync-CourseToVm

# step: done
Write-Step 'Done'
Write-Info ('Setup took {0} min.' -f [int][math]::Round($SetupWatch.Elapsed.TotalMinutes))
Write-Info "Lab VM: $(Get-VmName) in $(Get-RgName), reachable from $($Config.LEARNER_IP) only."
Write-Info "It shuts down every day at $($Config.AUTO_SHUTDOWN_TIME) ($($Config.AUTO_SHUTDOWN_TIMEZONE)). Stop it yourself when you finish:"
Write-Info '  .\chapters\00-lab-setup\lab\teardown.ps1 stop'
Write-Info 'Next: run the readiness report.'
Write-Info '  .\chapters\00-lab-setup\lab\validate.ps1'
