#!/usr/bin/env bash
# Shared helpers for every lab script in the course.
# Source this file from a script. Do not run it on its own.
# shellcheck disable=SC2034  # Variables defined here are used by the scripts that source this file.

if [[ -n "${ARO_K8S_LIB_LOADED:-}" ]]; then
  return 0
fi
ARO_K8S_LIB_LOADED=1

COURSE_TAG_KEY="course"
COURSE_TAG_VALUE="aro-k8s"
COURSE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LAB_VM_MARKER="/etc/aro-k8s/lab-vm"
KIND_CLUSTER_NAME="aro-k8s"
VM_COURSE_DIR="aro-k8s-course"

# Tool versions installed by chapter 0 cloud-init. Keep them in line with
# chapters/00-lab-setup/lab/infra/cloud-init.yaml and the kind cluster file of chapter 2.
PINNED_KIND_VERSION="v0.33.0"
PINNED_KUBECTL_MINOR="v1.37"

# Git Bash on Windows rewrites arguments that start with a slash, such as
# Azure resource IDs. This turns that rewriting off for every az call.
# The Azure CLI for Windows also ends its output lines with a carriage return,
# which breaks string comparisons in bash, so the wrapper below removes it.
case "$(uname -s)" in
  MINGW* | MSYS* | CYGWIN*)
    export MSYS_NO_PATHCONV=1
    az() {
      local rc
      command az "$@" | tr -d '\r'
      rc="${PIPESTATUS[0]}"
      return "$rc"
    }
    ;;
esac

if [[ -t 1 ]]; then
  C_GREEN=$'\033[32m'
  C_RED=$'\033[31m'
  C_YELLOW=$'\033[33m'
  C_BOLD=$'\033[1m'
  C_RESET=$'\033[0m'
else
  C_GREEN=""
  C_RED=""
  C_YELLOW=""
  C_BOLD=""
  C_RESET=""
fi

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0
SKIP_COUNT=0

# The guided validation of a lab (scripts/lib-validate.sh) collects the check
# lines of a stage before it shows them. Everywhere else they print at once.
CHECK_BUFFERING=0
CHECK_BUFFER=""

# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------

info() {
  printf '%s\n' "$*"
}

step() {
  printf '\n%s==> %s%s\n' "$C_BOLD" "$*" "$C_RESET"
}

die() {
  printf '%sERROR%s %s\n' "$C_RED" "$C_RESET" "$*" >&2
  exit 1
}

# Prints one line of a validation report, or keeps it for later when buffering is on.
check_line() {
  if [[ "$CHECK_BUFFERING" == "1" ]]; then
    CHECK_BUFFER="${CHECK_BUFFER}${1}"$'\n'
  else
    printf '%s\n' "$1"
  fi
}

check_pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  check_line "${C_GREEN}[PASS]${C_RESET} $1"
}

check_fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  check_line "${C_RED}[FAIL]${C_RESET} $1"
  if [[ -n "${2:-}" ]]; then
    check_line "       hint: $2"
  fi
  return 0
}

check_warn() {
  WARN_COUNT=$((WARN_COUNT + 1))
  check_line "${C_YELLOW}[WARN]${C_RESET} $1"
  if [[ -n "${2:-}" ]]; then
    check_line "       hint: $2"
  fi
  return 0
}

# Prints a number of seconds as text, for example "45 s" or "12 min".
duration_text() {
  if (($1 < 60)); then
    printf '%d s' "$1"
  else
    printf '%d min' "$((($1 + 30) / 60))"
  fi
}

# A check that was not run, for example a live test without --deep. It never fails the run.
check_skip() {
  SKIP_COUNT=$((SKIP_COUNT + 1))
  check_line "[SKIP] $1"
  return 0
}

# An extra line under a check, such as a detail of what was found. It is not counted.
check_note() {
  check_line "       $1"
}

# Prints the totals and returns 1 when at least one check failed.
check_summary() {
  if ((SKIP_COUNT > 0)); then
    printf '\nSummary: %d PASS, %d FAIL, %d WARN, %d SKIP\n' "$PASS_COUNT" "$FAIL_COUNT" "$WARN_COUNT" "$SKIP_COUNT"
  else
    printf '\nSummary: %d PASS, %d FAIL, %d WARN\n' "$PASS_COUNT" "$FAIL_COUNT" "$WARN_COUNT"
  fi
  if ((FAIL_COUNT > 0)); then
    printf 'Result: FAIL. Fix the failed checks and run the validation again.\n'
    return 1
  fi
  printf 'Result: PASS.\n'
  return 0
}

# ---------------------------------------------------------------------------
# Arguments and prompts
# ---------------------------------------------------------------------------

ASSUME_YES="${ASSUME_YES:-0}"

# Asks a yes or no question. Returns 0 for yes. --yes on the command line skips it.
confirm() {
  if [[ "$ASSUME_YES" == "1" ]]; then
    return 0
  fi
  local answer=""
  read -r -p "$1 [y/N] " answer || true
  [[ "$answer" =~ ^[Yy]$ ]]
}

# ---------------------------------------------------------------------------
# Settings from .env
# ---------------------------------------------------------------------------

# Reads KEY=VALUE lines from .env without executing them.
load_env() {
  local env_file="${COURSE_ROOT}/.env"
  if [[ ! -f "$env_file" ]]; then
    die "No .env file at ${env_file}. Copy .env.example to .env and fill it in."
  fi
  local line key value
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    if [[ ! "$line" =~ ^([A-Z][A-Z0-9_]*)=(.*)$ ]]; then
      continue
    fi
    key="${BASH_REMATCH[1]}"
    value="${BASH_REMATCH[2]}"
    if [[ "$value" =~ ^\"(.*)\"$ || "$value" =~ ^\'(.*)\'$ ]]; then
      value="${BASH_REMATCH[1]}"
    fi
    export "${key}=${value}"
  done <"$env_file"

  export PREFIX="${PREFIX:-arok8s}"
  export REGION="${REGION:-swedencentral}"
  export CURRENCY="${CURRENCY:-EUR}"
  export BUDGET_AMOUNT="${BUDGET_AMOUNT:-30}"
  export BUDGET_CONTACT_EMAIL="${BUDGET_CONTACT_EMAIL:-}"
  export AZURE_SUBSCRIPTION="${AZURE_SUBSCRIPTION:-}"
  export LEARNER_IP="${LEARNER_IP:-}"
  export SSH_KEY_PATH="${SSH_KEY_PATH:-~/.ssh/aro-k8s-lab}"
  export ADMIN_USERNAME="${ADMIN_USERNAME:-azureuser}"
  export VM_SIZE="${VM_SIZE:-Standard_D2as_v5}"
  export VM_IMAGE="${VM_IMAGE:-Canonical:ubuntu-26_04-lts:server:latest}"
  export OS_DISK_GB="${OS_DISK_GB:-64}"
  export AUTO_SHUTDOWN_TIME="${AUTO_SHUTDOWN_TIME:-1900}"
  export AUTO_SHUTDOWN_TIMEZONE="${AUTO_SHUTDOWN_TIMEZONE:-UTC}"

  if [[ ! "$PREFIX" =~ ^[a-z][a-z0-9]{2,11}$ ]]; then
    die "PREFIX must be 3 to 12 lowercase letters or digits and start with a letter."
  fi
  if [[ ! "$BUDGET_AMOUNT" =~ ^[0-9]+$ ]]; then
    die "BUDGET_AMOUNT must be a whole number, for example 30."
  fi
  case "$OS_DISK_GB" in
    32 | 64 | 128) ;;
    *) die "OS_DISK_GB must be 32, 64 or 128." ;;
  esac
  if [[ ! "$AUTO_SHUTDOWN_TIME" =~ ^[0-2][0-9][0-5][0-9]$ ]]; then
    die "AUTO_SHUTDOWN_TIME must use the hhmm format, for example 1900."
  fi
}

# ---------------------------------------------------------------------------
# Names and tags
# ---------------------------------------------------------------------------

rg_name() { printf '%s-lab-rg' "$PREFIX"; }
vm_name() { printf '%s-lab-vm' "$PREFIX"; }
budget_name() { printf '%s-monthly-budget' "$PREFIX"; }

# Prints the tag arguments for az commands, for example: course=aro-k8s chapter=01
course_tags() {
  printf '%s=%s chapter=%s' "$COURSE_TAG_KEY" "$COURSE_TAG_VALUE" "$1"
}

# Prints the Standard SSD disk tier that matches OS_DISK_GB.
os_disk_tier() {
  case "$OS_DISK_GB" in
    32) printf 'E4' ;;
    64) printf 'E6' ;;
    128) printf 'E10' ;;
  esac
}

# ---------------------------------------------------------------------------
# Where the script runs
# ---------------------------------------------------------------------------

on_lab_vm() {
  [[ -f "$LAB_VM_MARKER" ]]
}

require_lab_vm() {
  if ! on_lab_vm; then
    die "Run this script on the lab VM, not on your own computer. Connect with: scripts/lab-vm.sh connect (or .\\scripts\\lab-vm.ps1 connect in PowerShell)"
  fi
}

require_laptop() {
  if on_lab_vm; then
    die "Run this script on your own computer, not on the lab VM."
  fi
}

# Converts a path for Windows programs such as az when running in Git Bash.
native_path() {
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -m "$1"
  else
    printf '%s' "$1"
  fi
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    die "The command '$1' is missing. ${2:-}"
  fi
}

# ---------------------------------------------------------------------------
# Azure CLI
# ---------------------------------------------------------------------------

az_signed_in() {
  az account show --output none 2>/dev/null
}

require_az_login() {
  if az_signed_in; then
    return 0
  fi
  if on_lab_vm; then
    die "The Azure CLI on the lab VM is not signed in. Run: az login --identity"
  fi
  die "The Azure CLI is not signed in. Run: az login"
}

# Setup scripts on the lab VM sign in with the VM's managed identity.
ensure_vm_identity_login() {
  if az_signed_in; then
    return 0
  fi
  info "Signing in to Azure with the lab VM's managed identity."
  az login --identity --output none
}

# Stops when AZURE_SUBSCRIPTION is set and the CLI points at another subscription.
require_expected_subscription() {
  if [[ -z "$AZURE_SUBSCRIPTION" ]]; then
    return 0
  fi
  local current_name current_id
  current_name="$(az account show --query name --output tsv)"
  current_id="$(az account show --query id --output tsv)"
  if [[ "$AZURE_SUBSCRIPTION" != "$current_name" && "$AZURE_SUBSCRIPTION" != "$current_id" ]]; then
    die "The Azure CLI points at '${current_name}', not at AZURE_SUBSCRIPTION. Run: az account set --subscription \"\$AZURE_SUBSCRIPTION\""
  fi
}

# ---------------------------------------------------------------------------
# Prices from the Azure Retail Prices API (no sign-in needed)
# ---------------------------------------------------------------------------

# retail_price FILTER [JMESPATH]
# Prints the first matching pay-as-you-go Linux price, or n/a when the lookup fails.
retail_price() {
  local filter="$1"
  local query="${2:-Items[?type=='Consumption' && !contains(productName, 'Windows') && !contains(skuName, 'Spot') && !contains(skuName, 'Low Priority')].retailPrice | [0]}"
  local price=""
  price="$(az rest --method get --skip-authorization-header \
    --url "https://prices.azure.com/api/retail/prices" \
    --url-parameters "currencyCode='${CURRENCY}'" "\$filter=${filter}" \
    --query "$query" --output tsv 2>/dev/null || true)"
  if [[ -z "$price" || "$price" == "None" ]]; then
    printf 'n/a'
  else
    printf '%s' "$price"
  fi
}

price_vm_hour() {
  retail_price "serviceName eq 'Virtual Machines' and armRegionName eq '${REGION}' and armSkuName eq '${VM_SIZE}'"
}

price_disk_month() {
  local tier
  tier="$(os_disk_tier)"
  retail_price "armRegionName eq '${REGION}' and productName eq 'Standard SSD Managed Disks' and meterName eq '${tier} LRS Disk'" \
    "Items[?type=='Consumption'].retailPrice | [0]"
}

price_public_ip_hour() {
  retail_price "armRegionName eq '${REGION}' and productName eq 'IP Addresses' and meterName eq 'Standard IPv4 Static Public IP'" \
    "Items[?type=='Consumption'].retailPrice | [0]"
}

price_acr_basic_day() {
  retail_price "armRegionName eq '${REGION}' and serviceName eq 'Container Registry' and meterName eq 'Basic Registry Unit'" \
    "Items[?type=='Consumption'].retailPrice | [0]"
}

# ---------------------------------------------------------------------------
# Lab VM access from your own computer
# ---------------------------------------------------------------------------

# Returns 0 when a TCP port answers within 5 seconds. Works with bash 3.2 (macOS),
# which has no timeout command.
tcp_port_open() {
  local host="$1" port="$2" probe watchdog
  (exec 3<>"/dev/tcp/${host}/${port}") 2>/dev/null &
  probe=$!
  (sleep 5 && kill "$probe" 2>/dev/null) &
  watchdog=$!
  if wait "$probe" 2>/dev/null; then
    kill "$watchdog" 2>/dev/null || true
    return 0
  fi
  kill "$watchdog" 2>/dev/null || true
  return 1
}

ssh_key_file() {
  printf '%s' "${SSH_KEY_PATH/#\~/$HOME}"
}

known_hosts_file() {
  printf '%s/.ssh/aro-k8s_known_hosts' "$HOME"
}

vm_public_ip() {
  az network public-ip show --resource-group "$(rg_name)" --name "$(vm_name)-pip" \
    --query ipAddress --output tsv 2>/dev/null || true
}

# Runs a command on the lab VM over SSH. With no arguments it opens a shell.
lab_ssh() {
  local ip
  ip="$(vm_public_ip)"
  if [[ -z "$ip" ]]; then
    die "No public IP found for the lab VM. Run chapter 0 setup first."
  fi
  ssh -i "$(ssh_key_file)" \
    -o StrictHostKeyChecking=accept-new \
    -o UserKnownHostsFile="$(known_hosts_file)" \
    -o ConnectTimeout=10 \
    -o BatchMode=yes \
    "${ADMIN_USERNAME}@${ip}" "$@"
}

# Copies the course files (not your work in ~/work) to ~/aro-k8s-course on the lab VM.
sync_course_to_vm() {
  info "Copying the course files to ~/${VM_COURSE_DIR} on the lab VM."
  tar -C "$COURSE_ROOT" --exclude=.git -czf - . |
    lab_ssh "mkdir -p ~/${VM_COURSE_DIR} && tar -xzf - -C ~/${VM_COURSE_DIR} && find ~/${VM_COURSE_DIR} -name '*.sh' -exec chmod +x {} +"
}

# ---------------------------------------------------------------------------
# Clean-up report
# ---------------------------------------------------------------------------

list_course_resources() {
  step "Azure resources still tagged ${COURSE_TAG_KEY}=${COURSE_TAG_VALUE}"
  local groups resources
  groups="$(az group list --tag "${COURSE_TAG_KEY}=${COURSE_TAG_VALUE}" \
    --query "[].{group:name, chapter:tags.chapter, state:properties.provisioningState}" --output table 2>/dev/null || true)"
  resources="$(az resource list --tag "${COURSE_TAG_KEY}=${COURSE_TAG_VALUE}" \
    --query "[].{name:name, type:type, chapter:tags.chapter, group:resourceGroup}" --output table 2>/dev/null || true)"
  if [[ -z "$groups" && -z "$resources" ]]; then
    info "Nothing found. No course resource is left in this subscription."
    return 0
  fi
  if [[ -n "$groups" ]]; then
    printf 'Resource groups:\n%s\n\n' "$groups"
  fi
  if [[ -n "$resources" ]]; then
    printf 'Resources:\n%s\n' "$resources"
  fi
}
