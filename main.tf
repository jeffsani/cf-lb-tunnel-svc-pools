# --- Random Secret Generator ---
resource "random_id" "tunnel_secret" {
  byte_length = 32
}

# --- Create Cloudflare Tunnels ---
resource "cloudflare_zero_trust_tunnel_cloudflared" "cluster_a_tunnel" {
  account_id    = var.cloudflare_account_id
  name          = var.primary_tunnel_name
  tunnel_secret = random_id.tunnel_secret.b64_std
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "cluster_b_tunnel" {
  account_id    = var.cloudflare_account_id
  name          = var.failover_tunnel_name
  tunnel_secret = random_id.tunnel_secret.b64_std
}

# --- Create Tunnel Routes ---
resource "cloudflare_zero_trust_tunnel_cloudflared_route" "svc_a_pool_route" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.primary.id
  network    = var.primary_tunnel_cidr
  comment    = "Tunnel Route for SVC Pool A"
}

resource "cloudflare_zero_trust_tunnel_cloudflared_route" "svc_b_pool_route {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.failover.id
  network    = var.failover_tunnel_cidr
  comment    = "Tunnel Route for SVC Pool B"
}

# --- Create LB Monitors ---
resource "cloudflare_load_balancer_monitor" "svc_a_monitor" {
  account_id     = var.cloudflare_account_id
  type           = "http"
  method         = "GET"
  path           = "/"
  expected_codes = "2xx"
  timeout        = 5
  interval       = 60
  retries        = 2
  description    = "Monitor for SVC A"
}

# --- Create LB Monitors ---
resource "cloudflare_load_balancer_monitor" "svc_b_monitor" {
  account_id     = var.cloudflare_account_id
  type           = "http"
  method         = "GET"
  path           = "/"
  expected_codes = "2xx"
  timeout        = 5
  interval       = 60
  retries        = 2
  description    = "Monitor for SVC B"
}

# --- Create LB Pools ---
resource "cloudflare_load_balancer_pool" "svc_a_pool" {
  account_id = var.cloudflare_account_id
  name       = "${svc_a_tunnel_name}-pool"
  monitor    = cloudflare_load_balancer_monitor.http_monitor.id

  origins = [{
    name    = "primary-tunnel-origin"
    address = "${cloudflare_zero_trust_tunnel_cloudflared.svc_a_pool.id}.cfargotunnel.com"
    weight  = 1
    enabled = true
    header  = {}
  }]
}

resource "cloudflare_load_balancer_pool" "failover_pool" {
  account_id = var.cloudflare_account_id
  name       = "${var.failover_tunnel_name}-pool"
  monitor    = cloudflare_load_balancer_monitor.http_monitor.id

  origins = [{
    name    = "failover-tunnel-origin"
    address = "${cloudflare_zero_trust_tunnel_cloudflared.failover.id}.cfargotunnel.com"
    weight  = 1
    enabled = true
    header  = {}
  }]
}

# --- Create Load Balancer ---
resource "cloudflare_load_balancer" "lb" {
  zone_id = var.cloudflare_zone_id
  name    = var.lb_hostname

  # v5 FIX: Renamed from 'default_pool_ids' to 'default_pools'
  default_pools = [cloudflare_load_balancer_pool.primary_pool.id]

  # v5 FIX: Renamed from 'fallback_pool_id' to 'fallback_pool'
  fallback_pool = cloudflare_load_balancer_pool.failover_pool.id

  description     = "LB with Tunnel Backends"
  proxied         = true
  steering_policy = "off"
}