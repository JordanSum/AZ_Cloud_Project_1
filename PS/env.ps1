. .\env-var.ps1

# Prompt the user to enter the password for the SSH key pair
$securePassphrase = Read-Host "Enter a passphrase for the SSH key pair" -AsSecureString

# Convert the secure string to plain text for use in ssh-keygen
$Passphrase = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassphrase))

# Prompt the user to enter the path to store the private key file on there local host
$PrivateKeyPath = Read-Host "Enter the path to your private key file on local host, include what the file name should be"

# Generate an SSH Key Pair
ssh-keygen.exe -t rsa -b 2048 -f $PrivateKeyPath -q -N $Passphrase

# Read the public key and store it in a variable
$PublicKey = Get-Content -Path "$PrivateKeyPath.pub" -Raw

# List all Key Vaults in the subscription
$keyVaults = az keyvault list --query "[].{Name:name, ResourceGroup:resourceGroup}" -o json | ConvertFrom-Json

# Check if any Key Vaults were found
if ($keyVaults.Count -eq 0) {
    Write-Error "No Key Vaults found in the subscription."
    exit 1
}

# Display the list of Key Vaults with corresponding numbers
Write-Host "Available Key Vaults:"
for ($i = 0; $i -lt $keyVaults.Count; $i++) {
    Write-Host "$i. $($keyVaults[$i].Name) (Resource Group: $($keyVaults[$i].ResourceGroup))"
}

# Prompt the user to select a Key Vault by entering the corresponding number
$selection = Read-Host "Enter the number of the Key Vault you want to use"

# Validate the user's selection
if ($selection -lt 0 -or $selection -ge $keyVaults.Count) {
    Write-Error "Invalid selection. Please enter a valid number."
    exit 1
}

# Retrieve the selected Key Vault name
$KeyVaultName = $keyVaults[$selection].Name

# Prompt the user which key vault was selected
Write-Host "Selected Key Vault: $KeyVaultName"

# Upload the public key to Azure Key Vault as a secret
az keyvault secret set --vault-name $KeyVaultName --name $KVSecretName --value $PublicKey

# Retrieve the public SSH key from Azure Key Vault to use for VM creation
$RetrievedPublicKey = az keyvault secret show --vault-name $KeyVaultName --name $KVSecretName --query value -o tsv

# Create a Resource Group
az group create -n $RGname --location westus2

# Create a Network Security Group
az network nsg create -g $RGname -n $NSGname

# Prompt the user to enter the Public IP Address of their local machine
$securePublicIP = Read-Host "Enter the Public IP Address of your local machine to gian access to your VM" -AsSecureString

# Convert the secure string to plain text for public IP address
$PublicIP = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePublicIP))

# Define the NSG and open port 22 to the VM
az network nsg rule create `
    -g $RGname `
    --nsg-name $NSGname `
    -n allow-SSH `
    --priority 1000 `
    --source-address-prefixes $PublicIP `
    --destination-port-ranges 22 `
    --protocol TCP

# Prompt the user to enter the username for the VM
$VMUsername = Read-Host "Enter the username for the VM"

# Create a VM and enable system-assigned managed identity
$vm = az vm create `
    --name $VMname `
    --resource-group $RGname `
    --zone 2 `
    --size $VMsize `
    --ssh-key-value $RetrievedPublicKey `
    --image $VMimage `
    --nsg $NSGname `
    --assign-identity `
    --admin-username $VMUsername `
    --query "{identity: identity}" -o json | ConvertFrom-Json

# Debugging: Print the $vm object, uncomment the line below to see the output
#$vm | ConvertTo-Json | Write-Output

# Check if VM creation was successful
if ($null -eq $vm) {
    Write-Error "VM creation failed."
    exit 1
}

# Extract the systemAssignedIdentity (principalId) of the VM managed identity
$principalId = az vm show --resource-group $RGname --name $VMname --query "identity.principalId" -o tsv

# Extrace the subscription ID for the Azure account
$SubscriptionId = az account show --query "id" -o tsv # Dynamically get the subscription ID

# Extract the scope for the resource group
$Scope = "/subscriptions/$SubscriptionId/resourceGroups/$RGname"

# Assign Contributor role to the managed identity with resource group scope
az role assignment create --assignee $principalId --role "Key Vault Secrets User" --scope $Scope

# Retrieve the assigned role information into a variable
$roleAssignmentResult = az role assignment create --assignee $principalId --role "Key Vault Secrets User" --scope $Scope

if ($roleAssignmentResult) {
    Write-Host "Role assigned successfully."
} else {
    Write-Error "Failed to assign role."
}

# Debugging: Print the principal ID and scope information, uncomment the lines below to see the output
#Write-Host "Principal ID: $principalId"
#Write-Host "Scope: $Scope"

# Prompt the user to choose whether to auto-restart or leave the machines off
$RESTART_OPTION = Read-Host "Do you want to auto-restart the machine? (y/n)"

# Set the auto-shutdown and auto-start properties based on the user's choice
if ($RESTART_OPTION -eq "y") {
    $AUTO_SHUTDOWN = $true
    $AUTO_START = $true
} else {
    $AUTO_SHUTDOWN = $true
    $AUTO_START = $false
}

# Set the auto-shutdown properties for the VM
if ($AUTO_SHUTDOWN) {
    $ShutdownTime = Read-Host "Enter the time to auto-shutdown the VM (HH:MM) in UTC"
}
az vm auto-shutdown `
    -g $RGname `
    -n $VMname `
    --time $ShutdownTime

# Set the auto-start properties for the VM if chosen
if ($AUTO_START) {
    az vm start -g $RGname -n $VMname --no-wait
}

# Get the public IP of the VM
$VMPublicIP = az vm show -d -g $RGname -n $VMname --query publicIps -o tsv

Write-Host "Environment Complete"
# Display the public IP of the VM to use in SSH. Uncomment the line below to see the output
#Write-Host "VM Public IP: $VMPublicIP"
# Display the role assignment result. Uncomment the line below to see the output
#Write-Host "Role Assignment Result $roleAssignmentResult"

<# In order to connect to your VM, use the following command:
cd File\Path\To\Your\Private\Key\On\Local\Host *windowsOS* -Do not add the file name
ssh -i "PrivateKeyFileName" username@VMpublicIP
#>

#To manually stop and start the VM, use the following commands:
#az vm stop -g <Resource-Name> -n <VM-Name>
#az vm start -g <Resource-Name> -n <VM-Name>