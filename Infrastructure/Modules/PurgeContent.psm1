function PurgeContent {
    <#
.SYNOPSIS
Purges the content from an Azure Content Delivery Network (CDN)

.DESCRIPTION
Purges the content from an Azure Content Delivery Network (CDN)

.PARAMETER ResourceGroupName
The Resource Group of the CDN

.PARAMETER ProfileName
The CDN Profile Name

.PARAMETER EndPointName
The CDN EndPoint Name

.PARAMETER PurgeContent
The content to purge

.EXAMPLE

$DeploymentParameters = @ {
    ResourceGroupName = "cdn"
    ProfileName = "myprofile01"
    EndPointName = "myendpoint01"
    PurgeContent = "/*"
}
PurgeContent @DeploymentParameters

#>
    Param(
        [Parameter(Mandatory = $true)]
        [String]$ResourceGroupName,
        [Parameter(Mandatory = $true)]
        [String]$ProfileName,
        [Parameter(Mandatory = $true)]
        [String]$EndPointName,
        [Parameter(Mandatory = $true)]
        [String]$PurgeContent
    )

    try {
        # --- Set CDN EndPoint
        Write-Log -LogLevel Information -Message "Setting CDN EndPoint..."
        $CDNEndpoint = Get-AzureRmCdnEndpoint -ResourceGroupName $ResourceGroupName -ProfileName $ProfileName -EndpointName $EndpointName

         # ---> Purging CDN EndPoint
        Write-Log -LogLevel Information -Message "Purging CDN EndPoint..."
        $CDNEndpoint | Unpublish-AzureRmCdnEndpointContent -PurgeContent $PurgeContent -Verbose

        }
    catch {
        throw "Failed to fetch CDN Endpoint and Purge Content: $_"
    }
}
