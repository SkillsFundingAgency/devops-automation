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

.PARAMETER ServicePrincipalObjectId
Object ID of the Service principal that can access the KeyVault

.PARAMETER SecretName
Name of the secret to add

.PARAMETER SecretValue
Value of the secret to add

.EXAMPLE

#>
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $false)]
    [ValidateSet("West Europe", "North Europe")]
    [String]$Location = $ENV:Location,
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [String]$ResourceGroupName = $ENV:ResourceGroup,
    [Parameter(Mandatory = $true)]
    [String]$Name,
    [Parameter(Mandatory = $true)]
    [String]$ServicePrincipalObjectId,
    [Parameter(Mandatory = $true)]
    [String]$SecretName,
    [Parameter(Mandatory = $true)]
    [String]$SecretValue
)

# --- Import Azure Helpers
Import-Module (Resolve-Path -Path $PSScriptRoot\..\Modules\Azure.psm1).Path
Import-Module (Resolve-Path -Path $PSScriptRoot\..\Modules\Helpers.psm1).Path

$DeploymentParams = @{
    ResourceGroupName        = $ResourceGroupName
    TemplateFile             = "$PSScriptRoot\ARM-Templates\keyvault.json"
    keyVaultName             = $Name
    servicePrincipalObjectId = $ServicePrincipalObjectId
    secretName               = $SecretName
    secretValue              = $SecretValue
}
$DeploymentOutput = New-AzureRmResourceGroupDeployment @DeploymentParams
$KeyVaultUri = $DeploymentOutput.Outputs.keyVaultUri.Value
if ($KeyVaultUri) {
    Write-Output ("##vso[task.setvariable variable=KeyVaultUri;]$($KeyVaultUri)")
}
