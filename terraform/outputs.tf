output "oidc_issuer_url" {
  description = "The OpenID Connect issuer URL."
  value       = azurerm_kubernetes_cluster.default.oidc_issuer_url
}

output "azurerm_user_assigned_identity_tf_runner_client_id" {
  description = "The tf-runner managed identity client identifier."
  value       = azurerm_user_assigned_identity.tf_runner.client_id
}

output "azurerm_public_ip_ingress_nginx_ip_address" {
  description = "The public IP address for the NGINX ingress controller."
  value       = azurerm_public_ip.ingress_nginx.ip_address
}
