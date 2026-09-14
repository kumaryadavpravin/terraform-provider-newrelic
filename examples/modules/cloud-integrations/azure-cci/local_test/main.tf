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
    newrelic = {
      source = "newrelic/newrelic"
    }
  }
}

provider "azurerm" {
  features {}
  # uses `az login` session
}

provider "azapi" {}

provider "newrelic" {
  account_id        = 11805670
  api_key           = "local-test-key"
  region            = "US"
  nerdgraph_api_url = "http://localhost:8084/graphql"
}

module "azure_cci" {
  source = "../"

  # New Relic
  newrelic_account_id = 11805670

  # CCI connection
  connection_name    = "sampleMCAConnection1"
  agreement_type     = "MCA"
  billing_account_id = "0c068c4e-6084-5b84-9b47-89a494054d95:e85ef6da-ccbd-4efa-99b0-60cdffe78d1e_2019-05-31"
  base_drop_path     = ""

  # Azure resources
  resource_group_name  = "newrelic-cci-rg"
  storage_account_name = "nrccibillingstorage"
  container_name       = "cci-billing-exports"
  export_name          = "newrelic-cci-focus-export"
}

output "storage_account_name" { value = module.azure_cci.storage_account_name }
output "container_name"       { value = module.azure_cci.container_name }
output "cci_status"           { value = module.azure_cci.cci_status }
output "cci_integration_id"   { value = module.azure_cci.cci_integration_id }
