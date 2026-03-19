locals {
  # Consistent naming prefix: "<env>-web"
  resource_prefix = "${var.environment}-web"

  # Merged tags applied to every resource
  tags = merge(var.common_tags, {
    Environment = var.environment
  })

  # NSG rules defined as a map — used by a dynamic block in vnet.tf
  # Each key becomes the rule name; only inbound TCP rules are modelled here.
  nsg_rules = {
    allow_http = {
      priority               = 100
      destination_port_range = "80"
      source_address_prefix  = "*" # Public internet — intentional for a web app
      description            = "Allow inbound HTTP from internet"
    }
    allow_https = {
      priority               = 110
      destination_port_range = "443"
      source_address_prefix  = "*"
      description            = "Allow inbound HTTPS from internet"
    }
    # SECURITY: Restrict source to your office/VPN IP in production.
    # Pass the real IP through var.allowed_ssh_source_ips.
    allow_ssh = {
      priority               = 120
      destination_port_range = "22"
      source_address_prefix  = length(var.allowed_ssh_source_ips) == 1 ? var.allowed_ssh_source_ips[0] : null
      description            = "Allow SSH — restrict source in prod"
    }
  }
}
