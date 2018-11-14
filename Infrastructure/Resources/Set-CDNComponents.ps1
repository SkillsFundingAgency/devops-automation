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
.\Set-CDNComponents.ps1 @DeploymentParameters

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
    [Parameter(Mandatory = $true)]
    [String]$PurgeContent
)
# --- Import Azure Helpers
Import-Module (Resolve-Path -Path $PSScriptRoot\..\Modules\BlobCopy.psm1).Path
Import-Module (Resolve-Path -Path $PSScriptRoot\..\Modules\CORS.psm1).Path
Import-Module (Resolve-Path -Path $PSScriptRoot\..\Modules\PurgeContent.psm1).Path
Import-Module (Resolve-Path -Path $PSScriptRoot\..\Modules\Helpers.psm1).Path

# ---- Set BlobCopy Deployment Parameters
$DeploymentParameters = @{
    Source      = $Source
    Destination = $Destination
    SaSToken    = $SaSToken
}
# ---- Run BlobCopy Function
BlobCopy @DeploymentParameters

# ---- Set CORS Deployment Parameters
$DeploymentParameters = @{
    StorageAccountName = $StorageAccountName
    SaSToken           = $SaSToken
}
# ---- Run CORS Function
CORS @DeploymentParameters

# ---- Set PurgeContent Deployment Parameters
$DeploymentParameters = @{
    CDNProfileResourceGroup = $CDNProfileResourceGroup
    CDNProfileName  = $CDNProfileName
    CDNEndPointName = $CDNEndPointName
    PurgeContent = $PurgeContent
}
# ---- Run PurgeContent Function
PurgeContent @DeploymentParameters




