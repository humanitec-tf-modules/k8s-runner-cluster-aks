# AKS Kubernetes runner cluster

> [!NOTE]
> 🚧 The content of this repository is currently being curated. Please wait for the first release to appear before using it.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 4.65.0, < 6.0.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~> 3 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_k8s_runner_cluster"></a> [k8s\_runner\_cluster](#module\_k8s\_runner\_cluster) | github.com/humanitec-tf-modules/k8s-runner-cluster | add-runner-cluster |

## Resources

| Name | Type |
|------|------|
| [azurerm_federated_identity_credential.runner_identity](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/federated_identity_credential) | resource |
| [azurerm_user_assigned_identity.runner_identity](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/user_assigned_identity) | resource |
| [random_string.managed_identity_suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [azurerm_client_config.current](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config) | data source |
| [azurerm_resource_group.runner_identity](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/resource_group) | data source |
| [azurerm_user_assigned_identity.runner_identity](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/user_assigned_identity) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aks_oidc_issuer_url"></a> [aks\_oidc\_issuer\_url](#input\_aks\_oidc\_issuer\_url) | The OIDC issuer URL of the AKS cluster hosting the runner. Required if `federated_identity_credential_create` is `true`. Optional otherwise, if set it is included in the `federated_identity_credential` output. | `string` | `null` | no |
| <a name="input_federated_identity_credential_create"></a> [federated\_identity\_credential\_create](#input\_federated\_identity\_credential\_create) | Whether to create the federated identity credential trusting the AKS OIDC provider on the managed identity. Set to `false` if you manage the credential yourself. Use the `federated_identity_credential` output to configure it | `bool` | `true` | no |
| <a name="input_federated_identity_credential_name"></a> [federated\_identity\_credential\_name](#input\_federated\_identity\_credential\_name) | Name of the federated identity credential for the runner Managed Identity. If not set, the name of the Managed Identity is used. Only used if `federated_identity_credential_create` is `true`. | `string` | `null` | no |
| <a name="input_is_separate_runner_cluster"></a> [is\_separate\_runner\_cluster](#input\_is\_separate\_runner\_cluster) | Whether the target cluster is a separate runner cluster, i.e. not on the same cluster as an Operator. Setting this to `true` results in an additional role created and bound to the runner service account for managing Kubernetes Jobs and related resources. | `bool` | `false` | no |
| <a name="input_managed_identity_create"></a> [managed\_identity\_create](#input\_managed\_identity\_create) | Whether to create the Azure managed identity used by the runner. If `false`, `managed_identity_id` must be the resource ID of an existing managed identity. | `bool` | `true` | no |
| <a name="input_managed_identity_id"></a> [managed\_identity\_id](#input\_managed\_identity\_id) | The resource ID of an existing user-assigned managed identity used via the Cloud Account. It must be located in the subscription of the `azurerm` provider that is passed in to the module. The module reads the identity to obtain its client ID and tenant ID. Required if `managed_identity_create` is `false`, must not be set otherwise | `string` | `null` | no |
| <a name="input_managed_identity_location"></a> [managed\_identity\_location](#input\_managed\_identity\_location) | The Azure region to create the managed identity in, e.g. `westeurope`. If not set, the module uses the location of the resource group `managed_identity_resource_group_name`. Only used if `managed_identity_create` is `true` | `string` | `null` | no |
| <a name="input_managed_identity_name"></a> [managed\_identity\_name](#input\_managed\_identity\_name) | Name of the Azure managed identity to create for the runner. Only used if `managed_identity_create` is `true`. If not set, the module generates a name from `runner_namespace`, `runner_serviceaccount` and a random four-letter suffix, truncated to 120 characters so it can also be used as the federated identity credential name. | `string` | `null` | no |
| <a name="input_managed_identity_resource_group_name"></a> [managed\_identity\_resource\_group\_name](#input\_managed\_identity\_resource\_group\_name) | Name of an existing Resource Group where to create the Managed Identity for the runner. Required if `managed_identity_create` is `true`, must not be set otherwise. | `string` | `null` | no |
| <a name="input_managed_identity_tags"></a> [managed\_identity\_tags](#input\_managed\_identity\_tags) | Tags to assign to the managed identity created by the module. Only used if `managed_identity_create` is `true` | `map(string)` | `null` | no |
| <a name="input_runner_namespace"></a> [runner\_namespace](#input\_runner\_namespace) | Name of the Kubernetes namespacefor the runner. | `string` | `"humanitec-runner"` | no |
| <a name="input_runner_role"></a> [runner\_role](#input\_runner\_role) | Name of the Kubernetes role for the runner | `string` | `"humanitec-runner"` | no |
| <a name="input_runner_serviceaccount"></a> [runner\_serviceaccount](#input\_runner\_serviceaccount) | Name of the Kubernetes service account for the runner. | `string` | `"humanitec-runner"` | no |
| <a name="input_runner_serviceaccount_annotations"></a> [runner\_serviceaccount\_annotations](#input\_runner\_serviceaccount\_annotations) | Annotations to add to the runner Kubernetes service account. | `map(string)` | `{}` | no |
| <a name="input_separate_runner_cluster_subjects"></a> [separate\_runner\_cluster\_subjects](#input\_separate\_runner\_cluster\_subjects) | Subjects to bind to the additional role created if `is_separate_runner_cluster` is `true`. These are the identities accessing the separate runner cluster, which depend on the technology used for that kind of access. Required to contain at least one subject if `is_separate_runner_cluster` is `true`. | <pre>list(object({<br/>    kind      = string<br/>    name      = string<br/>    api_group = optional(string)<br/>    namespace = optional(string)<br/>  }))</pre> | `[]` | no |
| <a name="input_support_kubernetes_tf_backend"></a> [support\_kubernetes\_tf\_backend](#input\_support\_kubernetes\_tf\_backend) | Whether to support a `kubernetes` OpenTofu/Terraform backend for the runner. Setting this to `true` adds extended permissions to the role for the runner service account. If not required, leave it at `false` to maintain least privilege. | `bool` | `false` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_azure_tenant_id"></a> [azure\_tenant\_id](#output\_azure\_tenant\_id) | ID of the Azure tenant of the managed identity |
| <a name="output_federated_identity_credential"></a> [federated\_identity\_credential](#output\_federated\_identity\_credential) | Issuer, subject, and audience of the federated identity credential allowing the Cloud Account to use the managed identity. If `federated_identity_credential_create` is `false`, configure a credential with these values on the managed identity yourself |
| <a name="output_federated_identity_credential_id"></a> [federated\_identity\_credential\_id](#output\_federated\_identity\_credential\_id) | Resource ID of the federated identity credential created by the module, or `null` if `federated_identity_credential_create` is `false` |
| <a name="output_managed_identity_client_id"></a> [managed\_identity\_client\_id](#output\_managed\_identity\_client\_id) | Client ID of the managed identity used by the runner |
| <a name="output_managed_identity_id"></a> [managed\_identity\_id](#output\_managed\_identity\_id) | Resource ID of the managed identity used by the runner |
| <a name="output_managed_identity_name"></a> [managed\_identity\_name](#output\_managed\_identity\_name) | Name of the managed identity used by the runner |
| <a name="output_managed_identity_object_id"></a> [managed\_identity\_object\_id](#output\_managed\_identity\_object\_id) | Object ID (principal ID) of the managed identity used by the runner, i.e. the object ID of its service principal in Microsoft Entra ID. Use it as the principal ID to assign Azure roles to the identity |
| <a name="output_runner_namespace"></a> [runner\_namespace](#output\_runner\_namespace) | Name of the Kubernetes namespace for the runner. |
| <a name="output_runner_role_name"></a> [runner\_role\_name](#output\_runner\_role\_name) | Name of the Kubernetes role for the runner. |
| <a name="output_runner_rolebinding_name"></a> [runner\_rolebinding\_name](#output\_runner\_rolebinding\_name) | Name of the Kubernetes rolebinding for the runner. |
| <a name="output_runner_serviceaccount_name"></a> [runner\_serviceaccount\_name](#output\_runner\_serviceaccount\_name) | Name of the Kubernetes service account for the runner. |
| <a name="output_separate_runner_cluster_role_name"></a> [separate\_runner\_cluster\_role\_name](#output\_separate\_runner\_cluster\_role\_name) | Name of the Kubernetes role created if `is_separate_runner_cluster` is `true`. Returns `null` otherwise. |
| <a name="output_separate_runner_cluster_rolebinding_name"></a> [separate\_runner\_cluster\_rolebinding\_name](#output\_separate\_runner\_cluster\_rolebinding\_name) | Name of the Kubernetes rolebinding created if `is_separate_runner_cluster` is `true`. Returns `null` otherwise. |
| <a name="output_separate_runner_cluster_rolebinding_subjects"></a> [separate\_runner\_cluster\_rolebinding\_subjects](#output\_separate\_runner\_cluster\_rolebinding\_subjects) | Subjects of the Kubernetes rolebinding created if `is_separate_runner_cluster` is `true`, including any attributes filled in by the provider. Returns `null` otherwise. |
<!-- END_TF_DOCS -->