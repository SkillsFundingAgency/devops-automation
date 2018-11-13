<#

.SYNOPSIS
CDN

.DESCRIPTION
CDN

.PARAMETER Environment
The deployment environment


.EXAMPLE


#>
# ---- Copy CDN content to blob storage and set MIME settings
Param(
    [Parameter(Mandatory = $true)]
    [String]$Source,
    [Parameter(Mandatory = $true)]
    [String]$Destination,
    [Parameter(Mandatory = $true)]
    [String]$SaSToken
)
# --- Import Azure Helpers
Import-Module (Resolve-Path -Path $PSScriptRoot\..\Modules\BlobCopy.psm1).Path
Import-Module (Resolve-Path -Path $PSScriptRoot\..\Modules\Helpers.psm1).Path

$DeploymentParameters = @{
    Source      = $Source
    Destination = $Destination
    SaSToken    = $SaSToken

}

# ---- Run BlobCopy Function
BlobCopy @DeployParameters

# ---- Configure CORS Settings
Param(
    [Parameter(Mandatory = $true)]
    [String]$StorageAccountName,
    [Parameter(Mandatory = $true)]
    [String]$SaSToken
)
# --- Import Azure Helpers
Import-Module (Resolve-Path -Path $PSScriptRoot\..\Modules\CORS.psm1).Path
Import-Module (Resolve-Path -Path $PSScriptRoot\..\Modules\Helpers.psm1).Path

$DeploymentParameters = @{
    StorageAccountName = $StorageAccountName
    SaSToken           = $SaSToken
}

# ---- Run CORS Function
CORS @DeploymentParameters




