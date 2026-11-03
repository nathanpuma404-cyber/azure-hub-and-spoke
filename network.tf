locals {
  spoke_address_spaces = [
    for spoke in values(var.spokes) : spoke.address_space
  ]

  # Spokes that get a route table. Empty when the firewall is disabled, so no route points
  # at a firewall that does not exist

  firewall_spokes = {
    for key, spoke in var.spokes : key => spoke
    if var.enable_firewall
  }

  firewall_private_ip = try(azurerm_firewall.hub[0].ip_configuration[0].private_ip_address, null)
}

resource "azurerm_resource_group" "lab" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# Hub
resource "azurerm_virtual_network" "hub" {
  name                = "vnet-${var.prefix}-hub"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  address_space       = [var.hub_address_space]
  tags                = var.tags
}

resource "azurerm_subnet" "firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.hub_firewall_subnet_prefix]

}

resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.hub_firewall_subnet_prefix]
}

# Spokes
resource "azurerm_virtual_network" "spoke" {
  for_each = var.spokes

  name                = "vnet-${var.prefix}-${each.key}"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  address_space       = [each.value.address_space]
  tags                = var.tags
}

resource "azurerm_subnet" "workload" {
  for_each = var.spokes

  name                            = "snet-workload"
  resource_group_name             = azurerm_resource_group.lab.name
  virtual_network_name            = azurerm_virtual_network.spoke[each.key].name
  address_prefixes                = [each.value.workload_subnet_prefix]
  default_outbound_access_enabled = false
}

# peering (hub <-> each spoke, not spoke <-> spoke)
resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  for_each = var.spokes

  name                         = "peer-hub-to-${each.key}"
  resource_group_name          = azurerm_resource_group.lab.name
  virtual_network_name         = azurerm_virtual_network.hub.name
  remote_virtual_network_id    = azurerm_virtual_network.spoke[each.key].id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  for_each = var.spokes

  name                         = "peer-${each.key}-to-hub"
  resource_group_name          = azurerm_resource_group.lab.name
  virtual_network_name         = azurerm_virtual_network.spoke[each.key].name
  remote_virtual_network_id    = azurerm_virtual_network.hub.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

# user-defined routes
resource "azurerm_route_table" "spoke" {
  for_each = local.firewall_spokes

  name                          = "rt-${var.prefix}-${each.key}"
  location                      = azurerm_resource_group.lab.location
  resource_group_name           = azurerm_resource_group.lab.name
  bgp_route_propagation_enabled = false
  tags                          = var.tags

  route {
    name                   = "default-to-firewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = local.firewall_private_ip
  }
}

resource "azurerm_subnet_route_table_association" "workload" {
  for_each = local.firewall_spokes

  subnet_id      = azurerm_subnet.workload.spoke[each.key].id
  route_table_id = azurerm_route_table.spoke[each.key].id

}



