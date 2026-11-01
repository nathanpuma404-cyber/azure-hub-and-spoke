terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  backend "azurerm" {
    use_azuread_auth = true
  }
}

provider "azurerm" {
  resource_provider_registrations = "none"

  features {
    log_analytics_workspace {
      permanently_delete_on_destroy = true
    }

    resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }
}
