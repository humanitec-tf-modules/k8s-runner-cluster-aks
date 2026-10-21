variable "runner_namespace" {
  description = "Name of the Kubernetes namespacefor the runner."
  type        = string
  nullable    = false
  default     = "humanitec-runner"
}
variable "runner_serviceaccount" {
  description = "Name of the Kubernetes service account for the runner."
  type        = string
  nullable    = false
  default     = "humanitec-runner"
}
variable "runner_serviceaccount_annotations" {
  description = "Annotations to add to the runner Kubernetes service account."
  type        = map(string)
  nullable    = false
  default     = {}

  validation {
    condition     = !contains(keys(var.runner_serviceaccount_annotations), "azure.workload.identity/client-id")
    error_message = "The azure.workload.identity/client-id annotation is managed by this module and cannot be set."
  }
}
variable "runner_role" {
  description = "Name of the Kubernetes role for the runner"
  type        = string
  nullable    = false
  default     = "humanitec-runner"
}
variable "support_kubernetes_tf_backend" {
  description = "Whether to support a `kubernetes` OpenTofu/Terraform backend for the runner. Setting this to `true` adds extended permissions to the role for the runner service account. If not required, leave it at `false` to maintain least privilege."
  type        = bool
  nullable    = false
  default     = false
}
variable "is_separate_runner_cluster" {
  description = "Whether the target cluster is a separate runner cluster, i.e. not on the same cluster as an Operator. Setting this to `true` results in an additional role created and bound to the runner service account for managing Kubernetes Jobs and related resources."
  type        = bool
  nullable    = false
  default     = false
}
variable "separate_runner_cluster_subjects" {
  description = "Subjects to bind to the additional role created if `is_separate_runner_cluster` is `true`. These are the identities accessing the separate runner cluster, which depend on the technology used for that kind of access. Required to contain at least one subject if `is_separate_runner_cluster` is `true`."
  type = list(object({
    kind      = string
    name      = string
    api_group = optional(string)
    namespace = optional(string)
  }))
  nullable = false
  default  = []

  validation {
    condition     = !var.is_separate_runner_cluster || length(var.separate_runner_cluster_subjects) > 0
    error_message = "separate_runner_cluster_subjects must contain at least one subject if is_separate_runner_cluster is true."
  }
}
variable "managed_identity_create" {
  type        = bool
  description = "Whether to create the Azure managed identity used by the runner. If `false`, `managed_identity_id` must be the resource ID of an existing managed identity."
  nullable    = false
  default     = true
}
variable "managed_identity_name" {
  description = "Name of the Azure managed identity to create for the runner. Only used if `managed_identity_create` is `true`. If not set, the module generates a name from `runner_namespace`, `runner_serviceaccount` and a random four-letter suffix, truncated to 120 characters so it can also be used as the federated identity credential name."
  type        = string
  nullable    = true
  default     = null

  validation {
    condition     = var.managed_identity_create || var.managed_identity_name == null
    error_message = "managed_identity_name must not be set if managed_identity_create is false. Use managed_identity_id to pass in an existing managed identity"
  }
}
variable "managed_identity_resource_group_name" {
  description = "Name of an existing Resource Group where to create the Managed Identity for the runner. Required if `managed_identity_create` is `true`, must not be set otherwise."
  type        = string
  nullable    = true
  default     = null

  validation {
    condition     = var.managed_identity_create ? var.managed_identity_resource_group_name != null : var.managed_identity_resource_group_name == null
    error_message = "managed_identity_resource_group_name must be set if managed_identity_create is true, and must not be set otherwise"
  }
}
variable "managed_identity_location" {
  type        = string
  description = "The Azure region to create the managed identity in, e.g. `westeurope`. If not set, the module uses the location of the resource group `managed_identity_resource_group_name`. Only used if `managed_identity_create` is `true`"
  nullable    = true
  default     = null

  validation {
    condition     = var.managed_identity_create || var.managed_identity_location == null
    error_message = "managed_identity_location must not be set if managed_identity_create is false"
  }
}
variable "managed_identity_tags" {
  type        = map(string)
  description = "Tags to assign to the managed identity created by the module. Only used if `managed_identity_create` is `true`"
  nullable    = true
  default     = null

  validation {
    condition     = var.managed_identity_create || var.managed_identity_tags == null
    error_message = "managed_identity_tags must not be set if managed_identity_create is false"
  }
}
variable "managed_identity_id" {
  type        = string
  description = "The resource ID of an existing user-assigned managed identity used via the Cloud Account. It must be located in the subscription of the `azurerm` provider that is passed in to the module. The module reads the identity to obtain its client ID and tenant ID. Required if `managed_identity_create` is `false`, must not be set otherwise"
  nullable    = true
  default     = null

  validation {
    condition     = var.managed_identity_create ? var.managed_identity_id == null : var.managed_identity_id != null
    error_message = "managed_identity_id must be set if managed_identity_create is false, and must not be set otherwise"
  }

  validation {
    condition     = var.managed_identity_id == null || can(regex(local.managed_identity_id_pattern, var.managed_identity_id))
    error_message = "managed_identity_id must be a managed identity resource ID like /subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/my-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/my-identity"
  }
}
variable "federated_identity_credential_create" {
  type        = bool
  description = "Whether to create the federated identity credential trusting the AKS OIDC provider on the managed identity. Set to `false` if you manage the credential yourself. Use the `federated_identity_credential` output to configure it"
  nullable    = false
  default     = true
}
variable "federated_identity_credential_name" {
  description = "Name of the federated identity credential for the runner Managed Identity. If not set, the name of the Managed Identity is used. Only used if `federated_identity_credential_create` is `true`."
  type        = string
  nullable    = true
  default     = null

  validation {
    condition     = var.federated_identity_credential_create || var.federated_identity_credential_name == null
    error_message = "federated_identity_credential_name must not be set if federated_identity_credential_create is false"
  }
}
variable "aks_oidc_issuer_url" {
  description = "The OIDC issuer URL of the AKS cluster hosting the runner. Required if `federated_identity_credential_create` is `true`. Optional otherwise, if set it is included in the `federated_identity_credential` output."
  type        = string
  nullable    = true
  default     = null

  validation {
    condition     = !var.federated_identity_credential_create || var.aks_oidc_issuer_url != null
    error_message = "aks_oidc_issuer_url must be set when federated_identity_credential_create is true"
  }
}
