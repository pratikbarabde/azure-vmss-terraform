# terraform.tfvars.example
# Copy this to terraform.tfvars and fill in real values.
# Add terraform.tfvars to your .gitignore — never commit it.

environment         = "dev"
location            = "East US 2"
resource_group_name = "kml_rg_main-cdd5c41b59e84728"

# Restrict SSH source to your IP in production
# allowed_ssh_source_ips = ["203.0.113.10/32"]

vmss_config = {
  sku           = "Standard_D2s_v3"
  instances     = 3
  min_instances = 1
  max_instances = 3
}
