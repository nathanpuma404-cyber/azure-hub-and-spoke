locals {
  # one entry per (dest spoke, allowed src spoke) pair
  # eg, spoke2 allowing SSH and ICMP from spok1

  spoke_peer_pairs = flatten([
    for dest_key, dest in var.spokes : [
      for idx, source_key in dest.allow_inbound_from : {
        key         = "${source_key}-to-${dest_key}"
        dest_key    = dest_key
        source_key  = source_key
        source_cidr = var.spokes[source_key].address_space
        dest_cidr   = dest.address_space
        index       = idx
      }
    ]
  ])

  spoke_peer_rules = {
    for pair in local.spoke_peer_pairs : pair.key => pair
  }
}

resource "azurerm_network_security_group" "workload" {
  for_each = var.spokes

  name                = "nsg-${var.prefix}-${each.key}-workload"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  tags                = var.tags
}

# bastion in the hub reaches every spoke VM over SSH

resource "azurerm_network_security_rule" "allow_ssh_from_bastion" {
  for_each = var.spokes

  name                        = "Allow-SSH-From-Bastion"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = var.hub_bastion_subnet_prefix
  destination_address_prefix  = each.value.workload_subnet_prefix
  resource_group_name         = azurerm_resource_group.lab.name
  network_security_group_name = azurerm_network_security_group.workload[each.key].name
}

# spoke-to-spoke SSH, only for pairs listed in allow_inbound_from
resource "azurerm_network_security_rule" "allow_ssh_from_peer" {
  for_each = local.spoke_peer_rules

  name                        = "Allow-SSH-From-${each.value.source_key}"
  priority                    = 200 + (each.value.index * 10)
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = each.value.source_cidr
  destination_address_prefix  = var.spokes[each.value.dest_key].workload_subnet_prefix
  resource_group_name         = azurerm_resource_group.lab.name
  network_security_group_name = azurerm_network_security_group.workload[each.value.dest_key].name
}

# spoke-to-spoke ICMP (ping)
resource "azurerm_network_security_rule" "allow_icmp_from_peer" {
  for_each = local.spoke_peer_rules

  name                        = "Allow-ICMP-From-${each.value.source_key}"
  priority                    = 205 + (each.value.index * 10)
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Icmp"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = each.value.source_cidr
  destination_address_prefix  = var.spokes[each.value.dest_key].workload_subnet_prefix
  resource_group_name         = azurerm_resource_group.lab.name
  network_security_group_name = azurerm_network_security_group.workload[each.value.dest_key].name
}

resource "azurerm_network_security_rule" "deny_vnet_inbound" {
  for_each = var.spokes

  name                        = "Deny-Vnet-Inbound"
  priority                    = 4000
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.lab.name
  network_security_group_name = azurerm_network_security_group.workload[each.key].name
}

resource "azurerm_subnet_network_security_group_association" "workload" {
  for_each = var.spokes

  subnet_id                 = azurrm_subnet.workdload[each.key].id
  network_security_group_id = azurerm_network_security_group.workload[each.key].id
}
