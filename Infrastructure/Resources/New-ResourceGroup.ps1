<#

.SYNOPSIS
Create a Resource Group

.DESCRIPTION
Create a Resource Groups in a geographical location

.PARAMETER Location
The location of the Resource Group. This is limited to West Europe and North Europe

.PARAMETER Name
The name of the Resource Group

.EXAMPLE
.\New-ResourceGroup.ps1 -Name arm-rg-01 -Location "West Europe"

#>

Param (
    [Parameter(Mandatory = $true)]
    [ValidateSet("West Europe", "North Europe")]
    [String]$Location,
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [String]$Name
)

# --- Import Azure Helpers
Import-Module (Resolve-Path -Path $PSScriptRoot\..\Modules\Azure.psm1).Path

Write-Host "Checking for existing Resource Group $Name"			 
$ExistingResourceGroup = Get-AzureRmResourceGroup -Name $Name -ErrorAction SilentlyContinue

if (!$ExistingResourceGroup) {
    try {
        Write-Host "Creating Resource Group"
        $null = New-AzureRmResourceGroup -Location $Location -Name $Name
    }
    catch {
        throw "Could not create Resource Group $Name : $_"
    }
}

Write-Output ("##vso[task.setvariable variable=ResourceGroup;]$Name")
Write-Output ("##vso[task.setvariable variable=Location;]$Location")