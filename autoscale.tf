
/* 
  This file defines an autoscale setting for the VMSS. It includes a profile with capacity settings and commented-out rules for scaling based on CPU usage. Adjust the rules and thresholds as needed for your workload.

resource "azurerm_monitor_autoscale_setting" "vmss" {
  name                = "${local.resource_prefix}-autoscale"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  target_resource_id  = azurerm_orchestrated_virtual_machine_scale_set.vmss.id
  enabled             = true

  profile {
    name = "default"

    capacity {
      default = var.vmss_config.instances
      minimum = var.vmss_config.min_instances
      maximum = var.vmss_config.max_instances
    }/* 
    
    /* Uncomment below to enable autoscaling based on CPU usage. Adjust thresholds & cooldowns as needed.

    # Scale OUT: add 1 instance when avg CPU > 75% over 5 minutes
    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_orchestrated_virtual_machine_scale_set.vmss.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = var.autoscale_config.scale_out_cpu_threshold
      }
      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = 1
        cooldown  = var.autoscale_config.scale_out_cooldown
      }
    }

    # Scale IN: remove 1 instance when avg CPU < 25% over 5 minutes
    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_orchestrated_virtual_machine_scale_set.vmss.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = var.autoscale_config.scale_in_cpu_threshold
      }
      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = 1
        cooldown  = var.autoscale_config.scale_in_cooldown
      }
    }
  } 

  }
  
}*/
