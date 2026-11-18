# Kubernetes, hands-on

A catalogue of hands-on courses on containers, Kubernetes and the platforms built on it. The first courses run on your own computer. Only the courses on Azure Kubernetes Service and Azure Red Hat OpenShift use Azure.

This repository is the website: static HTML pages with no build step. The site is published at https://ashy-tree-001ac5303.6.azurestaticapps.net/.

Learners do not need this repository. Each course has its own lab kit, named after it: the kit of course 1, "Containers and Kubernetes", is `kubernetes-labs`. A kit holds the `course` command, the lab scripts, the sample app and the files of the reference solutions. The Introduction and Setup pages of each course explain how to use it.

## What is here

| Path | Content |
|---|---|
| `index.html` | The catalogue: one card per course |
| `about.html`, `resources.html`, `azure-limits.html`, `style-guide.html` | Pages shared by every course |
| `courses/<name>/` | One folder per course: its home page, Introduction, Setup, chapters, solutions and sample app pages |
| `courses/<name>/chapters/NN-name/` | One page per chapter, and its generated lab sheet |
| `assets/` | Style sheet, script with the navigation of each course, search index and diagrams |
| `staticwebapp.config.json` | The redirects from the addresses the site had before the catalogue |
| `archive/` | Earlier draft material kept unchanged |
| `scripts/` | The lab sheet and search index builders, and the checker of the site |
| `infra/` | Terraform of the hosting of the site |
| `.github/workflows/deploy.yml` | Checks the site against the kits, then deploys it from `main` |

## Checks

Contributors read [style-guide.html](style-guide.html) first. Its Checks section lists what to run before a change. The checker of the site also reads the kit of each course, `<name>-labs`, in the parent folder of this one or wherever `KITS_DIR` points.

## Hosting

The site is an Azure Static Web Apps resource on the Free plan, created with the Terraform files in `infra/`. On every push, the workflow `.github/workflows/deploy.yml` runs the checks. On `main` only, it then writes `assets/kit.js` with the GitHub account that hosts the kits, and uploads the pages with `staticwebapp.config.json`. It deploys nothing when a check fails, and nothing from another branch.

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

The state folder keeps the name it had before the site was renamed, so that the existing state is found.

The workflow needs the deployment token in the repository secret `AZURE_STATIC_WEB_APPS_API_TOKEN`. This pipes it from Terraform to GitHub without showing it:

```powershell
terraform -chdir=infra output -raw deployment_token | gh secret set AZURE_STATIC_WEB_APPS_API_TOKEN --repo <account>/kubernetes-hands-on
```
