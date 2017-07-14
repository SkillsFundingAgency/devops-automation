<#

.SYNOPSIS
Move a Resource to a new Resource Group

.DESCRIPTION
Move one or more resources to a new Resource Group and remove their source Resource Groups

.PARAMETER ResourceName
The names of one or more resources to move

.PARAMETER DestinationResourceGroup
The name of the destination Resource Group

.EXAMPLE
.\Move-Resource.ps1 -ResourceName cloud-service-01 -DestinationResourceGroup arm-rg-01

.EXAMPLE
.\Move-Resource.ps1 -ResourceName cloud-service-01,cloud-service-02 -DestinationResourceGroup arm-rg-01

#>

Param (
    [Parameter(Mandatory = $true)]
    [String[]]$ResourceName,
    [Parameter(Mandatory = $true)]
    [String]$DestinationResourceGroup
)

# --- Import Azure Helpers
Import-Module (Resolve-Path -Path $PSScriptRoot\..\Modules\Azure.psm1).Path

foreach ($Resource in $ResourceName) {

    $AzResource = Find-AzureRmResource -ResourceNameContains $Resource -ErrorAction SilentlyContinue

    # --- Double check that NewCloudService is valid
    if ($AzResource.Count -gt 1 -or $AzResource.Count -eq 0) {
        throw "Find-AzureRmResource has returned $($AzResource.Count) result(s).. check the value of ResourceNameContains"
    }

    # --- Check if the Storage Account exists in the correct resource group, if not move it
    if ($AzResource.ResourceGroupName.ToLower() -ne $DestinationResourceGroup.ToLower()) {
        try {
            Write-Host "Moving Resource $Resource to Resource Group $DestinationResourceGroup"
            $null = Move-AzureRmResource -DestinationResourceGroupName $DestinationResourceGroup -ResourceId $AzResource.ResourceId -Force
            Wait-AzureRmResource -ResourceGroupName $DestinationResourceGroup -ResourceName $Resource

            $Resources = Find-AzureRmResource -ResourceGroupNameContains $AzResource.ResourceGroupName
            if ($Resources.Count -eq 0) {
                Write-Host "Removing source Resource Group $($AzResource.ResourceGroupName)"
                $null = Remove-AzureRmResourceGroup -Name $AzResource.ResourceGroupName -Force
            }
        }
        catch {
            throw "Could not move Resource $Resource : $_"
        }
    }
}