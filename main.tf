data "azurerm_client_config" "current" {}

# Random suffix for the fallback Managed Identity name
resource "random_string" "managed_identity_suffix" {
  count   = var.managed_identity_create && var.managed_identity_name == null ? 1 : 0
  length  = 4
  upper   = false
  numeric = false
  special = false
}

locals {
  # Azure limits user-assigned identity names to 128 characters, but federated identity
  # credential names to 120. Use the lower limit so the generated identity name can
  # always be reused as the credential name.
  # Truncate the prefix so the "-" separator and the full random suffix always fit.
  # Service account names may contain ".", which Azure does not allow, so replace it with "-".
  managed_identity_name_max_length = 120
  managed_identity_name_prefix = substr(
    replace(join("-", [var.runner_namespace, var.runner_serviceaccount]), ".", "-"),
    0,
    local.managed_identity_name_max_length - 5
  )

  # Subscription, resource group, and name of an existing managed identity, parsed from its resource ID
  existing_identity_id_parts = var.managed_identity_id != null ? regex(local.managed_identity_id_pattern, var.managed_identity_id) : null

  # Determine the name of the managed identity: from the existing identity, the name passed in, or the constructed name
  managed_identity_name = (
    !var.managed_identity_create
    ? local.existing_identity_id_parts.name
    : var.managed_identity_name != null
    ? var.managed_identity_name
    : "${local.managed_identity_name_prefix}-${random_string.managed_identity_suffix[0].result}"
  )

  managed_identity_id        = var.managed_identity_create ? azurerm_user_assigned_identity.runner_identity[0].id : data.azurerm_user_assigned_identity.runner_identity[0].id
  managed_identity_client_id = var.managed_identity_create ? azurerm_user_assigned_identity.runner_identity[0].client_id : data.azurerm_user_assigned_identity.runner_identity[0].client_id
  managed_identity_object_id = var.managed_identity_create ? azurerm_user_assigned_identity.runner_identity[0].principal_id : data.azurerm_user_assigned_identity.runner_identity[0].principal_id
  managed_identity_tenant_id = var.managed_identity_create ? azurerm_user_assigned_identity.runner_identity[0].tenant_id : data.azurerm_user_assigned_identity.runner_identity[0].tenant_id

  federated_identity_credential_name = coalesce(var.federated_identity_credential_name, local.managed_identity_name)

  # Federated identity credential settings for the Humanitec OIDC provider
  federated_credential = {
    issuer   = var.aks_oidc_issuer_url
    subject  = "system:serviceaccount:${module.k8s_runner_cluster.runner_namespace}:${module.k8s_runner_cluster.runner_serviceaccount_name}"
    audience = ["api://AzureADTokenExchange"]
  }

  # Pattern for a managed identity resource ID, also used by the managed_identity_id validation
  managed_identity_id_pattern = "(?i)^/subscriptions/(?P<subscription_id>[^/]+)/resourceGroups/(?P<resource_group_name>[^/]+)/providers/Microsoft\\.ManagedIdentity/userAssignedIdentities/(?P<name>[^/]+)$"
}

# Identity and federated identity credential for the runner
resource "azurerm_user_assigned_identity" "runner_identity" {
  count               = var.managed_identity_create ? 1 : 0
  name                = local.managed_identity_name
  resource_group_name = var.managed_identity_resource_group_name
  location            = var.managed_identity_location != null ? var.managed_identity_location : data.azurerm_resource_group.runner_identity[0].location
  tags                = var.managed_identity_tags
}

# Resource group of the new managed identity. Read only if its location is needed as the default
data "azurerm_resource_group" "runner_identity" {
  count = var.managed_identity_create && var.managed_identity_location == null ? 1 : 0
  name  = var.managed_identity_resource_group_name
}

data "azurerm_user_assigned_identity" "runner_identity" {
  count               = var.managed_identity_create ? 0 : 1
  name                = local.existing_identity_id_parts.name
  resource_group_name = local.existing_identity_id_parts.resource_group_name

  lifecycle {
    precondition {
      condition     = lower(local.existing_identity_id_parts.subscription_id) == lower(data.azurerm_client_config.current.subscription_id)
      error_message = "managed_identity_id must be located in the subscription of the azurerm provider (${data.azurerm_client_config.current.subscription_id})."
    }
  }
}
resource "azurerm_federated_identity_credential" "runner_identity" {
  count                     = var.federated_identity_credential_create ? 1 : 0
  name                      = local.federated_identity_credential_name
  user_assigned_identity_id = local.managed_identity_id
  issuer                    = local.federated_credential.issuer
  subject                   = local.federated_credential.subject
  audience                  = local.federated_credential.audience
}

# Provision the core Kubernetes setup using the generic module
module "k8s_runner_cluster" {
  # ❌❌ TODO: use tag once available
  source = "github.com/humanitec-tf-modules/k8s-runner-cluster?ref=add-runner-cluster"
  providers = {
    kubernetes = kubernetes
  }

  # Pass through all core variables
  runner_namespace              = var.runner_namespace
  runner_serviceaccount         = var.runner_serviceaccount
  runner_role                   = var.runner_role
  support_kubernetes_tf_backend = var.support_kubernetes_tf_backend
  is_separate_runner_cluster    = var.is_separate_runner_cluster
  # Annotate the driver service account for Workload Identity and also add any annotations passed in
  runner_serviceaccount_annotations = merge(
    var.runner_serviceaccount_annotations,
    { "azure.workload.identity/client-id" = local.managed_identity_client_id }
  )
}
