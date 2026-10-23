output "runner_namespace" {
  description = "Name of the Kubernetes namespace for the runner."
  value       = module.k8s_runner_cluster.runner_namespace
}
output "runner_serviceaccount_name" {
  description = "Name of the Kubernetes service account for the runner."
  value       = module.k8s_runner_cluster.runner_serviceaccount_name
}
output "runner_role_name" {
  description = "Name of the Kubernetes role for the runner."
  value       = module.k8s_runner_cluster.runner_role_name
}
output "runner_rolebinding_name" {
  description = "Name of the Kubernetes rolebinding for the runner."
  value       = module.k8s_runner_cluster.runner_rolebinding_name
}
output "separate_runner_cluster_role_name" {
  description = "Name of the Kubernetes role created if `is_separate_runner_cluster` is `true`. Returns `null` otherwise."
  value       = module.k8s_runner_cluster.separate_runner_cluster_role_name
}
output "separate_runner_cluster_rolebinding_name" {
  description = "Name of the Kubernetes rolebinding created if `is_separate_runner_cluster` is `true`. Returns `null` otherwise."
  value       = module.k8s_runner_cluster.separate_runner_cluster_rolebinding_name
}
output "separate_runner_cluster_rolebinding_subjects" {
  description = "Subjects of the Kubernetes rolebinding created if `is_separate_runner_cluster` is `true`, including any attributes filled in by the provider. Returns `null` otherwise."
  value       = module.k8s_runner_cluster.separate_runner_cluster_rolebinding_subjects
}
output "managed_identity_id" {
  value       = local.managed_identity_id
  description = "Resource ID of the managed identity used by the runner"
}
output "managed_identity_name" {
  # Read the name from the identity rather than local.managed_identity_name so callers depend on the identity existing
  value       = var.managed_identity_create ? azurerm_user_assigned_identity.runner_identity[0].name : data.azurerm_user_assigned_identity.runner_identity[0].name
  description = "Name of the managed identity used by the runner"
}
output "managed_identity_client_id" {
  value       = local.managed_identity_client_id
  description = "Client ID of the managed identity used by the runner"
}
output "managed_identity_object_id" {
  value       = local.managed_identity_object_id
  description = "Object ID (principal ID) of the managed identity used by the runner, i.e. the object ID of its service principal in Microsoft Entra ID. Use it as the principal ID to assign Azure roles to the identity"
}
output "azure_tenant_id" {
  value       = local.managed_identity_tenant_id
  description = "ID of the Azure tenant of the managed identity"
}
output "federated_identity_credential_id" {
  value       = one(azurerm_federated_identity_credential.runner_identity[*].id)
  description = "Resource ID of the federated identity credential created by the module, or `null` if `federated_identity_credential_create` is `false`"
}
output "federated_identity_credential" {
  value       = local.federated_credential
  description = "Issuer, subject, and audience of the federated identity credential allowing the Cloud Account to use the managed identity. If `federated_identity_credential_create` is `false`, configure a credential with these values on the managed identity yourself"
}
