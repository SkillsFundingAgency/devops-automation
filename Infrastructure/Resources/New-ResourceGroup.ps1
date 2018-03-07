<#

.SYNOPSIS
Create a Resource Group

.DESCRIPTION
Create a Resource Groups in a geographical location

.PARAMETER Location
The location of the Resource Group. This is limited to West Europe and North Europe

.PARAMETER Name
The name of the Resource Group

.PARAMETER ContributorGroups
One or more groups that will be assigned as contributors

.PARAMETER ReaderGroups
One or more groups that will be assigned as readers

.EXAMPLE
.\New-ResourceGroup.ps1 -Name arm-rg-01 -Location "West Europe"

.EXAMPLE
.\New-ResourceGroup.ps1 -Name arm-rg-01 -Location "West Europe" -ContributorGroups "Group1","Group2"

#>
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $true)]
    [ValidateSet("West Europe", "North Europe")]
    [String]$Location,
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [String]$Name,
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [String[]]$ContributorGroups,
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [String[]]$ReaderGroups
)

# --- Import Azure Helpers
Import-Module (Resolve-Path -Path $PSScriptRoot\..\Modules\Azure.psm1).Path
Import-Module (Resolve-Path -Path $PSScriptRoot\..\Modules\Helpers.psm1).Path

function Add-Group {
    Param(
        [Parameter(Mandatory = $true)]
        [String]$ResourceGroupName,
        [Parameter(Mandatory = $true)]
        [String]$GroupName,
        [Parameter(Mandatory = $true)]
        [ValidateSet("Contributor", "Role")]
        [String]$Role
    )
    try {
        $AADGroupId = (Get-AzureRmADGroup -SearchString $ContributorGroup).Id
        if (!$AADGroupId) {
            throw "Could not find Group $GroupName"
        }
        $ExistingRoleAssignment = Get-AzureRmRoleAssignment -ResourceGroupName $ResourceGroupName -ObjectId $AADGroupId
        if (!$ExistingRoleAssignment){
            $null = New-AzureRmRoleAssignment -ResourceGroupName $ResourceGroupName -RoleDefinitionName $Role -ObjectId $AADGroupId
        }
    } catch {
        throw "$_"
    }
}

try {
    Write-Log -LogLevel Information -Message "Checking for existing Resource Group $Name"
    $ExistingResourceGroup = Get-AzureRmResourceGroup -Name $Name -ErrorAction SilentlyContinue

    if (!$ExistingResourceGroup) {
        try {
            Write-Log -LogLevel Information -Message "Creating Resource Group"
            $null = New-AzureRmResourceGroup -Location $Location -Name $Name
        }
        catch {
            throw "Could not create Resource Group $Name : $_"
        }
    }

    # --- Add role assignments to resource group
    foreach ($ContributorGroup in $ContributorGroups){
        Write-Log -LogLevel Information -Message "Adding group $ContributorGroup as a Contributor"
        Add-Group -ResourceGroupName $Name -GroupName $ContributorGroup -Role Contributor
    }

    foreach ($ReaderGroup in $ReaderGroups){
        Write-Log -LogLevel Information -Message "Adding group $ReaderGroup as a Reader "
        Add-Group -ResourceGroupName $Name -GroupName $ReaderGroup -Role Contributor
    }

    Write-Output ("##vso[task.setvariable variable=ResourceGroup;]$Name")
    Write-Output ("##vso[task.setvariable variable=Location;]$Location")

} catch {
    throw "$_"
}
