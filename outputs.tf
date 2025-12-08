//Use terraform output -raw primary_tunnel_token to get the token value without quotes from the cli
//Use terraform output -raw primary_tunnel_id to get the tunnel ID value without quotes from the cli
//Use terraform output -raw failover_tunnel_token to get the token value without quotes from the cli
//Use terraform output -raw failover_tunnel_id to get the tunnel ID value without quotes from the cli

output "cluster_a_tunnel_id" {
  value = cloudflare_zero_trust_tunnel_cloudflared.cluster_a_tunnel.id
}

output "cluster_a_tunnel_token" {
  description = "Token to connect the CLuster B CF Tunnel"
  value       = local.primary_token
  sensitive   = true
}

output "cluster_b_tunnel_id" {
  value = cloudflare_zero_trust_tunnel_cloudflared.cluster_b_tunnel.id
}

output "cluster_b_tunnel_token" {
  description = "Token to connect the Cluster B Tunnel"
  value       = local.failover_token
  sensitive   = true
}

output "load_balancer_hostname" {
  value = var.cluster_lb_hostname
}