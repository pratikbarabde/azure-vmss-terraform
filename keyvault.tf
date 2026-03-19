# keyvault.tf

data "azurerm_client_config" "current" {}

# Reference the existing Key Vault — we created it manually in Portal
data "azurerm_key_vault" "kv" {
  name                = "tfsecretdev"
  resource_group_name = var.resource_group_name
}

# Read each secret as a data source
data "azurerm_key_vault_secret" "ssh_public_key" {
  name         = "ssh-public-key"
  key_vault_id = data.azurerm_key_vault.kv.id
}

data "azurerm_key_vault_secret" "spn_client_id" {
  name         = "spn-client-id"
  key_vault_id = data.azurerm_key_vault.kv.id
}

data "azurerm_key_vault_secret" "spn_client_secret" {
  name         = "spn-client-secret"
  key_vault_id = data.azurerm_key_vault.kv.id
}

data "azurerm_key_vault_secret" "spn_tenant_id" {
  name         = "spn-tenant-id"
  key_vault_id = data.azurerm_key_vault.kv.id
}

data "azurerm_key_vault_secret" "spn_subscription_id" {
  name         = "spn-subscription-id"
  key_vault_id = data.azurerm_key_vault.kv.id
}