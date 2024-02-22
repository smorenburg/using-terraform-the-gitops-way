terraform {
  required_providers {
    azurerm = {
      version = ">= 3.84"
    }

    random = {
      version = ">= 3.6"
    }

    http = {
      version = ">= 3.4"
    }
  }

  backend "azurerm" {
    container_name = "tfstate"
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

data "azurerm_client_config" "current" {}

# Get the public IP address
data "http" "public_ip" {
  url = "https://ifconfig.co/ip"
}

locals {
  # Lookup and set the location abbreviation, defaults to na (not available).
  location_abbreviation = try(var.location_abbreviation[var.location], "na")

  # Construct the name suffix.
  suffix = "${var.app}-${local.location_abbreviation}"

  # Clean and set the public IP address
  public_ip = chomp(data.http.public_ip.response_body)

  # Set the authorized IP ranges for the Kubernetes cluster.
  authorized_ip_ranges = ["${local.public_ip}/32"]
}

# Generate a random suffix for the logs storage account.
resource "random_string" "storage_account" {
  length  = 6
  special = false
  upper   = false
}

# Generate a random suffix for the key vault.
resource "random_string" "key_vault" {
  length  = 6
  special = false
  upper   = false
}

# Generate a random suffix for the container registry.
resource "random_string" "container_registry" {
  length  = 6
  special = false
  upper   = false
}

# Create the resource group.
resource "azurerm_resource_group" "default" {
  name     = "rg-${local.suffix}"
  location = var.location
}

# Create the storage account for the logs.
resource "azurerm_storage_account" "logs" {
  name                     = "st${var.app}${random_string.storage_account.result}"
  location                 = var.location
  resource_group_name      = azurerm_resource_group.default.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Create the Log Analytics workspace.
resource "azurerm_log_analytics_workspace" "default" {
  name                = "log-${local.suffix}"
  location            = var.location
  resource_group_name = azurerm_resource_group.default.name
  retention_in_days   = 30
}

# Create the container registry.
resource "azurerm_container_registry" "default" {
  name                = "cr${var.app}${random_string.container_registry.result}"
  resource_group_name = azurerm_resource_group.default.name
  location            = var.location
  sku                 = "Premium"
}

# Create the managed identity for the Kubernetes cluster.
resource "azurerm_user_assigned_identity" "kubernetes_cluster" {
  name                = "id-aks-${local.suffix}"
  location            = var.location
  resource_group_name = azurerm_resource_group.default.name
}

# Create the managed identity for the tf-runner, part of the tf-controller.
resource "azurerm_user_assigned_identity" "tf_runner" {
  name                = "id-tf-${local.suffix}"
  location            = var.location
  resource_group_name = azurerm_resource_group.default.name
}

# Create the federated identity credentials for the tf-runner service account.
resource "azurerm_federated_identity_credential" "tf_runner" {
  name                = "fc-tf-${local.suffix}"
  resource_group_name = azurerm_resource_group.default.name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.default.oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.tf_runner.id
  subject             = "system:serviceaccount:flux-system:tf-runner"
}

# Assign the 'Network Contributor' role to the Kubernetes cluster managed identity on the resource group.
resource "azurerm_role_assignment" "network_contributor_kubernetes_cluster_resource_group" {
  scope                = azurerm_resource_group.default.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.kubernetes_cluster.principal_id
}

# Assign the 'Cluster Admin' role to the current user on the Kubernetes cluster.
resource "azurerm_role_assignment" "cluster_admin_current_user_kubernetes_cluster" {
  scope                = azurerm_kubernetes_cluster.default.id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Assign the 'AcrPull' role to the Kubernetes cluster managed identity on the shared container registry.
resource "azurerm_role_assignment" "arcpull_kubernetes_cluster_container_registry" {
  scope                = azurerm_container_registry.default.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.kubernetes_cluster.principal_id
}

# Assign the 'Managed Identity Operator' role to the Kubernetes cluster managed identity on the Kubernetes cluster.
resource "azurerm_role_assignment" "managed_identity_operator_kubernetes_cluster" {
  scope                = azurerm_user_assigned_identity.kubernetes_cluster.id
  role_definition_name = "Managed Identity Operator"
  principal_id         = azurerm_user_assigned_identity.kubernetes_cluster.principal_id
}

# Assign the 'Contributor' role to tf-runner managed identity on the subscription.
resource "azurerm_role_assignment" "contributor_tf_runner_subscription" {
  scope                = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.tf_runner.principal_id
}
