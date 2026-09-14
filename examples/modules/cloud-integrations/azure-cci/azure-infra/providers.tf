terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    azapi = {
      source  = "azure/azapi"
      version = "~> 1.0"
    }
  }
}

# No explicit credentials — uses `az login` locally or ARM_* env vars in CI/CD
provider "azurerm" {
  features {}
}

provider "azapi" {}
