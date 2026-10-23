# Mock all providers so the tests run without access to Azure or a Kubernetes cluster
mock_provider "kubernetes" {}
mock_provider "random" {
  # The mocked result does not honor the length attribute
  mock_resource "random_string" {
    defaults = {
      result = "abcd"
    }
  }
}
mock_provider "azurerm" {
  # Contains letters so the tests can check the case-insensitive subscription comparison
  mock_data "azurerm_client_config" {
    defaults = {
      subscription_id = "aaaaaaaa-0000-0000-0000-000000000000"
    }
  }
  mock_data "azurerm_resource_group" {
    defaults = {
      location = "westeurope"
    }
  }
  # The federated identity credential validates the format of the identity ID
  mock_resource "azurerm_user_assigned_identity" {
    defaults = {
      id           = "/subscriptions/aaaaaaaa-0000-0000-0000-000000000000/resourceGroups/my-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/created-identity"
      client_id    = "11111111-1111-1111-1111-111111111111"
      principal_id = "11111111-0000-0000-0000-000000000000"
      tenant_id    = "tttttttt-0000-0000-0000-000000000000"
    }
  }
  mock_data "azurerm_user_assigned_identity" {
    defaults = {
      id           = "/subscriptions/aaaaaaaa-0000-0000-0000-000000000000/resourceGroups/existing-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/existing-identity"
      client_id    = "22222222-2222-2222-2222-222222222222"
      principal_id = "22222222-0000-0000-0000-000000000000"
      tenant_id    = "tttttttt-0000-0000-0000-000000000000"
    }
  }
}

# The minimum set of variables. Runs using an existing Managed Identity reset managed_identity_resource_group_name to null
variables {
  aks_oidc_issuer_url                  = "https://oidc.example.com/"
  managed_identity_resource_group_name = "my-rg"
}

# Default case

run "defaults" {
  # The random suffix of the generated name is only known after apply
  command = apply

  # Managed Identity
  assert {
    condition     = length(azurerm_user_assigned_identity.runner_identity) == 1
    error_message = "Managed Identity should be created by default"
  }
  assert {
    condition     = length(data.azurerm_user_assigned_identity.runner_identity) == 0
    error_message = "No existing Managed Identity should be read by default"
  }
  assert {
    condition     = azurerm_user_assigned_identity.runner_identity[0].name == "humanitec-runner-humanitec-runner-abcd"
    error_message = "Managed Identity name should be generated as <namespace>-<serviceaccount>-<suffix>, got ${azurerm_user_assigned_identity.runner_identity[0].name}"
  }
  assert {
    condition     = azurerm_user_assigned_identity.runner_identity[0].resource_group_name == "my-rg"
    error_message = "Managed Identity should be created in managed_identity_resource_group_name"
  }
  assert {
    condition     = length(data.azurerm_resource_group.runner_identity) == 1 && azurerm_user_assigned_identity.runner_identity[0].location == "westeurope"
    error_message = "Managed Identity location should default to the location of its resource group"
  }
  assert {
    condition     = azurerm_user_assigned_identity.runner_identity[0].tags == null
    error_message = "Managed Identity should have no tags by default"
  }

  # Federated identity credential
  assert {
    condition     = length(azurerm_federated_identity_credential.runner_identity) == 1
    error_message = "Federated identity credential should be created by default"
  }
  assert {
    condition     = azurerm_federated_identity_credential.runner_identity[0].name == azurerm_user_assigned_identity.runner_identity[0].name
    error_message = "Federated identity credential name should default to the Managed Identity name"
  }
  assert {
    condition     = azurerm_federated_identity_credential.runner_identity[0].user_assigned_identity_id == azurerm_user_assigned_identity.runner_identity[0].id
    error_message = "Federated identity credential should be created on the new Managed Identity"
  }
  assert {
    condition     = azurerm_federated_identity_credential.runner_identity[0].issuer == "https://oidc.example.com/"
    error_message = "Federated identity credential should trust aks_oidc_issuer_url"
  }
  assert {
    condition     = azurerm_federated_identity_credential.runner_identity[0].audience == tolist(["api://AzureADTokenExchange"])
    error_message = "Federated identity credential should use the Azure AD token exchange audience"
  }
  assert {
    condition     = azurerm_federated_identity_credential.runner_identity[0].subject == "system:serviceaccount:humanitec-runner:humanitec-runner"
    error_message = "Federated identity credential subject should be the runner service account, got ${azurerm_federated_identity_credential.runner_identity[0].subject}"
  }

  # Outputs
  assert {
    condition = (
      output.runner_namespace == "humanitec-runner" &&
      output.runner_serviceaccount_name == "humanitec-runner" &&
      output.runner_role_name == "humanitec-runner" &&
      output.runner_rolebinding_name == "humanitec-runner"
    )
    error_message = "Kubernetes namespace, service account, role and rolebinding outputs should use the default names"
  }
  assert {
    condition = (
      output.separate_runner_cluster_role_name == null &&
      output.separate_runner_cluster_rolebinding_name == null &&
      output.separate_runner_cluster_rolebinding_subjects == null
    )
    error_message = "Separate runner cluster role, rolebinding and subjects outputs should be null by default"
  }
  assert {
    condition = (
      output.managed_identity_id == azurerm_user_assigned_identity.runner_identity[0].id &&
      output.managed_identity_name == "humanitec-runner-humanitec-runner-abcd"
    )
    error_message = "Managed Identity ID and name outputs should be those of the new Managed Identity"
  }
  assert {
    condition     = output.managed_identity_client_id == "11111111-1111-1111-1111-111111111111"
    error_message = "Managed Identity client ID output should be that of the new Managed Identity"
  }
  assert {
    condition     = module.k8s_runner_cluster.runner_serviceaccount_annotations == tomap({ "azure.workload.identity/client-id" = "11111111-1111-1111-1111-111111111111" })
    error_message = "Runner service account should only be annotated with the client ID of the new Managed Identity"
  }
  assert {
    condition     = output.managed_identity_object_id == "11111111-0000-0000-0000-000000000000"
    error_message = "Managed Identity object ID output should be the principal ID of the new Managed Identity"
  }
  assert {
    condition     = output.azure_tenant_id == "tttttttt-0000-0000-0000-000000000000"
    error_message = "Azure tenant ID output should be the tenant of the new Managed Identity"
  }
  assert {
    condition     = output.federated_identity_credential_id == azurerm_federated_identity_credential.runner_identity[0].id
    error_message = "Federated identity credential ID output should be the ID of the created credential"
  }
  assert {
    condition = (
      output.federated_identity_credential.issuer == "https://oidc.example.com/" &&
      output.federated_identity_credential.subject == "system:serviceaccount:humanitec-runner:humanitec-runner" &&
      tolist(output.federated_identity_credential.audience) == tolist(["api://AzureADTokenExchange"])
    )
    error_message = "Federated identity credential output should contain the issuer, subject and audience of the runner"
  }
  assert {
    condition = (
      output.federated_identity_credential.issuer == azurerm_federated_identity_credential.runner_identity[0].issuer &&
      output.federated_identity_credential.subject == azurerm_federated_identity_credential.runner_identity[0].subject &&
      tolist(output.federated_identity_credential.audience) == azurerm_federated_identity_credential.runner_identity[0].audience
    )
    error_message = "Federated identity credential output should match the created credential"
  }
}

# Complete cases

run "complete_create_identity" {
  command = apply

  variables {
    runner_namespace                  = "platform-runner"
    runner_serviceaccount             = "runner-sa"
    runner_serviceaccount_annotations = { "example.com/team" = "platform" }
    runner_role                       = "runner-role"
    support_kubernetes_tf_backend     = true
    is_separate_runner_cluster        = true
    separate_runner_cluster_subjects = [
      {
        kind      = "ServiceAccount"
        name      = "my-serviceaccount"
        namespace = "my-namespace"
      },
      {
        kind      = "Group"
        name      = "my-group"
        api_group = "rbac.authorization.k8s.io"
      },
      {
        kind = "User"
        name = "my-user"
      },
    ]
    managed_identity_create              = true
    managed_identity_name                = "my-identity"
    managed_identity_resource_group_name = "my-rg"
    managed_identity_location            = "northeurope"
    managed_identity_tags                = { env = "test" }
    federated_identity_credential_create = true
    federated_identity_credential_name   = "my-credential"
    aks_oidc_issuer_url                  = "https://oidc.example.com/"
  }

  # Managed Identity
  assert {
    condition     = length(random_string.managed_identity_suffix) == 0
    error_message = "No random suffix should be generated for a custom Managed Identity name"
  }
  assert {
    condition     = azurerm_user_assigned_identity.runner_identity[0].name == "my-identity"
    error_message = "Managed Identity should use managed_identity_name"
  }
  assert {
    condition     = azurerm_user_assigned_identity.runner_identity[0].location == "northeurope"
    error_message = "Managed Identity should use managed_identity_location"
  }
  assert {
    condition     = length(data.azurerm_resource_group.runner_identity) == 0
    error_message = "Resource group should not be read if managed_identity_location is set"
  }
  assert {
    condition     = azurerm_user_assigned_identity.runner_identity[0].tags == tomap({ env = "test" })
    error_message = "Managed Identity should use managed_identity_tags"
  }

  # Federated identity credential
  assert {
    condition     = azurerm_federated_identity_credential.runner_identity[0].name == "my-credential"
    error_message = "Federated identity credential should use federated_identity_credential_name"
  }
  assert {
    condition     = azurerm_federated_identity_credential.runner_identity[0].subject == "system:serviceaccount:platform-runner:runner-sa"
    error_message = "Federated identity credential subject should use the custom namespace and service account, got ${azurerm_federated_identity_credential.runner_identity[0].subject}"
  }

  # Outputs
  assert {
    condition = (
      output.runner_namespace == "platform-runner" &&
      output.runner_serviceaccount_name == "runner-sa" &&
      output.runner_role_name == "runner-role" &&
      output.runner_rolebinding_name == "runner-role"
    )
    error_message = "Kubernetes namespace, service account, role and rolebinding outputs should use the custom names"
  }
  assert {
    condition     = output.separate_runner_cluster_role_name == "runner-role-separate-cluster" && output.separate_runner_cluster_rolebinding_name == "runner-role-separate-cluster"
    error_message = "Separate runner cluster role and rolebinding should be created if is_separate_runner_cluster is true"
  }
  assert {
    condition = [for s in output.separate_runner_cluster_rolebinding_subjects : { kind = s.kind, name = s.name }] == [
      { kind = "ServiceAccount", name = "my-serviceaccount" },
      { kind = "Group", name = "my-group" },
      { kind = "User", name = "my-user" },
    ]
    error_message = "Separate runner cluster rolebinding should bind exactly the separate_runner_cluster_subjects, in order"
  }
  assert {
    condition     = output.separate_runner_cluster_rolebinding_subjects[0].namespace == "my-namespace"
    error_message = "Separate runner cluster rolebinding should pass on the namespace of a subject"
  }
  assert {
    condition     = output.separate_runner_cluster_rolebinding_subjects[1].api_group == "rbac.authorization.k8s.io"
    error_message = "Separate runner cluster rolebinding should pass on the api_group of a subject"
  }
  assert {
    condition     = output.managed_identity_name == "my-identity"
    error_message = "Managed Identity name output should be managed_identity_name"
  }
  assert {
    condition = module.k8s_runner_cluster.runner_serviceaccount_annotations == tomap({
      "example.com/team"                  = "platform"
      "azure.workload.identity/client-id" = "11111111-1111-1111-1111-111111111111"
    })
    error_message = "Runner service account should keep runner_serviceaccount_annotations and add the Managed Identity client ID"
  }
  assert {
    condition     = output.federated_identity_credential.subject == "system:serviceaccount:platform-runner:runner-sa"
    error_message = "Federated identity credential output subject should use the custom namespace and service account, got ${output.federated_identity_credential.subject}"
  }
}

run "complete_existing_identity" {
  command = apply

  variables {
    managed_identity_create              = false
    managed_identity_id                  = "/subscriptions/aaaaaaaa-0000-0000-0000-000000000000/resourceGroups/existing-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/existing-identity"
    managed_identity_resource_group_name = null
    federated_identity_credential_name   = "my-credential"
  }

  # Managed Identity
  assert {
    condition     = length(azurerm_user_assigned_identity.runner_identity) == 0
    error_message = "Managed Identity should not be created if managed_identity_create is false"
  }
  assert {
    condition     = length(random_string.managed_identity_suffix) == 0 && length(data.azurerm_resource_group.runner_identity) == 0
    error_message = "No random suffix should be generated and no resource group read for an existing Managed Identity"
  }
  assert {
    condition = (
      data.azurerm_user_assigned_identity.runner_identity[0].name == "existing-identity" &&
      data.azurerm_user_assigned_identity.runner_identity[0].resource_group_name == "existing-rg"
    )
    error_message = "Existing Managed Identity should be read by the name and resource group in managed_identity_id"
  }

  # Federated identity credential
  assert {
    condition     = azurerm_federated_identity_credential.runner_identity[0].user_assigned_identity_id == var.managed_identity_id
    error_message = "Federated identity credential should be created on the existing Managed Identity"
  }
  assert {
    condition     = azurerm_federated_identity_credential.runner_identity[0].name == "my-credential"
    error_message = "Federated identity credential should use federated_identity_credential_name"
  }

  # Outputs
  assert {
    condition = (
      output.managed_identity_id == var.managed_identity_id &&
      output.managed_identity_name == "existing-identity"
    )
    error_message = "Managed Identity ID and name outputs should be those of the existing Managed Identity"
  }
  assert {
    condition     = output.managed_identity_client_id == "22222222-2222-2222-2222-222222222222"
    error_message = "Managed Identity client ID output should be that of the existing Managed Identity"
  }
  assert {
    condition     = module.k8s_runner_cluster.runner_serviceaccount_annotations == tomap({ "azure.workload.identity/client-id" = "22222222-2222-2222-2222-222222222222" })
    error_message = "Runner service account should be annotated with the client ID of the existing Managed Identity"
  }
  assert {
    condition     = output.managed_identity_object_id == "22222222-0000-0000-0000-000000000000"
    error_message = "Managed Identity object ID output should be the principal ID of the existing Managed Identity"
  }
  assert {
    condition     = output.azure_tenant_id == "tttttttt-0000-0000-0000-000000000000"
    error_message = "Azure tenant ID output should be the tenant of the existing Managed Identity"
  }
  assert {
    condition     = output.federated_identity_credential_id == azurerm_federated_identity_credential.runner_identity[0].id
    error_message = "Federated identity credential ID output should be the ID of the created credential"
  }
}

# Edge cases

run "generated_name_is_truncated_and_sanitized" {
  command = apply

  variables {
    runner_namespace      = join("", [for i in range(63) : "n"])
    runner_serviceaccount = "s.${join("", [for i in range(98) : "s"])}"
  }

  assert {
    condition     = length(azurerm_user_assigned_identity.runner_identity[0].name) == 120
    error_message = "Generated Managed Identity name should be truncated to 120 characters, got ${length(azurerm_user_assigned_identity.runner_identity[0].name)}"
  }
  assert {
    condition     = azurerm_user_assigned_identity.runner_identity[0].name == "${join("", [for i in range(63) : "n"])}-s-${join("", [for i in range(49) : "s"])}-abcd"
    error_message = "Generated Managed Identity name should replace dots and keep the full random suffix, got ${azurerm_user_assigned_identity.runner_identity[0].name}"
  }
  assert {
    condition     = azurerm_federated_identity_credential.runner_identity[0].name == azurerm_user_assigned_identity.runner_identity[0].name
    error_message = "Federated identity credential name should default to the truncated Managed Identity name"
  }
}

run "custom_identity_name_is_credential_name" {
  command = apply

  variables {
    managed_identity_name = "my-identity"
  }

  assert {
    condition     = azurerm_federated_identity_credential.runner_identity[0].name == "my-identity"
    error_message = "Federated identity credential name should default to managed_identity_name"
  }
}

run "existing_identity_name_is_credential_name" {
  command = apply

  variables {
    managed_identity_create              = false
    managed_identity_id                  = "/subscriptions/aaaaaaaa-0000-0000-0000-000000000000/resourceGroups/existing-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/existing-identity"
    managed_identity_resource_group_name = null
  }

  assert {
    condition     = azurerm_federated_identity_credential.runner_identity[0].name == "existing-identity"
    error_message = "Federated identity credential name should default to the name of the existing Managed Identity"
  }
}

run "existing_identity_id_is_case_insensitive" {
  command = apply

  variables {
    managed_identity_create              = false
    managed_identity_id                  = "/SUBSCRIPTIONS/AAAAAAAA-0000-0000-0000-000000000000/RESOURCEGROUPS/existing-rg/PROVIDERS/MICROSOFT.MANAGEDIDENTITY/USERASSIGNEDIDENTITIES/existing-identity"
    managed_identity_resource_group_name = null
  }

  assert {
    condition = (
      data.azurerm_user_assigned_identity.runner_identity[0].name == "existing-identity" &&
      data.azurerm_user_assigned_identity.runner_identity[0].resource_group_name == "existing-rg"
    )
    error_message = "Existing Managed Identity should be read from an upper-case managed_identity_id"
  }
}

run "create_identity_without_credential" {
  command = apply

  # aks_oidc_issuer_url is still set from the file-level variables
  variables {
    federated_identity_credential_create = false
  }

  assert {
    condition     = length(azurerm_user_assigned_identity.runner_identity) == 1
    error_message = "Managed Identity should be created"
  }
  assert {
    condition     = length(azurerm_federated_identity_credential.runner_identity) == 0
    error_message = "Federated identity credential should not be created if federated_identity_credential_create is false"
  }
  assert {
    condition     = output.federated_identity_credential_id == null
    error_message = "Federated identity credential ID output should be null if no credential is created"
  }
  assert {
    condition     = output.managed_identity_client_id == "11111111-1111-1111-1111-111111111111"
    error_message = "Managed Identity client ID output should be set without a federated identity credential"
  }
  assert {
    condition = (
      output.federated_identity_credential.issuer == "https://oidc.example.com/" &&
      output.federated_identity_credential.subject == "system:serviceaccount:humanitec-runner:humanitec-runner" &&
      tolist(output.federated_identity_credential.audience) == tolist(["api://AzureADTokenExchange"])
    )
    error_message = "Federated identity credential output should provide the issuer, subject and audience to configure a credential yourself"
  }
}

run "existing_identity_without_credential" {
  command = apply

  variables {
    managed_identity_create              = false
    managed_identity_id                  = "/subscriptions/aaaaaaaa-0000-0000-0000-000000000000/resourceGroups/existing-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/existing-identity"
    managed_identity_resource_group_name = null
    federated_identity_credential_create = false
    aks_oidc_issuer_url                  = null
  }

  assert {
    condition     = length(azurerm_user_assigned_identity.runner_identity) == 0 && length(azurerm_federated_identity_credential.runner_identity) == 0
    error_message = "Neither a Managed Identity nor a federated identity credential should be created"
  }
  assert {
    condition     = output.federated_identity_credential_id == null
    error_message = "Federated identity credential ID output should be null if no credential is created"
  }
  assert {
    condition     = output.managed_identity_client_id == "22222222-2222-2222-2222-222222222222"
    error_message = "Managed Identity client ID output should be that of the existing Managed Identity"
  }
  assert {
    condition = (
      output.federated_identity_credential.issuer == null &&
      output.federated_identity_credential.subject == "system:serviceaccount:humanitec-runner:humanitec-runner" &&
      tolist(output.federated_identity_credential.audience) == tolist(["api://AzureADTokenExchange"])
    )
    error_message = "Federated identity credential output should provide the subject and audience, and no issuer if aks_oidc_issuer_url is not set"
  }
}

# Validation failures

run "rejects_client_id_annotation" {
  command = plan

  variables {
    runner_serviceaccount_annotations = { "azure.workload.identity/client-id" = "33333333-3333-3333-3333-333333333333" }
  }

  expect_failures = [var.runner_serviceaccount_annotations]
}

run "separate_runner_cluster_requires_subjects" {
  command = plan

  variables {
    is_separate_runner_cluster = true
  }

  expect_failures = [var.separate_runner_cluster_subjects]
}

run "create_identity_requires_resource_group" {
  command = plan

  variables {
    managed_identity_resource_group_name = null
  }

  expect_failures = [var.managed_identity_resource_group_name]
}

run "create_identity_rejects_managed_identity_id" {
  command = plan

  variables {
    managed_identity_id = "/subscriptions/aaaaaaaa-0000-0000-0000-000000000000/resourceGroups/existing-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/existing-identity"
  }

  expect_failures = [var.managed_identity_id]
}

run "credential_requires_oidc_issuer_url" {
  command = plan

  variables {
    aks_oidc_issuer_url = null
  }

  expect_failures = [var.aks_oidc_issuer_url]
}

run "no_credential_rejects_credential_name" {
  command = plan

  variables {
    federated_identity_credential_create = false
    federated_identity_credential_name   = "my-credential"
    aks_oidc_issuer_url                  = null
  }

  expect_failures = [var.federated_identity_credential_name]
}

run "existing_identity_requires_managed_identity_id" {
  command = plan

  variables {
    managed_identity_create              = false
    managed_identity_resource_group_name = null
  }

  expect_failures = [var.managed_identity_id]
}

run "existing_identity_rejects_invalid_managed_identity_id" {
  command = plan

  variables {
    managed_identity_create              = false
    managed_identity_id                  = "/subscriptions/aaaaaaaa-0000-0000-0000-000000000000/resourceGroups/existing-rg"
    managed_identity_resource_group_name = null
  }

  expect_failures = [var.managed_identity_id]
}

run "existing_identity_rejects_other_subscription" {
  command = plan

  variables {
    managed_identity_create              = false
    managed_identity_id                  = "/subscriptions/bbbbbbbb-0000-0000-0000-000000000000/resourceGroups/existing-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/existing-identity"
    managed_identity_resource_group_name = null
  }

  expect_failures = [data.azurerm_user_assigned_identity.runner_identity]
}

run "existing_identity_rejects_resource_group" {
  command = plan

  variables {
    managed_identity_create = false
    managed_identity_id     = "/subscriptions/aaaaaaaa-0000-0000-0000-000000000000/resourceGroups/existing-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/existing-identity"
  }

  expect_failures = [var.managed_identity_resource_group_name]
}

run "existing_identity_rejects_name" {
  command = plan

  variables {
    managed_identity_create              = false
    managed_identity_id                  = "/subscriptions/aaaaaaaa-0000-0000-0000-000000000000/resourceGroups/existing-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/existing-identity"
    managed_identity_resource_group_name = null
    managed_identity_name                = "my-identity"
  }

  expect_failures = [var.managed_identity_name]
}

run "existing_identity_rejects_location" {
  command = plan

  variables {
    managed_identity_create              = false
    managed_identity_id                  = "/subscriptions/aaaaaaaa-0000-0000-0000-000000000000/resourceGroups/existing-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/existing-identity"
    managed_identity_resource_group_name = null
    managed_identity_location            = "northeurope"
  }

  expect_failures = [var.managed_identity_location]
}

run "existing_identity_rejects_tags" {
  command = plan

  variables {
    managed_identity_create              = false
    managed_identity_id                  = "/subscriptions/aaaaaaaa-0000-0000-0000-000000000000/resourceGroups/existing-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/existing-identity"
    managed_identity_resource_group_name = null
    managed_identity_tags                = { env = "test" }
  }

  expect_failures = [var.managed_identity_tags]
}
