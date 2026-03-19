variable "environment" {
  type        = string
  description = "Deployment environment (dev, stage, prod)"
  default     = "dev"

  validation {
    condition     = contains(["dev", "stage", "prod"], var.environment)
    error_message = "Environment must be dev, stage, or prod."
  }
}

variable "location" {
  type        = string
  description = "Azure region where resources will be deployed"
  default     = "East US 2"
}

variable "resource_group_name" {
  type        = string
  description = "Name of the existing resource group to deploy into"
}

variable "network_config" {
  type = object({
    vnet_cidr   = string
    subnet_cidr = string
  })
  description = "Network CIDR configuration"
  default = {
    vnet_cidr   = "10.0.0.0/16"
    subnet_cidr = "10.0.1.0/24"
  }
}

variable "vmss_config" {
  type = object({
    sku           = string
    instances     = number
    min_instances = number
    max_instances = number
  })
  description = "VMSS sizing and autoscale configuration"
  default = {
    sku           = "Standard_D2s_v4"
    instances     = 3
    min_instances = 1
    max_instances = 5
  }

  validation {
    condition     = var.vmss_config.min_instances <= var.vmss_config.instances && var.vmss_config.instances <= var.vmss_config.max_instances
    error_message = "instances must be between min_instances and max_instances."
  }
}

variable "admin_username" {
  type        = string
  description = "Admin username for VMSS instances"
  default     = "azureuser"
}

# variable "admin_ssh_public_key" {
#   type        = string
#   description = "SSH public key for admin access. Pass via TF_VAR_admin_ssh_public_key env var or terraform.tfvars."
#   sensitive   = true
# }

variable "allowed_ssh_source_ips" {
  type        = list(string)
  description = "List of IPs allowed to SSH via the LB NAT rules. Restrict to your office/VPN IP in production."
  default     = ["*"] # WARNING: Replace with your actual IP in production
}

variable "autoscale_config" {
  type = object({
    scale_out_cpu_threshold = number
    scale_in_cpu_threshold  = number
    scale_out_cooldown      = string
    scale_in_cooldown       = string
  })
  description = "Autoscale policy thresholds"
  default = {
    scale_out_cpu_threshold = 75
    scale_in_cpu_threshold  = 25
    scale_out_cooldown      = "PT5M"
    scale_in_cooldown       = "PT5M"
  }
}

variable "common_tags" {
  type        = map(string)
  description = "Tags applied to every resource"
  default = {
    Project   = "WebApp-ScaleSet"
    ManagedBy = "Terraform"
  }
}
