<#

.SYNOPSIS
Set additonal CDN Components

.DESCRIPTION
Set additional CDN Components

.PARAMETER Source
The source location of the files to be copied

.PARAMETER Destination
The blob destinaton of where to copy the files

.PARAMETER SaSToken
The SaS Token to access the blob storage container

.PARAMETER StorageAccountName
The StorageAccountName to apply the CORS settings

.EXAMPLE
$DeploymentParameters = @ {
    Source = "c:\FilesToBeCopied\"
    Destination = "https://name.blob.core.windows.net/cdn"
    SaSToken = "MySecureSaStokenString"
    StorageAccountName = "mystorageaccountname"
    ResourceGroupName = "cdn"
    ProfileName = "myprofile01"
    EndPointName = "myendpoint01"
    PurgeContent = "/*"
}
.\Set-CDN-Components.ps1 @DeploymentParameters

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
    [String]$ResourceGroupName,
    [Parameter(Mandatory = $true)]
    [String]$ProfileName,
    [Parameter(Mandatory = $true)]
    [String]$EndPointName,
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
    ResourceGroupName = $ResourceGroupName
    ProfileName  = $ProfileName
    EndPointName = $EndPointName
    PurgeContent = $PurgeContent
}
# ---- Run PurgeContent Function
PurgeContent @DeploymentParameters




