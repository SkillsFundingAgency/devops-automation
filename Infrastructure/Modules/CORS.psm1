function CORS {
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

.EXAMPLE

$CORSParameters = @ {
    StorageAccountName = "mystorageaccountname"
    SaSToken = "MySecureSaStokenString"

}
CORS @CORSParameters

#>
    Param(
        [Parameter(Mandatory = $true)]
        [String]$storageAccountName,
        [Parameter(Mandatory = $true)]
        [String]$SaSToken
    )

    try {
        # --- Set CORS Rules
        $CorsRules = (@{
                AllowedHeaders  = @("*");
                AllowedOrigins  = @("*");
                MaxAgeInSeconds = 3600;
                AllowedMethods  = @("Get")
            })
        Write-Log -LogLevel Information -Message "Setting Storage Context and applying CORS settings"
        $StorageContext = New-AzureStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $SaSToken
        Set-AzureStorageCORSRule -ServiceType Blob -CorsRules $CorsRules -Context $StorageContext
    }
    catch {
        throw "Failed to get Storage Context and set CORS settings: $_"
    }
}
