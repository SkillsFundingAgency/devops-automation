<#

.SYNOPSIS
Set additonal CDN (Content Delivery Network) Components

.DESCRIPTION
Set additional CDN (Content Delivery Network) Components

.PARAMETER Source
The source location of the files to be copied

.PARAMETER Destination
The blob destinaton of where to copy the files

.PARAMETER AccessKey
The Access Key to access the blob storage container

.PARAMETER OriginType
The Origin Type i.e. "Storage", "Cloud Service", "Web App" or "Custom Origin"

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

.PARAMETER EnableCORS
The EnableCORS switch parameter, if specified at run time then Enable-CORS function will run

.EXAMPLE
$DeploymentParameters = @ {
    Source = "c:\FilesToBeCopied\"
    Destination = "https://name.blob.core.windows.net/cdn"
    AccessKey = "MySecureAccessKeyString"
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
    [Parameter(Mandatory = $false)]
    [String]$AccessKey,
    [Parameter(Mandatory = $false)]
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
    AccessKey   = $AccessKey
    OriginType  = $OriginType
}
try {
    # ---- Run BlobCopy Function
    if ($OriginType -eq "Storage") {
        Test-AzCopyContentType $Source
        Start-BlobCopy @DeploymentParameters
    }
    else {
        Write-Log -LogLevel Information -Message "Blob copy not required as OriginType set to either 'Cloud Service', 'Web App' or 'Custom Origin'"
    }
}
catch {
    throw "Registry is missing Content Types and failed to copy content to blob and set MIME settings: $_"
}

# ---- Set CORS Deployment Parameters
$DeploymentParameters = @{
    StorageAccountName = $StorageAccountName
    AccessKey          = $AccessKey
}
try {
    # ---- Run CORS Function
    if ($EnableCORS.IsPresent) {
        Enable-CORS @DeploymentParameters
    }
    else {
        Write-Log -LogLevel Information -Message "CORS settings not applied, only required for Development and Testing environments when using Storage Account"
    }
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

