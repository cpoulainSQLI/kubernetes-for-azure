<#
.SYNOPSIS
Chapter 0 teardown: stop (deallocate) the lab VM, or destroy the whole lab environment.

.DESCRIPTION
Run it on your own computer, from the course folder:
  .\chapters\00-lab-setup\lab\teardown.ps1 stop       deallocates the lab VM (keeps the disk, the IP and your work)
  .\chapters\00-lab-setup\lab\teardown.ps1 destroy    deletes the lab resource group and the budget
Both modes end with a list of everything still tagged for the course. Safe to run twice.
The bash version, teardown.sh, does the same on macOS and Linux.

.PARAMETER Mode
stop or destroy.

.PARAMETER Yes
Do not ask for confirmation.
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)][ValidateSet('stop', 'destroy')][string]$Mode,
    [switch]$Yes
)

. (Join-Path $PSScriptRoot '../../../scripts/lib.ps1')

if (-not $Mode) {
    Write-Info 'Usage: .\chapters\00-lab-setup\lab\teardown.ps1 stop|destroy [-Yes]'
    Write-Info ''
    Write-Info '  stop      Deallocate the lab VM. Compute charges stop. The disk and the public IP'
    Write-Info '            address are still charged, and your work on the VM is kept.'
    Write-Info '  destroy   Delete the lab resource group (VM, disk, network, IP address, any chapter'
    Write-Info '            resource inside it) and the monthly budget. Your work on the VM is lost.'
    exit 1
}

Read-CourseSetting
Assert-Command 'az' 'Install the Azure CLI: https://learn.microsoft.com/cli/azure/install-azure-cli'
Assert-AzSignedIn
Assert-ExpectedSubscription

$rg = Get-RgName
$vm = Get-VmName

if ($Mode -eq 'stop') {
    # step: stop
    Write-Step 'Stopping (deallocating) the lab VM'
    $powerState = Get-PowerState
    if (-not $powerState) {
        Write-Info 'No lab VM found. Nothing to stop.'
    }
    elseif ($powerState -eq 'PowerState/deallocated') {
        Write-Info 'The lab VM is already deallocated.'
    }
    else {
        Invoke-AzChange @('vm', 'deallocate', '--resource-group', $rg, '--name', $vm) 'Deallocating the lab VM'
        Write-Info 'The lab VM is deallocated. Compute charges have stopped.'
    }
    Write-Info "Still charged while stopped: the OS disk ($(Get-PriceDiskMonth) $($Config.CURRENCY) per month) and the public IP address ($(Get-PricePublicIpHour) $($Config.CURRENCY) per hour)."
    Write-Info 'Start the VM again with: .\scripts\lab-vm.ps1 start'
}

if ($Mode -eq 'destroy') {
    # step: destroy-confirm
    Write-Step 'Destroying the lab environment'
    Write-Info "This deletes resource group $rg with everything in it, and budget $(Get-BudgetName)."
    Write-Info 'Your work on the lab VM is lost. Copy anything you want to keep first.'
    if (-not $Yes) {
        $typed = Read-Host "Type the prefix '$($Config.PREFIX)' to confirm"
        if ($typed -cne $Config.PREFIX) {
            Write-Info 'Nothing deleted.'
            exit 0
        }
    }

    # step: destroy-rg
    if ((Invoke-Native -FilePath 'az' -Arguments @('group', 'show', '--name', $rg, '--output', 'none')).ExitCode -eq 0) {
        Write-Info "Deleting resource group $rg (5 to 10 minutes)."
        Invoke-AzChange @('group', 'delete', '--name', $rg, '--yes') 'Deleting the resource group'
        Write-Info 'Resource group deleted.'
    }
    else {
        Write-Info "Resource group $rg does not exist."
    }

    # step: destroy-budget
    $subId = Get-AzValue @('account', 'show', '--query', 'id')
    $budgetUrl = Get-BudgetUrl $subId
    if (Get-AzJson @('rest', '--method', 'get', '--url', $budgetUrl)) {
        Invoke-AzChange @('rest', '--method', 'delete', '--url', $budgetUrl) 'Deleting the budget'
        Write-Info "Budget $(Get-BudgetName) deleted."
    }
    else {
        Write-Info "Budget $(Get-BudgetName) does not exist."
    }

    # step: destroy-known-hosts
    Remove-Item -LiteralPath (Join-Path (Join-Path $HOME '.ssh') 'aro-k8s_known_hosts') -Force -ErrorAction SilentlyContinue
    Write-Info 'Azure may have created a resource group named NetworkWatcherRG when the network was created. It costs nothing on its own and you can keep it.'
}

# step: list
Show-CourseResource
