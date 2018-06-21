$Config = Get-Content $PSScriptRoot\..\Tests\Acceptance.Config.json -Raw | ConvertFrom-Json
Push-Location -Path $PSScriptRoot\..\Infrastructure\Resources\

Describe "Set-CosmosDbAccountComponents Tests" -Tag "Acceptance-ARM" {

    $ResourceGroupName = "$($Config.resourceGroupName)$($Config.suffix)"
    $CosmosDbAccountName = "$($Config.cosmosDbAccountName)$($Config.suffix)"

    Write-Host "Setting up CosmosDb Account for testing"
    $DBProperties = @{"databaseAccountOfferType" ="Standard"}
    New-AzureRmResource -ResourceType "Microsoft.DocumentDb/databaseAccounts" -ApiVersion "2015-04-08" `
        -ResourceGroupName $ResourceGroupName -Location $Config.location -Kind "MongoDB" `
        -ResourceName $CosmosDbAccountName -PropertyObject $DBProperties -Force

    New-Item  "./$($config.cosmosDbTestConfig.Databases[0].Collections[0].StoredProcedures[0].StoredProcedureName).ext" -ItemType File -Force
    Set-Content -Path "./$($config.cosmosDbTestConfig.Databases[0].Collections[0].StoredProcedures[0].StoredProcedureName).ext" -Value "function(){}"

    It "Should run successfully" {
        {.\Set-CosmosDbAccountComponents -ResourceGroupName $ResourceGroupName -CosmosDbAccountName $CosmosDbAccountName `
                -CosmosDbConfigurationString ($Config.cosmosDbTestConfig | ConvertTo-Json -Depth 10) -CosmosDbProjectFolderPath "."} | Should not throw
    }

    $TestContext = New-CosmosDbContext -Account $CosmosDbAccountName -ResourceGroup $ResourceGroupName -MasterKeyType "PrimaryMasterKey"

    It "Should create a database" {
        $TestDb = Get-CosmosDbDatabase -Context $TestContext -Id $config.cosmosDbTestConfig.Databases[0].DatabaseName
        $TestDb.Id | Should be $config.cosmosDbTestConfig.Databases[0].DatabaseName
    }

    It "Should create a collection" {
        $TestColl = Get-CosmosDbCollection -Context $TestContext -Database $config.cosmosDbTestConfig.Databases[0].DatabaseName `
            -Id $config.cosmosDbTestConfig.Databases[0].Collections[0].CollectionName
        $TestColl.Id | Should be $config.cosmosDbTestConfig.Databases[0].Collections[0].CollectionName
    }

    It "Should create a collection with IndexingMode set to None" {
        $TestColl = Get-CosmosDbCollection -Context $TestContext -Database $config.cosmosDbTestConfig.Databases[0].DatabaseName `
            -Id $config.cosmosDbTestConfig.Databases[0].Collections[1].CollectionName
        $TestColl.indexingPolicy.indexingMode | Should be $config.cosmosDbTestConfig.Databases[0].Collections[1].IndexingPolicy.indexingMode
    }

    It "Should create a stored procedure with the correct code body" {
        $TestSproc = Get-CosmosDbStoredProcedure -Context $TestContext -Database $config.cosmosDbTestConfig.Databases[0].DatabaseName `
            -CollectionId $config.cosmosDbTestConfig.Databases[0].Collections[0].CollectionName `
            -Id $config.cosmosDbTestConfig.Databases[0].Collections[0].StoredProcedures[0].StoredProcedureName
        $TestSproc.Id | Should be $config.cosmosDbTestConfig.Databases[0].Collections[0].StoredProcedures[0].StoredProcedureName
        $TestSproc.body | Should be (Get-Content "./$($config.cosmosDbTestConfig.Databases[0].Collections[0].StoredProcedures[0].StoredProcedureName).ext" -Raw)
    }

    It "Should update stored procedures if they change" {
        $NewStoredProcCode = "function(x,y){}"
        Set-Content -Path "./$($config.cosmosDbTestConfig.Databases[0].Collections[0].StoredProcedures[0].StoredProcedureName).ext" -Value $NewStoredProcCode
        {.\Set-CosmosDbAccountComponents -ResourceGroupName $ResourceGroupName -CosmosDbAccountName $CosmosDbAccountName `
                -CosmosDbConfigurationString ($Config.cosmosDbTestConfig | ConvertTo-Json -Depth 10) -CosmosDbProjectFolderPath "."} | Should not throw

        $TestSproc = Get-CosmosDbStoredProcedure -Context $TestContext -Database $config.cosmosDbTestConfig.Databases[0].DatabaseName `
            -CollectionId $config.cosmosDbTestConfig.Databases[0].Collections[0].CollectionName `
            -Id $config.cosmosDbTestConfig.Databases[0].Collections[0].StoredProcedures[0].StoredProcedureName
        ($TestSproc.body) | Should be (Get-Content "./$($config.cosmosDbTestConfig.Databases[0].Collections[0].StoredProcedures[0].StoredProcedureName).ext" -Raw)
    }

    Remove-Item -Path "./$($config.cosmosDbTestConfig.Databases[0].Collections[0].StoredProcedures[0].StoredProcedureName).ext" -Force
}

Pop-Location
