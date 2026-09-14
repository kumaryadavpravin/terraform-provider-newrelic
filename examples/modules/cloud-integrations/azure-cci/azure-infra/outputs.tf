output "storage_account_name" {
  value       = azurerm_storage_account.cci.name
  description = "Azure storage account name — pass to newrelic-integration as storage_account_name."
}

output "container_name" {
  value       = azurerm_storage_container.cci.name
  description = "Azure storage container name — pass to newrelic-integration as container_name."
}

output "export_name" {
  value       = azapi_resource.cci_billing_export.name
  description = "Azure Cost Management FOCUS export name."
}

output "tenant_id" {
  value       = data.azurerm_subscription.current.tenant_id
  description = "Azure tenant ID — pass to newrelic-integration as tenant_id."
}

output "subscription_id" {
  value       = data.azurerm_subscription.current.subscription_id
  description = "Azure subscription ID."
}
