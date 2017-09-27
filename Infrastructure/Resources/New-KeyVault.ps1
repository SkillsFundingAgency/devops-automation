<#

.SYNOPSIS
Create a Keyvault and access policies and optionally add secrets

.DESCRIPTION
Create a Keyvault and access policies and optionally add secrets

.PARAMETER Location
The location of the Resource Group. This is limited to West Europe and North Europe

.PARAMETER ResourceGroupName
The name of the destination Resource Group for the resource

.PARAMETER Name
The name of Keyvault

.PARAMETER SPObjectId
Object ID of the Service principal that can access the KeyVault

.PARAMETER SecretName
Name of the secret to add

.PARAMETER SecretValue
Value of the secret to add

.EXAMPLE

#>
[CmdletBinding(DefaultParameterSetName = "standard")]
Param (
    [Parameter(Mandatory = $false)]
    [ValidateSet("West Europe", "North Europe")]
    [String]$Location = $ENV:Location,
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [String]$ResourceGroupName = $ENV:ResourceGroup,	
    [Parameter(Mandatory = $true)]
    [String]$Name,
    [Parameter(Mandatory = $false)]
    [String]$SPObjectId,
    [Parameter(ParameterSetName = "secret", Mandatory = $true)]
    [String]$SecretName,
    [Parameter(ParameterSetName = "secret", Mandatory = $true)]
    [String]$SecretValue
)

# --- Import Azure Helpers
Import-Module (Resolve-Path -Path $PSScriptRoot\..\Modules\Azure.psm1).Path
Import-Module (Resolve-Path -Path $PSScriptRoot\..\Modules\Helpers.psm1).Path

Write-Log -Message "Searching for existing KeyVault" -LogLevel Verbose
$KeyVault = Get-AzureRmKeyVault -VaultName $Name -ResourceGroupName $ResourceGroupName

if (!$KeyVault) {
    Write-Log -Message "Creating new KeyVault $($Name) in $($ResourceGroupName)" -LogLevel Information
    $KeyVault = New-AzureRmKeyVault -VaultName $Name -ResourceGroupName $ResourceGroupName -Location $Location    
}

if ($SPObjectId) {
    Write-Log -Message "Checking access policies for specified Object ID" -LogLevel Verbose
    if (!($KeyVault.AccessPolicies | Where-Object {$_.ObjectId -eq $SPObjectId})) {
        Write-Log -Message "Setting new access policy" -LogLevel Information
        Set-AzureRmKeyVaultAccessPolicy -VaultName $KeyVault.VaultName -ResourceGroupName $KeyVault.ResourceGroupName -ObjectId $SPObjectId -PermissionsToSecrets get
    }
}

if ($PSCmdlet.ParameterSetName -eq "secret") {
    Write-Log -Message "Checking for existing secret" -LogLevel Verbose
    $Secret = Get-AzureKeyVaultSecret -VaultName $KeyVault.VaultName -Name $SecretName
    if(!$Secret){
        Write-Log -Message "Adding secret to keyvault" -LogLevel Information
        $SecretPassword = ConvertTo-SecureString -String $SecretValue -AsPlainText -Force
        $null = Set-AzureKeyVaultSecret -VaultName $KeyVault.VaultName -Name $SecretName -SecretValue $SecretPassword
    }
}

Write-Output ("##vso[task.setvariable variable=KeyVaultUri;]$($KeyVault.VaultUri)")