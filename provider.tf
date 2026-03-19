terraform {
  required_version = ">=1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.104.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.6.0"
    }
  }

}

provider "azurerm" {
  features {
    virtual_machine_scale_set {
      # Prevent accidental deletion of VMSS with instances running
      force_delete = false
    }
  }

  # Credentials are loaded from environment variables automatically:
  # ARM_CLIENT_ID, ARM_CLIENT_SECRET, ARM_TENANT_ID, ARM_SUBSCRIPTION_ID
  # Never hardcode credentials here or in any .tf / .ps1 file.
  skip_provider_registration = true
}
