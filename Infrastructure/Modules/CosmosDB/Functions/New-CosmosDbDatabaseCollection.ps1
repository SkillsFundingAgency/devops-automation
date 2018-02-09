function New-CosmosDbDatabaseCollection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $ResourceGroupName,
        [Parameter(Mandatory = $true)]
        $CosmosDbAccountName,
        [Parameter(Mandatory = $true)]
        $DatabaseName,
        [Parameter(Mandatory = $true)]
        $CollectionName
    )

    $masterKey = Get-CosmosDbMasterKey -ResourceGroupName $ResourceGroupName -CosmosDbAccountName $CosmosDbAccountName
    $authorizationHeader = New-CosmosDbAuthHeader -Verb "POST" -ResourceType "colls" -ResourceId "dbs/$DatabaseName" -Key $masterKey

    $headers = @{
        "Authorization"   = $authorizationHeader
        "x-ms-version"    = "2017-02-22"
        "x-ms-date"       = "$([System.DateTime]::UtcNow.ToString("R"))"
        "Content-Type"    = "application/json"
        "x-ms-offer-type" = "S1"
    }

    $body = @{
        "id" = $CollectionName
    }

    try {
        $response = Invoke-WebRequest -Uri "https://$($CosmosDbAccountName).documents.azure.com/dbs/$DatabaseName/colls" -Method POST -Headers $headers -Body ($body | ConvertTo-Json)
        Write-Host $response.StatusDescription
    }
    catch {
        $_.Exception
        $Result = $_.Exception.Response.GetResponseStream()
        $Reader = New-Object System.IO.StreamReader($result)
        $Reader.ReadToEnd();
    }
}
