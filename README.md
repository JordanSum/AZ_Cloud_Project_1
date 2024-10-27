# Powershell Script and Terraform For Azure Using Virtual Machine and Keyvault.

This Powwershell and Terraform project is designed to create a comprehensive and secure Azure infrastructure. The infrastructure components include a Virtual Machine (VM), Virtual Network, Network Security Group (NSG) a pre-made KeyVault to store the public SSH key, and other related resources. The deliverable will be a secure connection using a RSA key pair and allowing only a certain public IP address to access the VM hosted in Azure.

## Table of Contents

- [Powershell Script and Terraform For Azure Using Virtual Machine and Keyvault.](#powershell-script-and-terraform-for-azure-using-virtual-machine-and-keyvault)
  - [Table of Contents](#table-of-contents)
  - [Project Overview](#project-overview)
  - [Pre-Requisites](#pre-requisites)
  - [Components](#components)
    - [SSH-KeyGen](#ssh-keygen)
    - [VM (Virtual Machine)](#vm-virtual-machine)
    - [VNet (Virtual Network) w/ NSG (Network Security Group)](#vnet-virtual-network-w-nsg-network-security-group)
    - [KeyVault](#keyvault)
  - [Usage](#usage)
  - [Please...](#please)


## Project Overview

This project automates the deployment of an Azure infrastructure using Powershell and Terraform. It covers the essential components needed to deploy and manage a secure and maintainable environment. The primary focus is on deploying a VM with KeyVault to allow a secure connection from the local host using SSH-Keygen.

> [!WARNING]  
> This is a development project and should NOT be used for production. Please use best policy and security when deploying this project

## Pre-Requisites

The following is needed in order to execute this project:

- Azure account
- AZ CLI
- Azure KeyVault

## Components

### SSH-KeyGen

You will need to run to following SSH command, provided in the env.ps1 script, to generate a RSA key pair. The private key will be stored on the local host and the public key will be stored in Azure KeyVault.

```Powershell
ssh-keygen.exe -t rsa -b 2048 -f $PrivateKeyPath -q -N $Passphrase
```

### VM (Virtual Machine)

VM is a software-based emulation of a physical computer. It runs on a physical server in a data center and provides the same functionality as a physical machine. This can be used for develiopment and testing, application hosting, data centers, and host legacy applications

### VNet (Virtual Network) w/ NSG (Network Security Group)

Imagine having your own private network in the cloud! Well that is what VNet is in Azure. It allows Azure resources like VM to securely communicate with each other, the internet, and on-premises networks. A NSG is a set of security rules that allow or deny inbound and outbound network traffic to and from Azure resources within a VNet.  The primary purpose of the NSG for this project is to only allow the public IP source (Local Host) to connect to the VM.

### KeyVault

KeyVault is used to store keys, secrets, and certificates.  For the purpose of this project KeyVault will be used to store the Public Key generated for the ssh-keygen command that is ran at the begining of the project.

> [!NOTE]  
When deploying the resources in PowerShell you will get a message stating:  
>
>WARNING: No access was given yet to the 'VM-test', because '--scope' was not provided. You should setup by creating a role assignment, e.g. 'az role assignment create --assignee <principal-id> --role contributor -g RG-test' would let it access the current resource group. To get the pricipal id, run 'az vm show -g RG-test -n VM-test --query "identity.principalId" -otsv'
>
>Ignore this warning. The following command will show the assigned role to your VM to retrieve the public key.

```powershell
$roleAssignmentResult = az role assignment create --assignee $principalId --role "Key Vault Secrets User" --scope $Scope

if ($roleAssignmentResult) {
    
    Write-Host "Role assigned successfully."
} else {
    Write-Error "Failed to assign role."
}
```


> [!IMPORTANT]  
> In this project a KeyVault has already been created.  You can completed the provisioning of KeyVault in the Azure Portal. Please refer to Microsoft Azure documentation to complete this task.

## Usage

To use this project, clone the repository and configure the Powershell and Terraform variables according to your environment. Then, apply the variables configuration file to provision the resources in your Powershell or Terraform script.

> [!NOTE]  
Make sure you are in either the PS or Terraform directory to provision one of the infrastructure resources.

## Please...

If any additional fixes or changes are found within this project, please pass them along respectfully.  I am always looking to advance my knowledge and apply best practices.