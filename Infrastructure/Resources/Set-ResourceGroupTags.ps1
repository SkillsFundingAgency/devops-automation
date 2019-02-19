<#
.SYNOPSIS
Sets standard tags on a resource group required by the ESFA.

.DESCRIPTION
Checks if a resource group exists, if it doesn't creates with specified tags.  If it does validates that the tags are match those specified in the parameters and updates them if necessary.
Removed ValidateSet for ParentBusiness and ServiceOffering so it's more generic and there are loads for AS

.PARAMETER ResourceGroupName
Name of the resource group to be created and \ or have tags applied

.PARAMETER Location
[Optional]Location of the resource group, defaults to West Europe

.PARAMETER Environment
Name of the environment, select from a valid ESFA environment name tag: Production, Pre-Production or Dev/Test

.PARAMETER ParentBusiness
Name of the business to which the resources belong, e.g. Apprenticeships, Apprenticeships (PP)

.PARAMETER ServiceOffering
Name of the service offering to which the resources belong, e.g. AS Commitments, AS Commitments (PP)

.EXAMPLE
Set-ResourceGroupTags -ResourceGroupName "das-at-foobar-rg" -Environment "Dev/Test" -ParentBusiness "Apprenticeships" -ServiceOffering "AS Commitments"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    [Parameter(Mandatory = $false)]
    [string]$Location = "West Europe",
    [Parameter(Mandatory = $true)]
    [ValidateSet("Production", "Pre-Production", "Dev/Test")]
    [string]$Environment,
    [Parameter(Mandatory = $true)]
    [string]$ParentBusiness,
    [Parameter(Mandatory = $true)]
    [string]$ServiceOffering
)

$Tags = @{
    Environment        = $Environment
    'Parent Business'  = $ParentBusiness
    'Service Offering' = $ServiceOffering
}

Write-Verbose -Message "Attempting to retrieve existing resource group $ResourceGroupName"
$ResourceGroup = Get-AzureRmResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue

if (!$ResourceGroup) {

    Write-Verbose -Message "Resource group $ResourceGroupName doesn't exist, creating resource group"
    New-AzureRmResourceGroup -Name $ResourceGroupName -Location $Location -Tag $Tags

}
else {

    Write-Verbose -Message "Resource group $ResourceGroupName exists, validating tags"
    $UpdateTags = $false

    if ($ResourceGroup.Tags) {

        # Check existing tags and update if necessary
        $UpdatedTags = $ResourceGroup.Tags
        foreach ($Key in $Tags.Keys) {

            Write-Verbose "Current value of Resource Group Tag $Key is $($ResourceGroup.Tags[$Key])"
            if ($($ResourceGroup.Tags[$Key]) -eq $($Tags[$Key])) {

                Write-Verbose -Message "Current value of tag ($($ResourceGroup.Tags[$Key])) matches parameter ($($Tags[$Key]))"

            }
            elseif ($null -eq $($ResourceGroup.Tags[$Key])) {

                Write-Verbose -Message ("Tag value is not set, adding tag {0} with value {1}" -f $Key, $Tags[$Key])
                $UpdatedTags[$Key] = $Tags[$Key]
                $UpdateTags = $true

            }
            else {

                Write-Verbose -Message ("Tag value is incorrect, setting tag {0} with value {1}" -f $Key, $Tags[$Key])
                $UpdatedTags[$Key] = $Tags[$Key]
                $UpdateTags = $true

            }
        }

    }
    else {

        # No tags to check, just update with the passed in tags
        $UpdatedTags = $Tags
        $UpdateTags = $true

    }

    if ($UpdateTags) {

        Write-Host "Replacing existing tags:"
        $UpdatedTags
        Set-AzureRmResourceGroup -Name $ResourceGroup.ResourceGroupName -Tag $UpdatedTags

    }
}
