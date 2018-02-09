function New-CosmosDbDatabaseCollectionStoredProcedure {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $ResourceGroupName,
        [Parameter(Mandatory = $true)]
        $CosmosDbAccountName,
        [Parameter(Mandatory = $true)]
        $DatabaseName,
        [Parameter(Mandatory = $true)]
        $CollectionName,
        [Parameter(Mandatory = $true)]
        $StoredProcedureName,
        [Parameter(Mandatory = $true)]
        $StoredProcedureFilePath
    )

    $masterKey = Get-CosmosDbMasterKey -ResourceGroupName $ResourceGroupName -CosmosDbAccountName $CosmosDbAccountName
    $authorizationHeader = New-CosmosDbAuthHeader -Verb "POST" -ResourceType "sprocs" -ResourceId "dbs/$DatabaseName/colls/$CollectionName" -Key $masterKey

    $headers = @{
        "Authorization" = $authorizationHeader
        "x-ms-version"  = "2017-02-22"
        "x-ms-date"     = "$([System.DateTime]::UtcNow.ToString("R"))"
        "Content-Type"  = "application/json"
    }

    $StoredProcedureCode  = [System.IO.File]::ReadAllText($StoredProcedureFilePath);
    $StoredProcBody = $StoredProcedureCode.replace("`r", "\r").replace("`n", "\n")

    $body = @{
        "id"   = $StoredProcedureName
        "body" = $StoredProcBody
    }

    try {
        $response = Invoke-WebRequest -Uri "https://$($CosmosDbAccountName).documents.azure.com/dbs/$DatabaseName/colls/$CollectionName/sprocs" -Method POST `
            -Headers $headers -Body ($body | ConvertTo-Json)
        Write-Host $response.StatusDescription
    }
    catch {
        $_.Exception
        $Result = $_.Exception.Response.GetResponseStream()
        $Reader = New-Object System.IO.StreamReader($result)
        $Reader.ReadToEnd();
    }
}
