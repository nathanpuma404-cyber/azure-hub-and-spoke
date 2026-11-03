output "resource_group_name" {
  description = "Lab resource group."
  value       = azurerm_resource_group.lab.name
}

output "firewall_private_ip" {
  description = "Private IP of Azure Firewall (next hop for the spoke UDRs). Null when the firewall is disabled."
  value       = local.firewall_private_ip
}

output "vm_private_ips" {
  description = "Private IP of each spoke VM."
  value = {
    for key, nic in azurerm_network_interface.vm : key => nic.private_ip_address
  }
}

output "vm_names" {
  description = "Name of each spoke VM."
  value = {
    for key, vm in azurerm_linux_virtual_machine.vm : key => vm.name
  }
}

output "bastion_name" {
  description = "Bastion host name. Null when Bastion is disabled."
  value       = try(azurerm_bastion_host.hub[0].name, null)
}

output "log_analytics_workspace_id" {
  description = "Workspace (customer) ID used for KQL queries."
  value       = azurerm_log_analytics_workspace.lab.workspace_id
}
