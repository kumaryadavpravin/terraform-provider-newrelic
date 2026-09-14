variable "resource_group_name" {
  type        = string
  description = "Name of the Azure resource group for CCI billing resources."
}

variable "storage_account_name" {
  type        = string
  description = "Globally unique name for the Azure storage account (3-24 lowercase alphanumeric chars)."
}

variable "container_name" {
  type        = string
  description = "Name of the storage container for billing exports."
  default     = "cci-billing-exports"
}

variable "export_name" {
  type        = string
  description = "Name for the Azure Cost Management FOCUS billing export."
  default     = "newrelic-cci-focus-export"
}

variable "base_drop_path" {
  type        = string
  description = "Directory path within the container for billing exports. Leave empty if files are in the container root."
  default     = ""
}
