resource "azurerm_log_analytics_workspace" "lab" {
  name                = "log-${var.prefix}-lab"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days
  daily_quota_gb      = var.log_daily_quota_gb
  tags                = var.tags
}

resource "azurerm_monitor_diagnostic_setting" "firewall" {
  count = var.enable_firewall ? 1 : 0

  name                           = "diag-firewall-to-law"
  target_resource_id             = azurerm_firewall.hub[0].id
  log_analytics_workspace_id     = azurerm_log_analytics_workspace.lab.id
  log_analytics_destination_type = "Dedicated"

  enabled_log {
    category = "AZFWNetworkRule"
  }

  enabled_log {
    category = "AZFWApplicationRule"
  }

  enabled_log {
    category = "AZFWNatRule"
  }

  enabled_log {
    category = "AZFWThreatIntel"
  }
}
