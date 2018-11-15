function Start-BlobCopy {
    <#
.SYNOPSIS
Copy content to blob storage and update ContentType(MIME) settings

.DESCRIPTION
Copy content to blob storage and update ContentType(MIME) settings using AzCopy
AzCopy syntax: https://docs.microsoft.com/en-us/azure/storage/common/storage-use-azcopy

.PARAMETER Source
The source location of the files to be copied

.PARAMETER Destination
The blob destinaton of where to copy the files

.PARAMETER SaSToken
The SaS Token to access the blob storage container

.PARAMETER OriginType
The Origin Type i.e. "Storage", "Cloud Service", "Web App" or "Custom Origin"

.EXAMPLE

$DeploymentParameters = @ {
    Source = "c:\FilesToBeCopied\"
    Destination = "https://name.blob.core.windows.net/cdn"
    SaSToken = "MySecureSaStokenString"
    OriginType = "Storage"

}
BlobCopy @DeploymentParameters

#>
    Param(
        [Parameter(Mandatory = $true)]
        [String]$Source,
        [Parameter(Mandatory = $true)]
        [String]$Destination,
        [Parameter(Mandatory = $true)]
        [String]$SaSToken,
        [Parameter(Mandatory = $true)]
        [ValidateSet("Storage", "Cloud Service", "Web App", "Custom Origin")]
        [String]$OriginType
    )
    try {
        if ($OriginType -eq "Storage") {
            # --- Set location for AzCopy.exe
            $AzCopyPath = 'C:\Program Files (x86)\Microsoft SDKs\Azure\AzCopy\'
            if (Test-Path $AzCopyPath ) {
                Write-Log -LogLevel Information -Message "Setting location to Azure Storage AzCopy utility"
                Set-Location -Path $AzCopyPath
            }
            else {
                Write-Log -LogLevel Information -Message "Could not locate Azure Storage AzCopy utility under $AzCopyPath"
            }

            Write-Log -LogLevel Information -Message "Invoking Azure Storage AzCopy utility to upload content and change MIME settings..."
            # ---> Invoke AzCopy.exe for
            .\AzCopy.exe /Source:$Source /Dest:$Destination /DestKey:$SaStoken /NC:10 /Z /V /S /Y /SetContentType
            # ---> Invoke AzCopy.exe for *.woff
            .\AzCopy.exe /Source:$Source /Dest:$Destination /DestKey:$SaStoken /NC:10 /Z /V /Pattern:"*.woff" /SetContentType:"application/font-woff" /S /Y
            # ---> Invoke AzCopy.exe for *.woff2
            .\AzCopy.exe /Source:$Source /Dest:$Destination /DestKey:$SaStoken /NC:10 /Z /V /Pattern:"*.woff2" /SetContentType:"application/font-woff2" /S /Y
        }
        else {
            Write-Log -LogLevel Information -Message "Blob copy not required as OriginType set to either 'Cloud Service', 'Web App' or 'Custom Origin'"
        }
    }
    catch {
        throw "Failed to copy content to blob and set MIME settings: $_"
    }
}

function Enable-CORS {
    <#
.SYNOPSIS
Set CORS settings on blob storage

.DESCRIPTION
Cross-Origin Resource Sharing (CORS) is a mechanism that uses additional HTTP headers to tell a browser
to let a web application running at one origin (domain) have permission to access selected resources from a server at a different origin.
Courtesy: https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS
More Information: https://docs.microsoft.com/en-us/powershell/module/azure.storage/set-azurestoragecorsrule?view=azurermps-6.12.0

.PARAMETER StorageAccountName
The StorageAccountName to apply the CORS settings

.PARAMETER SaSToken
The SaS Token to access the blob storage container

.PARAMETER CORSRules
The CORS Rules to be applied

.EXAMPLE

$DeploymentParameters = @ {
    StorageAccountName = "mystorageaccountname"
    SaSToken = "MySecureSaStokenString"
    $EnableCORS = "Yes"

}
Enable-CORS @DeploymentParameters

#>
    Param(
        [Parameter(Mandatory = $true)]
        [String]$StorageAccountName,
        [Parameter(Mandatory = $true)]
        [String]$SaSToken,
        [Parameter(Mandatory = $true)]
        [ValidateSet("Yes", "No")]
        [string]$EnableCORS
    )
    try {
        # ---- Default CORS Settings
        $CORSRules = (@{
            AllowedHeaders  = @("*");
            AllowedOrigins  = @("*");
            MaxAgeInSeconds = 3600;
            AllowedMethods  = @("Get")
        })
        #    --- Set CORS Rules
        if ( $EnableCORS -eq "No" ) { Write-Log -LogLevel Information -Message "CORS settings not applied, only required for Development and Testing environments"
        }
        else {
            Write-Log -LogLevel Information -Message "Setting Storage Context and applying CORS settings"
            $StorageContext = New-AzureStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $SaSToken
            Set-AzureStorageCORSRule -ServiceType Blob -CorsRules $CORSRules -Context $StorageContext
        }
    }
    catch {
        throw "Failed to get Storage Context and set CORS settings: $_"
    }
}

function Start-ContentPurge {
    <#
.SYNOPSIS
Purges the content from an Azure Content Delivery Network (CDN)

.DESCRIPTION
Purges the content from an Azure Content Delivery Network (CDN)

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
    CDNProfileResourceGroup = "cdn"
    CDNProfileName = "myprofile01"
    CDNEndPointName = "myendpoint01"
    PurgeContent = "/*"
}
PurgeContent @DeploymentParameters

#>
    Param(
        [Parameter(Mandatory = $true)]
        [String]$CDNProfileResourceGroup,
        [Parameter(Mandatory = $true)]
        [String]$CDNProfileName,
        [Parameter(Mandatory = $true)]
        [String]$CDNEndPointName,
        [Parameter(Mandatory = $false)]
        [String]$PurgeContent = ""
    )
    try {
        if ( $PurgeContent -eq "" ) { Write-Log -LogLevel Information -Message "Purge Content not required"
        }
        else {
            # --- Set CDN EndPoint
            Write-Log -LogLevel Information -Message "Setting CDN EndPoint..."
            $CDNEndpoint = Get-AzureRmCdnEndpoint -ResourceGroupName $CDNProfileResourceGroup -ProfileName $CDNProfileName -EndpointName $CDNEndpointName

            # ---> Purging CDN EndPoint
            Write-Log -LogLevel Information -Message "Purging CDN EndPoint..."
            $CDNEndpoint | Unpublish-AzureRmCdnEndpointContent -PurgeContent $PurgeContent
        }
    }
    catch {
        throw "Failed to fetch CDN Endpoint and Purge Content: $_"
    }
}
