data "azurerm_subscription" "current" {}

# ── Resource group (East US — reduces outbound data transfer costs) ────────

resource "azurerm_resource_group" "cci" {
  name     = var.resource_group_name
  location = "East US"
}

# ── Storage account ────────────────────────────────────────────────────────
# Requirements: Azure Blob storage, East US, Standard LRS

resource "azurerm_storage_account" "cci" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.cci.name
  location                 = "East US"
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
}

# ── Storage container ──────────────────────────────────────────────────────

resource "azurerm_storage_container" "cci" {
  name                  = var.container_name
  storage_account_name  = azurerm_storage_account.cci.name
  container_access_type = "private"
}

# ── FOCUS billing export ───────────────────────────────────────────────────
# Uses azapi because azurerm_subscription_cost_management_export does not
# support FOCUS format (FocusCost / 1.2-preview) yet.
#
# Parameters per setup requirements:
#   Type of Data  : Cost and Usage details (FOCUS) - Preview
#   Dataset Ver.  : 1.2-preview
#   Frequency     : Daily (month-to-date)
#   Compression   : Parquet
#   Data Overwrite: Yes (OverwritePreviousReport)
#   Partitioning  : Yes

resource "azapi_resource" "cci_billing_export" {
  type      = "Microsoft.CostManagement/exports@2023-11-01"
  name      = var.export_name
  parent_id = data.azurerm_subscription.current.id

  body = jsonencode({
    properties = {
      schedule = {
        status    = "Active"
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
}
