# Hosting of the website: Terraform and provider versions, state backend and provider settings.
# The author runs it from his own computer. README.md gives the commands.

terraform {
  required_version = ">= 1.17.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.14"
    }
  }

  # The state holds the deployment token of the site, so it stays in a local file under the user profile,
  # outside OneDrive and outside both repositories. terraform init passes its path with -backend-config.
  backend "local" {}
}

provider "azurerm" {
  subscription_id = var.subscription_id

  # Register only the resource provider of Static Web Apps, not the default set.
  resource_provider_registrations = "none"
  resource_providers_to_register  = ["Microsoft.Web"]

  features {}
}
