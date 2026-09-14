# ── New Relic ──────────────────────────────────────────────────────────────

variable "newrelic_account_id" {
  type        = number
  description = "The New Relic account ID."
}

# ── CCI connection ─────────────────────────────────────────────────────────

variable "connection_name" {
  type        = string
  description = "Unique connection name for the CCI Azure integration."
}

variable "agreement_type" {
  type        = string
  description = "Azure agreement type: 'Enterprise Agreement' or 'Microsoft Customer Agreement'."
  default     = "Enterprise Agreement"
}

variable "billing_account_id" {
  type        = string
  description = "Azure billing account ID (EA/MCA). Required when export_scope is 'BillingAccount'."
  default     = ""
}

variable "export_scope" {
  type        = string
  description = "Scope for the FOCUS billing export. 'BillingAccount' uses billing_account_id as scope; 'Subscription' uses the current subscription."
  default     = "BillingAccount"

  validation {
    condition     = contains(["BillingAccount", "Subscription"], var.export_scope)
    error_message = "export_scope must be either 'BillingAccount' or 'Subscription'."
  }
}

variable "base_drop_path" {
  type        = string
  description = "Directory path within the container for billing exports. Leave empty if files are in the container root."
  default     = ""
}

# ── New Relic service principal ────────────────────────────────────────────

variable "newrelic_azure_app_id" {
  type        = string
  description = "New Relic's msazurecostdata Azure application (client) ID. Environment-specific: differs for staging, US, and EU. Must be explicitly set per environment."
}

# ── Azure resources ────────────────────────────────────────────────────────

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
