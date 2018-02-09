function New-CosmosDbDatabase {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $ResourceGroupName,
        [Parameter(Mandatory = $true)]
        $CosmosDbAccountName,
        [Parameter(Mandatory = $true)]
        $DatabaseName
    )

    $masterKey = Get-CosmosDbMasterKey -ResourceGroupName $ResourceGroupName -CosmosDbAccountName $CosmosDbAccountName
    $authorizationHeader = New-CosmosDbAuthHeader -Verb "POST" -ResourceType "dbs" -ResourceId "" -Key $masterKey

    $headers = @{
        "Authorization" = $authorizationHeader
        "x-ms-version"  = "2017-02-22"
        "x-ms-date"     = "$([System.DateTime]::UtcNow.ToString("R"))"
        "Content-Type"  = "application/json"
    }

    $body = @{
        "id" = $DatabaseName
    }

    try {
        $response = Invoke-WebRequest -Uri "https://$($CosmosDbAccountName).documents.azure.com/dbs" -Method POST -Headers $headers -Body ($body | ConvertTo-Json)
        Write-Host $response.StatusDescription
    }
    catch {
        $_.Exception
        $Result = $_.Exception.Response.GetResponseStream()
        $Reader = New-Object System.IO.StreamReader($result)
        $Reader.ReadToEnd();
    }
}
