# Hosting of the website: a resource group and an Azure Static Web Apps resource on the Free plan.
# The workflow in .github/workflows/deploy.yml uploads the pages with the deployment token of the app.

locals {
  tags = var.tags
}

resource "azurerm_resource_group" "site" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.tags
}

resource "azurerm_static_web_app" "site" {
  name                = var.app_name
  resource_group_name = azurerm_resource_group.site.name
  location            = azurerm_resource_group.site.location
  sku_tier            = "Free"
  sku_size            = "Free"
  # No staging environments for pull requests: the workflow deploys main only.
  preview_environments_enabled = false
  tags                         = local.tags
}
