function PurgeContent {
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

.PARAMETER CDNPurgeContent
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
        [Parameter(Mandatory = $true)]
        [String]$PurgeContent
    )

    try {
        # --- Set CDN EndPoint
        Write-Log -LogLevel Information -Message "Setting CDN EndPoint..."
        $CDNEndpoint = Get-AzureRmCdnEndpoint -ResourceGroupName $CDNProfileResourceGroup -ProfileName $CDNProfileName -EndpointName $CDNEndpointName

         # ---> Purging CDN EndPoint
        Write-Log -LogLevel Information -Message "Purging CDN EndPoint..."
        $CDNEndpoint | Unpublish-AzureRmCdnEndpointContent -PurgeContent $PurgeContent -Verbose

        }
    catch {
        throw "Failed to fetch CDN Endpoint and Purge Content: $_"
    }
}
