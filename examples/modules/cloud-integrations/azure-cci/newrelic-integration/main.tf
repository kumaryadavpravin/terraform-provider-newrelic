resource "newrelic_cloud_cci_azure_integration" "azure_cci" {
  account_id           = var.newrelic_account_id
  connection_name      = var.connection_name
  agreement_type       = var.agreement_type
  tenant_id            = var.tenant_id
  billing_account_id   = var.billing_account_id
  storage_account_name = var.storage_account_name
  container_name       = var.container_name
  base_drop_path       = var.base_drop_path
}

output "integration_id" {
  value       = newrelic_cloud_cci_azure_integration.azure_cci.integration_id
  description = "CCI Azure integration ID."
}

output "status" {
  value       = newrelic_cloud_cci_azure_integration.azure_cci.status
  description = "Validation status: NOT_EVALUATED, ACTIVE, or FAILED."
}

output "schedule_id" {
  value       = newrelic_cloud_cci_azure_integration.azure_cci.schedule_id
  description = "CCI internal schedule ID."
}
