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
$SelectedKeyVaultResourceGroup = $keyVaults[$selection].ResourceGroup

# Prompt the user which key vault was selected
Write-Host "Selected Key Vault: $KeyVaultName"

$KVSecretName= Read-Host "Enter the name of the secret to store the public key in the Key Vault"
$resourcegroup = Read-Host "Enter the name of the resource group of your envirornment"

# Upload the public key to Azure Key Vault as a secret
az keyvault secret set --vault-name $KeyVaultName --name $KVSecretName --value $PublicKey

# Export the selected Key Vault and resource group as environment variables
$env:TF_VAR_key_vault_name = $KeyVaultName
$env:TF_VAR_key_vault_rg = $SelectedKeyVaultResourceGroup
$env:TF_VAR_ssh_public_key_secret_name = $KVSecretName
$env:TF_VAR_rg_name = $resourcegroup


# Apply Terraform configuration with auto-approve
terraform apply -auto-approve