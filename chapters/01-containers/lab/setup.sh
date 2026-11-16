#!/usr/bin/env bash
# Chapter 1 setup. Creates the chapter registry and copies the sample app to ~/work.
# Run it on the lab VM:
#   ~/aro-k8s-course/chapters/01-containers/lab/setup.sh [--yes]
# Safe to run again.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../scripts/lib.sh
source "${SCRIPT_DIR}/../../../scripts/lib.sh"

CHAPTER="01"
WORK_DIR="${HOME}/work/01-containers"

for arg in "$@"; do
  case "$arg" in
    --yes) ASSUME_YES=1 ;;
    -h | --help)
      echo "Usage: chapters/01-containers/lab/setup.sh [--yes]"
      echo "Creates a Basic Azure Container Registry for chapter 1 and copies the sample app to ${WORK_DIR}."
      exit 0
      ;;
    *) die "Unknown option: ${arg}. Run with --help." ;;
  esac
done

require_lab_vm
load_env
require_cmd docker "Run chapter 0 setup again: Docker should be on the lab VM."
require_cmd az "Run chapter 0 setup again: the Azure CLI should be on the lab VM."

if ! docker info >/dev/null 2>&1; then
  die "Docker does not answer. If chapter 0 just finished, disconnect and reconnect so your docker group membership applies."
fi

step "Signing in to Azure"
ensure_vm_identity_login
require_expected_subscription
info "Signed in as the lab VM's managed identity."

step "Estimated cost"
info "Basic registry: $(price_acr_basic_day) ${CURRENCY} per day while it exists, 10 GiB of storage included."
info "teardown.sh deletes it at the end of the chapter."
if ! confirm "Create or update the chapter 1 registry in $(rg_name)?"; then
  info "Nothing changed."
  exit 0
fi

step "Deploying the registry (about a minute)"
registry_name="$(az deployment group create \
  --resource-group "$(rg_name)" \
  --name "${PREFIX}-ch${CHAPTER}-registry" \
  --template-file "${SCRIPT_DIR}/infra/registry.bicep" \
  --parameters prefix="$PREFIX" location="$REGION" chapter="$CHAPTER" \
  --query properties.outputs.name.value --output tsv --only-show-errors)"
login_server="$(az acr show --name "$registry_name" --query loginServer --output tsv)"
info "Registry ready: ${login_server}"

step "Copying the sample app to ${WORK_DIR}"
mkdir -p "$WORK_DIR"
if [[ -d "${WORK_DIR}/sample-app" ]]; then
  info "${WORK_DIR}/sample-app already exists. Kept as it is."
else
  cp -r "${COURSE_ROOT}/sample-app" "${WORK_DIR}/sample-app"
  info "Copied."
fi

step "Done"
info "Setup took $(duration_text "$SECONDS")."
info "Registry login server: ${login_server}"
info "Your working folder: ${WORK_DIR}/sample-app"
info "Next: do the lab tasks of the chapter 1 page. The guided check follows you task by task:"
info "  ~/${VM_COURSE_DIR}/chapters/01-containers/lab/validate.sh --guided"
info "At the end, the full report:"
info "  ~/${VM_COURSE_DIR}/chapters/01-containers/lab/validate.sh"
