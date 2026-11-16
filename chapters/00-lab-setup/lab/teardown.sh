#!/usr/bin/env bash
# Chapter 0 teardown. Run it on your own computer, from the course folder:
#   chapters/00-lab-setup/lab/teardown.sh stop       deallocates the lab VM (keeps the disk, the IP and your work)
#   chapters/00-lab-setup/lab/teardown.sh destroy    deletes the lab resource group and the budget
# Both modes end with a list of everything still tagged for the course. Safe to run twice.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../scripts/lib.sh
source "${SCRIPT_DIR}/../../../scripts/lib.sh"

usage() {
  cat <<'EOF'
Usage: chapters/00-lab-setup/lab/teardown.sh stop|destroy [--yes]

  stop      Deallocate the lab VM. Compute charges stop. The disk and the public IP
            address are still charged, and your work on the VM is kept.
  destroy   Delete the lab resource group (VM, disk, network, IP address, any chapter
            resource inside it) and the monthly budget. Your work on the VM is lost.

Options:
  --yes     do not ask for confirmation
EOF
}

mode=""
for arg in "$@"; do
  case "$arg" in
    stop | destroy) mode="$arg" ;;
    --yes) ASSUME_YES=1 ;;
    -h | --help)
      usage
      exit 0
      ;;
    *) die "Unknown option: ${arg}. Run with --help." ;;
  esac
done
if [[ -z "$mode" ]]; then
  usage
  exit 1
fi

require_laptop
load_env
require_cmd az "Install the Azure CLI: https://learn.microsoft.com/cli/azure/install-azure-cli"
require_az_login
require_expected_subscription

rg="$(rg_name)"
vm="$(vm_name)"

if [[ "$mode" == "stop" ]]; then
  # step: stop
  step "Stopping (deallocating) the lab VM"
  power_state="$(az vm get-instance-view --resource-group "$rg" --name "$vm" \
    --query "instanceView.statuses[?starts_with(code, 'PowerState/')].code | [0]" --output tsv 2>/dev/null || true)"
  if [[ -z "$power_state" ]]; then
    info "No lab VM found. Nothing to stop."
  elif [[ "$power_state" == "PowerState/deallocated" ]]; then
    info "The lab VM is already deallocated."
  else
    az vm deallocate --resource-group "$rg" --name "$vm" --output none
    info "The lab VM is deallocated. Compute charges have stopped."
  fi
  disk_month="$(price_disk_month)"
  ip_hour="$(price_public_ip_hour)"
  info "Still charged while stopped: the OS disk (${disk_month} ${CURRENCY} per month) and the public IP address (${ip_hour} ${CURRENCY} per hour)."
  info "Start the VM again with: scripts/lab-vm.sh start"
fi

if [[ "$mode" == "destroy" ]]; then
  # step: destroy-confirm
  step "Destroying the lab environment"
  info "This deletes resource group ${rg} with everything in it, and budget $(budget_name)."
  info "Your work on the lab VM is lost. Copy anything you want to keep first."
  if [[ "$ASSUME_YES" != "1" ]]; then
    read -r -p "Type the prefix '${PREFIX}' to confirm: " typed || true
    if [[ "$typed" != "$PREFIX" ]]; then
      info "Nothing deleted."
      exit 0
    fi
  fi

  # step: destroy-rg
  if az group show --name "$rg" --output none 2>/dev/null; then
    info "Deleting resource group ${rg} (5 to 10 minutes)."
    az group delete --name "$rg" --yes --output none
    info "Resource group deleted."
  else
    info "Resource group ${rg} does not exist."
  fi

  # step: destroy-budget
  sub_id="$(az account show --query id --output tsv)"
  budget_url="https://management.azure.com/subscriptions/${sub_id}/providers/Microsoft.Consumption/budgets/$(budget_name)?api-version=2023-05-01"
  if az rest --method get --url "$budget_url" --output none 2>/dev/null; then
    az rest --method delete --url "$budget_url" --output none
    info "Budget $(budget_name) deleted."
  else
    info "Budget $(budget_name) does not exist."
  fi

  # step: destroy-known-hosts
  rm -f "$(known_hosts_file)"
  info "Azure may have created a resource group named NetworkWatcherRG when the network was created. It costs nothing on its own and you can keep it."
fi

# step: list
list_course_resources
