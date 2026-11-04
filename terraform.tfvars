# WARNING: whatever these flags say is what the pipeline deploys when you
# merge to main. Set both to false before merging anything after teardown.

location            = "australiaeast"
prefix              = "hubspoke"
resource_group_name = "rg-hubspoke-lab-aue"

enable_firewall = true
enable_bastion  = true

vm_size        = "Standard_D2as_v5"
admin_username = "azureuser"

spokes = {
  spoke1 = {
    address_space          = "10.1.0.0/16"
    workload_subnet_prefix = "10.1.1.0/24"
    vm_private_ip          = "10.1.1.4"
    allow_inbound_from     = []
  }
  spoke2 = {
    address_space          = "10.2.0.0/16"
    workload_subnet_prefix = "10.2.1.0/24"
    vm_private_ip          = "10.2.1.4"
    allow_inbound_from     = ["spoke1"]
  }
}

allowed_web_fqdns = [
  "*.microsoft.com",
  "*.ubuntu.com",
]

tags = {
  project     = "hubspoke"
  environment = "lab"
  owner       = "nathan"
  managed_by  = "terraform"
}
