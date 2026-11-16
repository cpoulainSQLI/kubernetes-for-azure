# Kubernetes and Azure Red Hat OpenShift, hands-on

A hands-on course, from zero containers to an Azure Red Hat OpenShift cluster, with labs on your own Azure subscription.

This repository is the website of the course: static HTML pages with no build step. The site is published at https://ashy-tree-001ac5303.6.azurestaticapps.net/.

Learners do not need this repository. They clone the lab kit, `kubernetes-for-azure-labs`, which holds the `course` command, the lab scripts, the sample app and the files of the reference solutions. The Introduction and Setup pages of the site explain how.

## What is here

| Path | Content |
|---|---|
| `index.html`, `introduction.html`, `setup.html` | Home page, introduction, setup of the lab environment |
| `about.html`, `resources.html`, `azure-limits.html` | Goal and learner profile, primary sources, Azure limits |
| `chapters/NN-name/` | One page per chapter, and its generated lab sheet |
| `solutions/`, `sample-app/` | Pages that explain the reference solutions and the sample app, with links to their files in the kit |
| `assets/` | Style sheet, script, search index and diagrams |
| `archive/` | Earlier draft material kept unchanged, to be reworked for chapter 7 |
| `scripts/` | The lab sheet and search index builders, and the checker of the site |
| `infra/` | Terraform of the hosting of the site |
| `.github/workflows/deploy.yml` | Checks the site against the kit, then deploys it |

## Checks

Contributors read [style-guide.html](style-guide.html) first. Its Checks section lists what to run before a change. The checker of the site also reads a checkout of the lab kit, in the sibling folder `../kubernetes-for-azure-labs` or wherever `KIT_DIR` points.

## Hosting

The site is an Azure Static Web Apps resource on the Free plan, created with the Terraform files in `infra/`. On every push to `main`, the workflow `.github/workflows/deploy.yml` runs the checks, writes `assets/kit.js` with the GitHub account that hosts the kit, and uploads the pages. It deploys nothing when a check fails.

The Terraform state holds the deployment token, so it stays in a local file under your user profile, outside this repository and outside any synchronised folder. In PowerShell, signed in with `az login` on the subscription that hosts the site:

```powershell
$state = Join-Path $HOME '.kubernetes-for-azure\site'
New-Item -ItemType Directory -Force $state | Out-Null
$env:TF_DATA_DIR = Join-Path $state '.terraform'
$env:TF_VAR_subscription_id = az account show --query id --output tsv
terraform -chdir=infra init "-backend-config=path=$state\terraform.tfstate"
terraform -chdir=infra plan "-out=$state\site.tfplan"
terraform -chdir=infra apply "$state\site.tfplan"
terraform -chdir=infra output default_host_name
```

The workflow needs the deployment token in the repository secret `AZURE_STATIC_WEB_APPS_API_TOKEN`. This pipes it from Terraform to GitHub without showing it:

```powershell
terraform -chdir=infra output -raw deployment_token | gh secret set AZURE_STATIC_WEB_APPS_API_TOKEN --repo <account>/kubernetes-for-azure
```
