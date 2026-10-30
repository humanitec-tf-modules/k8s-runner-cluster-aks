terraform {
  required_version = ">= 1.11.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3"
    }
    # 4.65.0 introduced user_assigned_identity_id on azurerm_federated_identity_credential.
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.65.0, < 6.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3"
    }
  }
}
