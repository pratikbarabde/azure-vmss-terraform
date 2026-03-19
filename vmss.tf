resource "azurerm_orchestrated_virtual_machine_scale_set" "vmss" {
  name                        = "${local.resource_prefix}-vmss"
  resource_group_name         = data.azurerm_resource_group.rg.name
  location                    = data.azurerm_resource_group.rg.location
  sku_name                    = var.vmss_config.sku
  instances                   = var.vmss_config.instances
  platform_fault_domain_count = 1

  # Spread instances across all 3 availability zones for HA
  zones = ["1", "2", "3"]

  # User data script runs on first boot to install Apache + demo page
  # The file path is relative to the Terraform working directory.
  user_data_base64 = base64encode(file("${path.module}/userdata.sh"))

  os_profile {
    linux_configuration {
      disable_password_authentication = true
      admin_username                  = var.admin_username
      admin_ssh_key {
        username   = var.admin_username
        public_key = data.azurerm_key_vault_secret.ssh_public_key.value
        # Pass via: TF_VAR_admin_ssh_public_key="$(cat ~/.ssh/id_rsa.pub)"
        # Or add to terraform.tfvars (gitignored).
      }
    }
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-LTS-gen2"
    version   = "latest"
  }

  os_disk {
    # Premium_LRS gives significantly better IOPS for a web workload
    storage_account_type = "Standard_LRS"
    caching              = "ReadOnly" # ReadOnly is safe & faster for OS disks
  }

  network_interface {
    name    = "${local.resource_prefix}-nic"
    primary = true

    ip_configuration {
      name      = "primary"
      primary   = true
      subnet_id = azurerm_subnet.vmss.id
      load_balancer_backend_address_pool_ids = [
        azurerm_lb_backend_address_pool.vmss.id
      ]
    }
  }

  # Boot diagnostics — empty URI means Azure-managed storage (no extra cost)
  boot_diagnostics {}

  tags = local.tags

  lifecycle {
    # Autoscale manages instance count; ignore drift here so Terraform
    # doesn't reset it on every plan after autoscale fires.
    ignore_changes = [instances]
  }

  # Ensure NAT GW is ready before VMSS is created; instances need outbound
  # internet access to run the userdata.sh bootstrap script.
  depends_on = [azurerm_subnet_nat_gateway_association.vmss]
}
