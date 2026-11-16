#!/usr/bin/env bash
# Chapter 0 setup. Creates or updates the lab resource group, the monthly budget and the lab VM.
# Run it on your own computer, from the course folder:
#   chapters/00-lab-setup/lab/setup.sh [--yes]
# Safe to run again: it updates what exists and creates what is missing.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../scripts/lib.sh
source "${SCRIPT_DIR}/../../../scripts/lib.sh"

CHAPTER="00"

usage() {
  cat <<'EOF'
Usage: chapters/00-lab-setup/lab/setup.sh [--yes]

Creates or updates the chapter 0 lab environment in Azure:
  - resource group <PREFIX>-lab-rg
  - monthly budget <PREFIX>-monthly-budget with alerts
  - lab VM <PREFIX>-lab-vm with daily auto-shutdown, reachable over SSH from LEARNER_IP only

Options:
  --yes   do not ask for confirmation
EOF
}

for arg in "$@"; do
  case "$arg" in
    --yes) ASSUME_YES=1 ;;
    -h | --help)
      usage
      exit 0
      ;;
    *) die "Unknown option: ${arg}. Run with --help." ;;
  esac
done

# step: preflight
require_laptop
load_env
require_cmd az "Install the Azure CLI: https://learn.microsoft.com/cli/azure/install-azure-cli"
require_cmd ssh "Install an OpenSSH client."
require_cmd tar "Install tar (Git Bash on Windows includes it)."
require_az_login
require_expected_subscription

if [[ -z "$LEARNER_IP" ]]; then
  die "Set LEARNER_IP in .env to your public IPv4 address."
fi
if [[ ! "$LEARNER_IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
  die "LEARNER_IP must be a plain IPv4 address, without /32."
fi

key_file="$(ssh_key_file)"
if [[ ! -f "$key_file" || ! -f "${key_file}.pub" ]]; then
  die "No SSH key pair at ${SSH_KEY_PATH}. Create it with: ssh-keygen -t ed25519 -f ${SSH_KEY_PATH} -C aro-k8s-lab"
fi
ssh_public_key="$(tr -d '\r\n' <"${key_file}.pub")"
if [[ "$ssh_public_key" != ssh-ed25519* && "$ssh_public_key" != ssh-rsa* ]]; then
  die "${SSH_KEY_PATH}.pub is not an Ed25519 or RSA public key."
fi

# step: subscription
step "Subscription"
sub_id="$(az account show --query id --output tsv)"
sub_name="$(az account show --query name --output tsv)"
sub_state="$(az account show --query state --output tsv)"
spending_limit="$(az rest --method get \
  --url "https://management.azure.com/subscriptions/${sub_id}?api-version=2022-12-01" \
  --query subscriptionPolicies.spendingLimit --output tsv 2>/dev/null || echo "unknown")"
info "Subscription: ${sub_name} (${sub_state}), spending limit: ${spending_limit}"
if [[ "$sub_state" != "Enabled" ]]; then
  die "The subscription is ${sub_state}. Wait for the next billing period or pick another subscription."
fi
if [[ "$spending_limit" == "Off" ]]; then
  info "Warning: the spending limit is off, so nothing stops charges at the credit amount. The budget alerts still work."
fi

# step: region
step "Checking the region, the VM size and the image"
size_found="$(az vm list-skus --location "$REGION" --size "$VM_SIZE" --resource-type virtualMachines \
  --query "[?name=='${VM_SIZE}'] | length(@)" --output tsv)"
if [[ "$size_found" == "0" ]]; then
  die "${VM_SIZE} is not offered in ${REGION}. Pick another REGION or VM_SIZE in .env."
fi
size_restrictions="$(az vm list-skus --location "$REGION" --size "$VM_SIZE" --resource-type virtualMachines \
  --query "[?name=='${VM_SIZE}'].restrictions[].reasonCode" --output tsv)"
if [[ -n "$size_restrictions" ]]; then
  die "${VM_SIZE} is restricted for this subscription in ${REGION} (${size_restrictions}). Pick another REGION or VM_SIZE in .env."
fi
if ! az vm image show --urn "$VM_IMAGE" --location "$REGION" --output none 2>/dev/null; then
  die "The image ${VM_IMAGE} is not available in ${REGION}. List the options with: az vm image list --publisher Canonical --offer ubuntu-26_04-lts --location ${REGION} --all --output table"
fi
IFS=: read -r image_publisher image_offer image_sku image_version <<<"$VM_IMAGE"
info "OK: ${VM_SIZE} and ${VM_IMAGE} are available in ${REGION}."

# step: cost
step "Estimated cost (Azure Retail Prices API, ${CURRENCY}, pay-as-you-go)"
vm_hour="$(price_vm_hour)"
disk_month="$(price_disk_month)"
ip_hour="$(price_public_ip_hour)"
info "Lab VM ${VM_SIZE}: ${vm_hour} per hour, only while it runs."
info "OS disk ${OS_DISK_GB} GiB Standard SSD: ${disk_month} per month, even while the VM is stopped."
info "Public IPv4 address: ${ip_hour} per hour, even while the VM is stopped."
if [[ "$vm_hour" != "n/a" && "$disk_month" != "n/a" && "$ip_hour" != "n/a" ]]; then
  awk -v vm="$vm_hour" -v disk="$disk_month" -v ip="$ip_hour" -v cur="$CURRENCY" 'BEGIN {
    printf "About %.2f %s per month if the VM runs 2 hours a day (60 hours).\n", vm * 60 + disk + ip * 730, cur
    printf "About %.2f %s per day while the VM is stopped (disk and IP address).\n", disk / 30.4 + ip * 24, cur
  }'
fi
info "Budget: ${BUDGET_AMOUNT} ${CURRENCY} per month for the whole subscription, with alerts."

# step: confirm
if ! confirm "Create or update the lab environment in ${REGION}?"; then
  info "Nothing changed."
  exit 0
fi

# step: providers
step "Registering the resource providers used by the course"
for namespace in Microsoft.Compute Microsoft.Network Microsoft.Storage Microsoft.DevTestLab \
  Microsoft.ContainerRegistry Microsoft.Consumption Microsoft.ContainerService Microsoft.RedHatOpenShift \
  Microsoft.ManagedIdentity Microsoft.OperationalInsights; do
  state="$(az provider show --namespace "$namespace" --query registrationState --output tsv 2>/dev/null || echo "NotRegistered")"
  if [[ "$state" == "Registered" ]]; then
    info "${namespace}: already registered"
  else
    info "${namespace}: registering (this can take a few minutes)"
    az provider register --namespace "$namespace" --wait --output none
  fi
done

# step: budget
step "Budget"
budget_url="https://management.azure.com/subscriptions/${sub_id}/providers/Microsoft.Consumption/budgets/$(budget_name)?api-version=2023-05-01"
existing_amount="$(az rest --method get --url "$budget_url" --query properties.amount --output tsv 2>/dev/null || true)"
deploy_budget="true"
if [[ -n "$existing_amount" ]]; then
  if [[ "${existing_amount%.*}" == "$BUDGET_AMOUNT" ]]; then
    deploy_budget="false"
    info "Budget $(budget_name) already exists with ${BUDGET_AMOUNT} ${CURRENCY}. Kept as it is."
  else
    info "Budget amount changes from ${existing_amount%.*} to ${BUDGET_AMOUNT}. Replacing the budget."
    az rest --method delete --url "$budget_url" --output none
  fi
fi
contact_email="${BUDGET_CONTACT_EMAIL:-$(az account show --query user.name --output tsv)}"
if [[ "$contact_email" != *@* ]]; then
  die "No e-mail address for budget alerts. Set BUDGET_CONTACT_EMAIL in .env."
fi

# step: deploy
step "Deploying the lab environment (about 3 minutes)"
vm_existed="false"
if az vm show --resource-group "$(rg_name)" --name "$(vm_name)" --output none 2>/dev/null; then
  vm_existed="true"
fi
az deployment sub create \
  --name "${PREFIX}-lab-setup" \
  --location "$REGION" \
  --template-file "$(native_path "${SCRIPT_DIR}/infra/main.bicep")" \
  --parameters \
  prefix="$PREFIX" \
  location="$REGION" \
  chapter="$CHAPTER" \
  budgetAmount="$BUDGET_AMOUNT" \
  budgetStartDate="$(date -u +%Y-%m-01)" \
  deployBudget="$deploy_budget" \
  budgetContactEmails="[\"${contact_email}\"]" \
  learnerIp="$LEARNER_IP" \
  sshPublicKey="$ssh_public_key" \
  adminUsername="$ADMIN_USERNAME" \
  vmSize="$VM_SIZE" \
  imagePublisher="$image_publisher" \
  imageOffer="$image_offer" \
  imageSku="$image_sku" \
  imageVersion="$image_version" \
  osDiskSizeGB="$OS_DISK_GB" \
  autoShutdownTime="$AUTO_SHUTDOWN_TIME" \
  autoShutdownTimeZone="$AUTO_SHUTDOWN_TIMEZONE" \
  shutdownNotificationEmail="$contact_email" \
  --only-show-errors --output none
info "Deployment finished."

# step: start-vm
power_state="$(az vm get-instance-view --resource-group "$(rg_name)" --name "$(vm_name)" \
  --query "instanceView.statuses[?starts_with(code, 'PowerState/')].code | [0]" --output tsv)"
if [[ "$power_state" != "PowerState/running" ]]; then
  info "The lab VM is ${power_state#PowerState/}. Starting it."
  az vm start --resource-group "$(rg_name)" --name "$(vm_name)" --output none
fi

vm_ip="$(vm_public_ip)"
if [[ "$vm_existed" == "false" ]]; then
  # A new VM can reuse an old IP address with a new host key: forget the old key.
  ssh-keygen -R "$vm_ip" -f "$(known_hosts_file)" >/dev/null 2>&1 || true
fi

# step: wait-ssh
step "Waiting for SSH on ${vm_ip}"
ready="false"
for _ in $(seq 1 30); do
  if tcp_port_open "$vm_ip" 22; then
    ready="true"
    break
  fi
  sleep 10
done
if [[ "$ready" != "true" ]]; then
  die "SSH did not answer after 5 minutes. Check that LEARNER_IP in .env is still your public IP, then run setup again."
fi

# step: wait-cloud-init
step "Waiting for cloud-init to install the tools (5 to 10 minutes on the first run)"
if ! lab_ssh "cloud-init status --wait > /dev/null 2>&1; test -f /etc/aro-k8s/tools-ready"; then
  die "The tool installation did not finish. Read the log on the VM with: scripts/lab-vm.sh connect, then: sudo tail -n 50 /var/log/aro-k8s-install.log"
fi
lab_ssh "cat /etc/aro-k8s/tools-ready"

# step: sync
step "Copying the course files to the lab VM"
sync_course_to_vm

# step: done
step "Done"
info "Setup took $(duration_text "$SECONDS")."
info "Lab VM: $(vm_name) in $(rg_name), reachable from ${LEARNER_IP} only."
info "It shuts down every day at ${AUTO_SHUTDOWN_TIME} (${AUTO_SHUTDOWN_TIMEZONE}). Stop it yourself when you finish:"
info "  chapters/00-lab-setup/lab/teardown.sh stop"
info "Next: run the readiness report."
info "  chapters/00-lab-setup/lab/validate.sh"
