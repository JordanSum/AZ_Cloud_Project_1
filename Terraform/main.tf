provider "azurerm" {
  features {}

  subscription_id = var.subscription_id
}

# Fetch the current Azure client configuration
data "azurerm_client_config" "current" {}

# Create a resource group
resource "azurerm_resource_group" "rg" {
  name     = var.rg_name
  location = var.location
}

# Create a network security group and define the rules

# Allow SSH traffic
resource "azurerm_network_security_rule" "allow_ssh" {
  name                        = "allow-SSH"
  priority                    = 1000
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["22"]
  source_address_prefix       = var.public_ip  # var.public_ip is the public IP address of the machine you are connecting from
  destination_address_prefix  = "*"
  network_security_group_name = azurerm_network_security_group.nsg.name
  resource_group_name         = azurerm_resource_group.rg.name
}

# Allow HTTP traffic
resource "azurerm_network_security_rule" "allow_http" {
  name                        = "allow-HTTP"
  priority                    = 1001
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["80"]
  source_address_prefix       = "*" 
  destination_address_prefix  = "*"
  network_security_group_name = azurerm_network_security_group.nsg.name
  resource_group_name         = azurerm_resource_group.rg.name
}

# Allow HTTPS traffic
resource "azurerm_network_security_rule" "allow_https" {
  name                        = "allow-HTTPS"
  priority                    = 1002
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["443"]
  source_address_prefix       = "*" 
  destination_address_prefix  = "*"
  network_security_group_name = azurerm_network_security_group.nsg.name
  resource_group_name         = azurerm_resource_group.rg.name
}

# Create a virtual network and subnet
resource "azurerm_virtual_network" "vnet" {
  name                = "${var.rg_name}-vnet"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "subnet" {
  name                 = "${var.rg_name}-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Associate the NSG with the Network Interface

resource "azurerm_network_interface_security_group_association" "my_nic_association" {
  network_interface_id = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_network_security_group" "nsg" {
  name                = var.nsg_name
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Create a Network Interface Card and associate with the Public IP and NSG
resource "azurerm_network_interface" "nic" {
  name                = "${var.vm_name}-nic"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "${var.vm_name}-ip"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip.id
  }

}

# Create a Public IP address
resource "azurerm_public_ip" "public_ip" {
  name                = "${var.vm_name}-public-ip"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
}

# Define the Key Vault data source so we can reference the pre-existing Key Vault
data "azurerm_key_vault" "pre-existing-key-vault" {
  name                = var.key_vault_name
  resource_group_name = var.key_vault_rg
}

# Define the Key Vault Secret data source so we can reference the SSH public key
data "azurerm_key_vault_secret" "ssh_public_key" {
  name         = var.ssh_public_key_secret_name
  key_vault_id = data.azurerm_key_vault.pre-existing-key-vault.id
}

# Create a virtual machine
resource "azurerm_virtual_machine" "vm" {
  name                  = var.vm_name
  location              = var.location
  zones                 = ["2"]
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.nic.id]
  vm_size               = var.vm_size

  storage_image_reference {
    publisher = var.os_publisher
    offer     = var.vm_image    
    sku       = var.vm_sku
    version   = var.os_version
    
  }

  storage_os_disk {
    name              = "${var.vm_name}-osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = var.vm_name
    admin_username = var.username

    custom_data = base64encode(<<-EOF
      #!/bin/bash
      
      # Update the system
      sudo apt-get update && sudo apt-get upgrade -y

      # Install necessary packages
      sudo apt-get install -y fail2ban unattended-upgrades

      # Configure automatic reboot for unattended upgrades
      echo 'Unattended-Upgrade::Automatic-Reboot "true";' | sudo tee -a /etc/apt/apt.conf.d/50unattended-upgrades

      # Configure SSH settings
      sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config
      sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
      sudo systemctl restart sshd

    EOF
    )
  }

  os_profile_linux_config {
    disable_password_authentication = true

    # Configure the SSH public key that is being retrieved from the Key Vault
    ssh_keys {
      path     = "/home/${var.username}/.ssh/authorized_keys"
      key_data = data.azurerm_key_vault_secret.ssh_public_key.value
    }
  }

  # Enable system-assigned managed identity to allow the VM to access the Key Vault
  identity {
    type = "SystemAssigned"
  }

  delete_os_disk_on_termination = true  # Ensure the OS disk is deleted when the VM is deleted
}

# Assign the Key Vault Secrets User role to the VM's managed identity
resource "azurerm_role_assignment" "kv_secrets_user" {
  principal_id         = azurerm_virtual_machine.vm.identity[0].principal_id
  role_definition_name = "Key Vault Secrets User"
  scope                = data.azurerm_key_vault.pre-existing-key-vault.id
}

# Assign the Key Vault Access Policy to the VM's managed identity
resource "azurerm_key_vault_access_policy" "kv-policy" {
  key_vault_id = data.azurerm_key_vault.pre-existing-key-vault.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_virtual_machine.vm.identity[0].principal_id

  secret_permissions = [
    "Get",
  ]
}