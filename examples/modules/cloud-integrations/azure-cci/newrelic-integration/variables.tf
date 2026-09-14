# ── New Relic provider ─────────────────────────────────────────────────────

variable "newrelic_account_id" {
  type        = number
  description = "The New Relic account ID."
}

variable "newrelic_api_key" {
  type        = string
  sensitive   = true
  description = "New Relic User API key."
}

variable "newrelic_region" {
  type        = string
  description = "New Relic region: US, EU, or STAGING."
  default     = "US"
}

# ── CCI integration inputs ─────────────────────────────────────────────────
# These come from azure-infra outputs (or entered manually if using existing Azure resources)

variable "connection_name" {
  type        = string
  description = "Unique connection name for the CCI Azure integration."
}

variable "agreement_type" {
  type        = string
  description = "Azure agreement type: 'Enterprise Agreement' or 'Microsoft Customer Agreement'."
  default     = "Enterprise Agreement"
}

variable "tenant_id" {
  type        = string
  sensitive   = true
  description = "Azure tenant ID. Copy from azure-infra output: tenant_id."
}

variable "billing_account_id" {
  type        = string
  description = "Azure billing account ID (EA/MCA). Optional."
  default     = ""
}

variable "storage_account_name" {
  type        = string
  description = "Azure storage account name. Copy from azure-infra output: storage_account_name."
}

variable "container_name" {
  type        = string
  description = "Azure storage container name. Copy from azure-infra output: container_name."
}

variable "base_drop_path" {
  type        = string
  description = "Directory path within the container for billing exports. Leave empty if files are in the container root."
  default     = ""
}
