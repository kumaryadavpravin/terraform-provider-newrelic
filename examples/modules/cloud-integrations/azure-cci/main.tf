data "azurerm_subscription" "current" {}

locals {
  export_parent_id = var.export_scope == "BillingAccount" ? "/providers/Microsoft.Billing/billingAccounts/${var.billing_account_id}" : data.azurerm_subscription.current.id
}

# ── Step 1: Resource group ─────────────────────────────────────────────────

resource "azurerm_resource_group" "cci" {
  name     = var.resource_group_name
  location = "East US"

  lifecycle {
    prevent_destroy = true
  }
}

# ── Step 2: Storage account ────────────────────────────────────────────────
# East US is recommended to reduce outbound data transfer costs.
# Storage type must be Azure Blob storage.

resource "azurerm_storage_account" "cci" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.cci.name
  location                 = "East US"
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"

  lifecycle {
    prevent_destroy = true
  }
}

# ── Step 3: Storage container ──────────────────────────────────────────────

resource "azurerm_storage_container" "cci" {
  name                  = var.container_name
  storage_account_name  = azurerm_storage_account.cci.name
  container_access_type = "private"

  lifecycle {
    prevent_destroy = true
  }
}

# ── Step 4: New Relic service principal ───────────────────────────────────
# Creates the msazurecostdata service principal in the customer's tenant if it
# does not already exist. Replaces the manual OAuth consent flow in the NR UI.

resource "azuread_service_principal" "msazurecostdata" {
  client_id    = var.newrelic_azure_app_id
  use_existing = true
}

# ── Step 5: Grant read-only access to the billing container ────────────────
# Assigns Storage Blob Data Reader at container scope (least privilege).

resource "azurerm_role_assignment" "cci_nr_reader" {
  scope                = azurerm_storage_container.cci.resource_manager_id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azuread_service_principal.msazurecostdata.object_id

  depends_on = [azurerm_storage_container.cci]
}

# ── Step 7: FOCUS billing export ───────────────────────────────────────────
# Uses azapi because azurerm does not support FOCUS format (1.2-preview) yet.
#
# Parameters:
#   Type of Data  : Cost and Usage details (FOCUS) - Preview
#   Dataset Ver.  : 1.2-preview
#   Frequency     : Daily (month-to-date)
#   Compression   : Parquet
#   Data Overwrite: Yes
#   Partitioning  : Yes

resource "azapi_resource" "cci_billing_export" {
  type      = "Microsoft.CostManagement/exports@2023-11-01"
  name      = var.export_name
  parent_id = local.export_parent_id

  body = jsonencode({
    properties = {
      schedule = {
        status     = "Active"
        recurrence = "Daily"
        recurrencePeriod = {
          from = "2024-01-01T00:00:00Z"
          to   = "2099-12-31T00:00:00Z"
        }
      }
      format                = "Parquet"
      partitionData         = true
      dataOverwriteBehavior = "OverwritePreviousReport"
      deliveryInfo = {
        destination = {
          resourceId     = azurerm_storage_account.cci.id
          container      = azurerm_storage_container.cci.name
          rootFolderPath = var.base_drop_path
        }
      }
      definition = {
        type      = "FocusCost"
        timeframe = "MonthToDate"
        dataSet = {
          granularity   = "Daily"
          configuration = {
            dataVersion = "1.2-preview"
          }
        }
      }
    }
  })

  depends_on = [azurerm_storage_container.cci]

  lifecycle {
    prevent_destroy = true
  }
}

# ── Step 8: New Relic CCI Azure integration ────────────────────────────────
# If this step fails, re-run `terraform apply` — Azure resources above are
# already in state and will not be recreated. Only this resource is retried.

resource "newrelic_cloud_cci_azure_integration" "azure_cci" {
  account_id           = var.newrelic_account_id
  connection_name      = var.connection_name
  agreement_type       = var.agreement_type
  tenant_id            = data.azurerm_subscription.current.tenant_id
  billing_account_id   = var.billing_account_id
  storage_account_name = azurerm_storage_account.cci.name
  container_name       = azurerm_storage_container.cci.name
  base_drop_path       = var.base_drop_path

  depends_on = [
    azapi_resource.cci_billing_export,
    azurerm_role_assignment.cci_nr_reader,
  ]
}

# ── Outputs ────────────────────────────────────────────────────────────────

output "storage_account_name" {
  value       = azurerm_storage_account.cci.name
  description = "Azure storage account name created for CCI billing exports."
}

output "container_name" {
  value       = azurerm_storage_container.cci.name
  description = "Azure storage container name for billing exports."
}

output "cci_integration_id" {
  value       = newrelic_cloud_cci_azure_integration.azure_cci.integration_id
  description = "CCI Azure integration ID."
}

output "cci_status" {
  value       = newrelic_cloud_cci_azure_integration.azure_cci.status
  description = "Validation status: NOT_EVALUATED, ACTIVE, or FAILED."
}

output "cci_schedule_id" {
  value       = newrelic_cloud_cci_azure_integration.azure_cci.schedule_id
  description = "CCI internal schedule ID."
}
