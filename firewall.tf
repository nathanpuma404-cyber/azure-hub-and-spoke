resource "azurerm_public_ip" "firewall" {
  count = var.enable_firewall ? 1 : 0

  name                = "pip-${var.prefix}-fw"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_firewall_policy" "hub" {
  count = var.enable_firewall ? 1 : 0

  name                     = "afwp-${var.prefix}"
  location                 = azurerm_resource_group.lab.location
  resource_group_name      = azurerm_resource_group.lab.name
  sku                      = "Standard"
  threat_intelligence_mode = "Alert"
  tags                     = var.tags
}

resource "azurerm_firewall_policy_rule_collection_group" "hub" {
  count = var.enable_firewall ? 1 : 0

  name               = "rcg-${var.prefix}-core"
  firewall_policy_id = azurerm_firewall_policy.hub[0].id
  priority           = 200

  # 1. Allow listed spoke pairs (spoke1 -> spoke2) for SSH and ICMP only.
  network_rule_collection {
    name     = "rc-allow-spoke-to-spoke"
    priority = 100
    action   = "Allow"

    dynamic "rule" {
      for_each = local.spoke_peer_rules

      content {
        name                  = "allow-ssh-${rule.key}"
        protocols             = ["TCP"]
        source_addresses      = [rule.value.source_cidr]
        destination_addresses = [rule.value.dest_cidr]
        destination_ports     = ["22"]
      }
    }

    dynamic "rule" {
      for_each = local.spoke_peer_rules

      content {
        name                  = "allow-icmp-${rule.key}"
        protocols             = ["ICMP"]
        source_addresses      = [rule.value.source_cidr]
        destination_addresses = [rule.value.dest_cidr]
        destination_ports     = ["*"]
      }
    }
  }

  # 2. Explicitly deny every other spoke-to-spoke flow (for example spoke2 -> spoke1).
  network_rule_collection {
    name     = "rc-deny-spoke-to-spoke"
    priority = 200
    action   = "Deny"

    rule {
      name                  = "deny-all-spoke-to-spoke"
      protocols             = ["Any"]
      source_addresses      = local.spoke_address_spaces
      destination_addresses = local.spoke_address_spaces
      destination_ports     = ["*"]
    }
  }

  # 3. Allow outbound web access only to approved FQDNs.
  application_rule_collection {
    name     = "rc-allow-web-fqdns"
    priority = 300
    action   = "Allow"

    rule {
      name              = "allow-approved-fqdns"
      source_addresses  = local.spoke_address_spaces
      destination_fqdns = var.allowed_web_fqdns

      protocols {
        type = "Http"
        port = 80
      }

      protocols {
        type = "Https"
        port = 443
      }
    }
  }
}

resource "azurerm_firewall" "hub" {
  count = var.enable_firewall ? 1 : 0

  name                = "afw-${var.prefix}-hub"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"
  firewall_policy_id  = azurerm_firewall_policy.hub[0].id
  tags                = var.tags

  ip_configuration {
    name                 = "ipconfig-fw"
    subnet_id            = azurerm_subnet.firewall.id
    public_ip_address_id = azurerm_public_ip.firewall[0].id
  }

  # Create the rules before the firewall so it starts with a complete policy
  # and the two do not update the same policy at the same time.
  depends_on = [
    azurerm_firewall_policy_rule_collection_group.hub,
  ]
}
