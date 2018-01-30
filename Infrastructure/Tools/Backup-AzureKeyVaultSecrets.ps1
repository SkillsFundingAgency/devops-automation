<#
.SYNOPSIS
Backs up All KeyVault Secrets
.DESCRIPTION
Backs up All KeyVault Secrets to specified file  
.PARAMETER BackupPath
The location of the Backup Files. 
.EXAMPLE
.\Backup-AzureKeyVaultSecrets.ps1 -Location c:\temp\Backup\
#>

Param (
    [Parameter(Mandatory = $false)]
    [String]$BackupPath
)

# --- Import Azure Helpers
Import-Module (Resolve-Path -Path $PSScriptRoot\..\Modules\Azure.psm1).Path
Import-Module (Resolve-Path -Path $PSScriptRoot\..\Modules\Helpers.psm1).Path

# --- Set backup Ptah if not passed as a paramater
If ($BackupPath -eq $null) {
    $BackupPath = (get-location).Drive.Name + ":\temp\Backup\"
}

# --- Enumerate Subscriptions
$Subscriptions = Get-AzureRmSubscription
ForEach ($Subscription in $Subscriptions) {
    Set-AzureRmContext -SubscriptionName $Subscription.Name
    # --- Enumerate Resource Groups for that subscription
    $ResourceGroups = Get-AzureRmResourceGroup   
    ForEach ($ResourceGroup in $ResourceGroups) {
        # --- Get all KeyVaults for the Resource Group
        $KeyVaults = Get-AzureRmResource -ResourceGroupName $ResourceGroup.ResourceGroupName -ResourceType Microsoft.KeyVault/vaults
        If ($KeyVaults -ne $null ) {
            # --- Retrieve all Secrets from KeyVault
            ForEach ($KeyVault in $KeyVaults) {
                $Secrets = Get-AzureKeyVaultSecret -VaultName $KeyVault.Name 
                ForEach ($Secret in $Secrets) {
                    $SecretName = $Secret.Name
                    # --- Backup Secrets
                    Backup-AzureKeyVaultSecret -VaultName $KeyVault.Name -Name $Secret.Name -OutputFile $BackupPath$SecretName".blob" -force
                    Write-Log -LogLevel Information -Message "Backed up "$BackupPath$SecretName".blob from " $KeyVault.Name 
                }
            }
        }
    }
}
