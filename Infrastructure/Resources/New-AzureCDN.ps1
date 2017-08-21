Param(
	[ValidateSet("West Europe", "North Europe")]
    [String]$Location = $ENV:Location,
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [String]$ResourceGroupName = $ENV:ResourceGroup,
    [Parameter(Mandatory = $true)]
    [String]$CDNProfileName,
    [Parameter(Mandatory = $true)]
    [String]$CDNEndpointName,
    [Parameter(Mandatory = $false)]
    [String]$CustomDomain,
    [Parameter(Mandatory = $false)]
    [String]$Sku = "Standard_Verizon",
    [Parameter(Mandatory = $true)]
    [String]$CDNStorageAccountName
)


$CDNStorage = Get-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName -Name $CDNStorageAccountName

if(!$CDNStorage){
    throw "CDN Storage Account does not exist"
}



New-AzureRmCdnProfile -ProfileName $CDNProfileName -Location $Location -Sku $Sku -ResourceGroupName $ResourceGroupName


New-AzureRmCdnEndpoint -EndpointName $CDNEndpointName -ProfileName $CDNProfileName -ResourceGroupName $ResourceGroupName -Location $Location `
                            -OriginName $CDNStorageAccountName -OriginHostName "$($CDNStorageAccountName).blob.core.windows.net" -IsCompressionEnabled $true `
                            -ContentTypesToCompress "text/plain","text/html","text/css","text/javascript","application/x-javascript","application/javascript","application/json","application/xml" `
                            -IsHttpAllowed $false -OriginHostHeader "$($CDNStorageAccountName).blob.core.windows.net"
