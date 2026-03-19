# ---------------------------------------------------------------------------
# Existing resource group — imported as a data source so Terraform does not
# own its lifecycle. Replace the name with your actual RG or pass it via
# terraform.tfvars / TF_VAR_resource_group_name.
# ---------------------------------------------------------------------------
data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}

# ---------------------------------------------------------------------------
# Random suffix — used for globally unique names (Public IP DNS labels, etc.)
# ---------------------------------------------------------------------------
resource "random_pet" "suffix" {
  length    = 2
  separator = "-"
}

# ---------------------------------------------------------------------------
# Virtual Network + Subnet
# ---------------------------------------------------------------------------
resource "azurerm_virtual_network" "vnet" {
  name                = "${local.resource_prefix}-vnet"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  address_space       = [var.network_config.vnet_cidr]
  tags                = local.tags
}

resource "azurerm_subnet" "vmss" {
  name                 = "${local.resource_prefix}-subnet"
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.network_config.subnet_cidr]
}

# ---------------------------------------------------------------------------
# Network Security Group
# Dynamic block builds all rules from locals.nsg_rules — add new rules there.
# ---------------------------------------------------------------------------
resource "azurerm_network_security_group" "vmss" {
  name                = "${local.resource_prefix}-nsg"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  tags                = local.tags

  dynamic "security_rule" {
    for_each = local.nsg_rules
    content {
      name                       = security_rule.key
      priority                   = security_rule.value.priority
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = security_rule.value.destination_port_range
      source_address_prefix      = security_rule.value.source_address_prefix
      destination_address_prefix = "VirtualNetwork"
      description                = security_rule.value.description
    }
  }
}

resource "azurerm_subnet_network_security_group_association" "vmss" {
  subnet_id                 = azurerm_subnet.vmss.id
  network_security_group_id = azurerm_network_security_group.vmss.id
}

# ---------------------------------------------------------------------------
# NAT Gateway — provides outbound internet access for VMSS instances.
# Required because the Standard LB has no default outbound SNAT rules.
# ---------------------------------------------------------------------------
resource "azurerm_public_ip" "natgw" {
  name                = "${local.resource_prefix}-natgw-pip"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = local.tags
}

resource "azurerm_nat_gateway" "natgw" {
  name                    = "${local.resource_prefix}-natgw"
  location                = data.azurerm_resource_group.rg.location
  resource_group_name     = data.azurerm_resource_group.rg.name
  sku_name                = "Standard"
  idle_timeout_in_minutes = 10
  tags                    = local.tags
}

resource "azurerm_nat_gateway_public_ip_association" "natgw" {
  nat_gateway_id       = azurerm_nat_gateway.natgw.id
  public_ip_address_id = azurerm_public_ip.natgw.id
}

resource "azurerm_subnet_nat_gateway_association" "vmss" {
  subnet_id      = azurerm_subnet.vmss.id
  nat_gateway_id = azurerm_nat_gateway.natgw.id
}

# ---------------------------------------------------------------------------
# Load Balancer — Standard SKU, zone-redundant frontend
# ---------------------------------------------------------------------------
resource "azurerm_public_ip" "lb" {
  name                = "${local.resource_prefix}-lb-pip"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  # Uncomment to set a friendly DNS name:
   domain_name_label = "${local.resource_prefix}-${random_pet.suffix.id}"
  tags = local.tags
}

resource "azurerm_lb" "lb" {
  name                = "${local.resource_prefix}-lb"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  sku                 = "Standard"
  tags                = local.tags

  frontend_ip_configuration {
    name                 = "frontend"
    public_ip_address_id = azurerm_public_ip.lb.id
  }
}

resource "azurerm_lb_backend_address_pool" "vmss" {
  name            = "${local.resource_prefix}-bepool"
  loadbalancer_id = azurerm_lb.lb.id
}

# Health probe — LB only routes to instances where Apache returns 200 on "/"
resource "azurerm_lb_probe" "http" {
  name                = "http-probe"
  loadbalancer_id     = azurerm_lb.lb.id
  protocol            = "Http"
  port                = 80
  request_path        = "/"
  interval_in_seconds = 5
  number_of_probes    = 2
}

# LB rule: distribute HTTP traffic across all healthy backend instances
resource "azurerm_lb_rule" "http" {
  name                           = "http"
  loadbalancer_id                = azurerm_lb.lb.id
  frontend_ip_configuration_name = azurerm_lb.lb.frontend_ip_configuration[0].name
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.vmss.id]
  probe_id                       = azurerm_lb_probe.http.id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  enable_floating_ip             = false
  idle_timeout_in_minutes        = 4
  disable_outbound_snat          = true # Outbound handled by NAT Gateway above
}

# NAT rule pool: SSH into individual instances via ports 50000-50009
# e.g. ssh azureuser@<LB_IP> -p 50000 => instance 0
resource "azurerm_lb_nat_rule" "ssh" {
  name                           = "ssh-nat"
  resource_group_name            = data.azurerm_resource_group.rg.name
  loadbalancer_id                = azurerm_lb.lb.id
  frontend_ip_configuration_name = azurerm_lb.lb.frontend_ip_configuration[0].name
  backend_address_pool_id        = azurerm_lb_backend_address_pool.vmss.id
  protocol                       = "Tcp"
  frontend_port_start            = 50000
  frontend_port_end              = 50009
  backend_port                   = 22
}
