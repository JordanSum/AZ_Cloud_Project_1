variable "subscription_id" {
  type    = string
  description = "value of the selected subscription id, create/look in the terraform.tfvars file"
}

variable "vm_name" {
  type    = string
  description = "Name of the virtual machine:"
  default = "default-vm"
}

variable "username" {
  type    = string
  description = "Username for the virtual machine:"
  default = "adminuser"
}

variable "nsg_name" {
  type    = string
  description = "Network Security Group name"
  default = "default-nsg"
}

variable "os_publisher" {
  type    = string
  description = "value of the selected os publisher"
  default = "Canonical"
}

variable "vm_image" {
  type    = string
  description = "value of the selected vm image"
  default = "0001-com-ubuntu-server-focal"
}

variable "vm_sku" {
  type    = string
  description = "value of the selected vm sku"
  default = "20_04-lts-gen2"
}

variable "vm_size" {
  type    = string
  description = "value of the selected vm size"
  default = "Standard_B1s"
}

variable "os_version" {
  type    = string
  description = "value of the selected os version"
  default = "20.04.202209200"
}

variable "location" {
  type    = string
  description = "Location of the cloud environment"
  default = "westus2"
}

variable "public_ip" {
  type    = string
  description = "Enter the public IP address of the machine you are connecting from:"
  sensitive = true
  }

#ps1 script variables

variable "key_vault_name" {
  type    = string
  description = "value of the selected key vault name pulled from the env.ps1 file"
}

variable "key_vault_rg" {
  type    = string
  description = "value of the selected key vault resource group pull from the env.ps1 file"
}

variable "ssh_public_key_secret_name" {
  type    = string
  description = "value of the selected ssh public key secret name pulled from the env.ps1 file"
}

variable "rg_name" {
  type    = string
  description = "Resource Group name"
  default = "default-rg"
}