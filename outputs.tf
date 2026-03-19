# outputs.tf — useful values after apply

output "lb_public_ip" {
  description = "Public IP of the Load Balancer — open this in your browser"
  value       = azurerm_public_ip.lb.ip_address
}

output "lb_public_ip_fqdn" {
  description = "DNS label for the Load Balancer (if domain_name_label is set)"
  value       = azurerm_public_ip.lb.fqdn
}

output "vmss_id" {
  description = "Resource ID of the VMSS"
  value       = azurerm_orchestrated_virtual_machine_scale_set.vmss.id
}

output "ssh_nat_instructions" {
  description = "How to SSH into individual VMSS instances"
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.lb.ip_address} -p 50000   # instance 0, 50001 for instance 1, etc."
}
