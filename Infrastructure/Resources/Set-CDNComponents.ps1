<#

.SYNOPSIS
Set additonal CDN (Content Delivery Network) Components

.DESCRIPTION
Set additional CDN (Content Delivery Network) Components

.PARAMETER Source
The source location of the files to be copied

.PARAMETER Destination
The blob destinaton of where to copy the files

.PARAMETER SaSToken
The SaS Token to access the blob storage container

.PARAMETER StorageAccountName
The StorageAccountName to apply the CORS settings

.PARAMETER CDNProfileResourceGroup
The Resource Group of the CDN

.PARAMETER CDNProfileName
The CDN Profile Name

.PARAMETER CDNEndPointName
The CDN EndPoint Name

.PARAMETER PurgeContent
The content to purge

.EXAMPLE
$DeploymentParameters = @ {
    Source = "c:\FilesToBeCopied\"
    Destination = "https://name.blob.core.windows.net/cdn"
    SaSToken = "MySecureSaStokenString"
    StorageAccountName = "mystorageaccountname"
    CDNProfileResourceGroupName = "cdn"
    CDNProfileName = "myprofile01"
    CDNEndPointName = "myendpoint01"
    PurgeContent = "/*"
}
.\Set-CDNComponents.ps1 @DeploymentParameters -EnableCORS

#>
# ---- Copy CDN content to blob storage and set MIME settings
Param(
    [Parameter(Mandatory = $true)]
    [String]$Source,
    [Parameter(Mandatory = $true)]
    [String]$Destination,
    [Parameter(Mandatory = $true)]
    [String]$SaSToken,
    [Parameter(Mandatory = $true)]
    [String]$StorageAccountName,
    [Parameter(Mandatory = $true)]
    [String]$CDNProfileResourceGroup,
    [Parameter(Mandatory = $true)]
    [String]$CDNProfileName,
    [Parameter(Mandatory = $true)]
    [String]$CDNEndPointName,
    [Parameter(Mandatory = $false)]
    [String]$PurgeContent = "",
    [Parameter(Mandatory = $true)]
    [ValidateSet("Storage", "Cloud Service", "Web App", "Custom Origin")]
    [String]$OriginType,
    [Parameter(Mandatory = $false)]
    [switch]$EnableCORS

)
# --- Import Azure Helpers
Import-Module (Resolve-Path -Path $PSScriptRoot\..\Modules\CDNHelpers.psm1).Path
Import-Module (Resolve-Path -Path $PSScriptRoot\..\Modules\Helpers.psm1).Path

# ---- Set BlobCopy Deployment Parameters
$DeploymentParameters = @{
    Source      = $Source
    Destination = $Destination
    SaSToken    = $SaSToken
    OriginType  = $OriginType
}
try {
    # ---- Run BlobCopy Function
    Start-BlobCopy @DeploymentParameters
}
catch {
    throw "Failed to copy content to blob and set MIME settings: $_"
}

# ---- Set CORS Deployment Parameters
$DeploymentParameters = @{
    StorageAccountName = $StorageAccountName
    SaSToken           = $SaSToken
    }
try {
    # ---- Run CORS Function
    Enable-CORS @DeploymentParameters
}
catch {
    throw "Failed to get Storage Context and set CORS settings: $_"
}
# ---- Set PurgeContent Deployment Parameters
$DeploymentParameters = @{
    CDNProfileResourceGroup = $CDNProfileResourceGroup
    CDNProfileName          = $CDNProfileName
    CDNEndPointName         = $CDNEndPointName
    PurgeContent            = $PurgeContent
}

try {
    # ---- Run PurgeContent Function
    Start-ContentPurge @DeploymentParameters
}
catch {
    throw "Failed to fetch CDN Endpoint and Purge Content: $_"
}

