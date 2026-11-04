variable "location" {
  description = "Azure region for every resource in this lab."
  type        = string
  default     = "australiaeast"
}

variable "prefix" {
  description = "Short project name used inside resource names."
  type        = string
  default     = "hubspoke"
}

variable "resource_group_name" {
  description = "Name of the resource group that holds the lab resources."
  type        = string
  default     = "rg-hubspoke-lab-aue"
}

variable "tags" {
  description = "Tags applied to every resource that supports them."
  type        = map(string)
  default     = {}
}

variable "enable_firewall" {
  description = "Deploy Azure Firewall, its policy and public IP, its diagnostic setting and the spoke route tables. Billed hourly while it exists."
  type        = bool
  default     = false
}

variable "enable_bastion" {
  description = "Deploy Azure Bastion (Basic) and its public IP. Billed hourly while it exists."
  type        = bool
  default     = false
}

variable "hub_address_space" {
  description = "Address space of the hub VNet."
  type        = string
  default     = "10.0.0.0/16"
}

variable "hub_firewall_subnet_prefix" {
  description = "Prefix for AzureFirewallSubnet. Must be at least /26."
  type        = string
  default     = "10.0.1.0/26"
}

variable "hub_bastion_subnet_prefix" {
  description = "Prefix for AzureBastionSubnet. Must be at least /26."
  type        = string
  default     = "10.0.2.0/26"
}

variable "spokes" {
  description = "Map of spoke VNets. Each entry creates a VNet, workload subnet, NSG, route table, peerings and one Linux VM. allow_inbound_from lists the spoke keys allowed to reach this spoke over SSH and ICMP."
  type = map(object({
    address_space          = string
    workload_subnet_prefix = string
    vm_private_ip          = string
    allow_inbound_from     = list(string)
  }))
}

variable "allowed_web_fqdns" {
  description = "FQDNs the spoke VMs may reach over HTTP and HTTPS through the firewall."
  type        = list(string)
  default = [
    "*.microsoft.com",
    "*.ubuntu.com",
  ]
}

variable "vm_size" {
  description = "Size of the spoke test VMs."
  type        = string
  default     = "Standard_B1s"
}

variable "admin_username" {
  description = "Admin username on the Linux VMs."
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key" {
  description = "SSH public key for the VM admin user. Supplied through the TF_VAR_ssh_public_key environment variable, never committed."
  type        = string

  validation {
    condition     = can(regex("^ssh-rsa ", var.ssh_public_key))
    error_message = "ssh_public_key must be an RSA public key starting with ssh-rsa. Check that TF_VAR_ssh_public_key is set."
  }
}

variable "log_retention_days" {
  description = "Log Analytics retention in days."
  type        = number
  default     = 30
}

variable "log_daily_quota_gb" {
  description = "Daily ingestion cap for the Log Analytics workspace, as a cost guard."
  type        = number
  default     = 1
}
