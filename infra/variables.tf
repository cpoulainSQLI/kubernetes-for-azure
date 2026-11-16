# Hosting of the website: input variables. Pass the subscription with TF_VAR_subscription_id, never in a file.

variable "subscription_id" {
  description = "Subscription that hosts the website."
  type        = string
}

variable "location" {
  description = "Region of the Static Web Apps resource. The content is served globally, and the region only hosts managed Functions and staging environments."
  type        = string
  default     = "westeurope"

  validation {
    # The regions that Microsoft.Web/staticSites accepted on 16 November 2026, from az provider show.
    condition     = contains(["centralus", "eastus2", "westus2", "westeurope", "eastasia"], var.location)
    error_message = "Static Web Apps accepts centralus, eastus2, westus2, westeurope or eastasia."
  }
}

variable "resource_group_name" {
  description = "Resource group of the website, created by this configuration."
  type        = string
  default     = "kubernetes-for-azure-site-rg"
}

variable "app_name" {
  description = "Name of the Static Web Apps resource. The site keeps the hostname that Azure generates for it."
  type        = string
  default     = "kubernetes-for-azure"
}

variable "tags" {
  description = "Tags of every resource of the website. Never course=aro-k8s, so that the clean-up commands of the kit never list or delete the website."
  type        = map(string)
  default = {
    project   = "kubernetes-for-azure"
    component = "site"
  }

  validation {
    condition     = !contains(keys(var.tags), "course")
    error_message = "The website must not carry a course tag: the clean-up commands of the kit look for course=aro-k8s."
  }
}
