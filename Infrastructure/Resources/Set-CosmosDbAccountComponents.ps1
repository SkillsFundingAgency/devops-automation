<#

.SYNOPSIS
Create databases, collections and stored procedures within a CosmosDb Account

.DESCRIPTION
Create databases, collections and stored procedures within a CosmosDb Account

.PARAMETER ResourceGroupName
The name of the Resource Group for the CosmosDb Account

.PARAMETER CosmosDbAccountName
The name of the CosmosDb Account

.PARAMETER CosmosDbConfigurationString
CosmosDb JSON configuration in string format

.PARAMETER CosmosDbConfigurationFilePath
CosmosDb JSON configuration as a file

.Parameter CosmosDbProjectFolderPath
Root folder to search for Stored Procedure files

.EXAMPLE
.\Set-CosmosDbAccountComponents -ResourceGroupName $ResourceGroupName -CosmosDbAccountName $CosmosDbAccountName `
                -CosmosDbConfigurationFilePath $ConfigurationFilePath  -CosmosDbProjectFolderPath $MongoDbProjectFolderPath
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroupName = $ENV:ResourceGroup,
    [Parameter(Mandatory = $true)]
    [string]$CosmosDbAccountName,
    [Parameter(Mandatory = $true, ParameterSetName = "AsString")]
    [string]$CosmosDbConfigurationString,
    [Parameter(Mandatory = $true, ParameterSetName = "AsFilePath")]
    [string]$CosmosDbConfigurationFilePath,
    [Parameter(Mandatory = $true)]
    [string]$CosmosDbProjectFolderPath
)

Class CosmosDbStoredProcedure {
    [string]$StoredProcedureName
}

Class CosmosDbCollection {
    [string]$CollectionName
    [string]$PartitionKey
    [int]$OfferThroughput
    [CosmosDbStoredProcedure[]]$StoredProcedures
}

Class CosmosDbDatabase {
    [string]$DatabaseName
    [CosmosDbCollection[]]$Collections
}

Class CosmosDbSchema {
    [CosmosDbDatabase[]]$Databases
}


if (!(Get-Module CosmosDB)) {
    Install-Module CosmosDB -Scope CurrentUser -Force
    Import-Module CosmosDB
}


Write-Verbose "Searching for existing account"
$ExistingAccount = Find-AzureRmResource -ResourceType "Microsoft.DocumentDb/databaseAccounts"-ResourceGroupName $ResourceGroupName `
    -ResourceNameEquals $CosmosDbAccountName

if (!$ExistingAccount) {
    throw "CosmosDb Account could not be found, make sure it has been deployed."
}

try {
    if ($PSCmdlet.ParameterSetName -eq "AsFilePath") {
        if (!Test-Path $CosmosDbConfigurationFilePath) {
            throw "Configuration File Path can not be found"
        }
        $CosmosDbConfiguration = [CosmosDbSchema](Get-Content $CosmosDbConfigurationFilePath | ConvertFrom-Json)
    }
    elseif ($PSCmdlet.ParameterSetName -eq "AsString") {
        $CosmosDbConfiguration = [CosmosDbSchema]($CosmosDbConfigurationString | ConvertFrom-Json)
    }
}
catch {
    throw "Config deserialization failed, check JSON is valid $_"
}

$CosmosDbConnection = New-CosmosDbConnection -Account $CosmosDbAccountName -ResourceGroup $ResourceGroupName -MasterKeyType 'PrimaryMasterKey'


foreach ($Database in $CosmosDbConfiguration.Databases) {
    # --- Create Database
    try {
        $ExistingDatabase = Get-CosmosDbDatabase -Connection $CosmosDbConnection -Id $Database.DatabaseName
    }
    catch {
    }
    if (!$ExistingDatabase) {
        Write-Host "Creating Database: $($Database.DatabaseName)"
        $null = New-CosmosDbDatabase -Connection $CosmosDbConnection -Id $Database.DatabaseName
    }

    foreach ($Collection in $Database.Collections) {
        # --- Create or Update Collection
        try {
            $ExistingCollection = Get-CosmosDbCollection -Connection $CosmosDbConnection -Database $Database.DatabaseName `
                -Id $Collection.CollectionName
        }
        catch {
        }
        if (!$ExistingCollection) {
            Write-Host "Creating Collection: $($Collection.CollectionName) in $($Database.DatabaseName)"
            $null = New-CosmosDbCollection -Connection $CosmosDbConnection -Database $Database.DatabaseName `
                -Id $Collection.CollectionName -OfferThroughput $($Collection.OfferThroughput)
        }

        foreach ($StoredProcedure in $Collection.StoredProcedures) {
            # --- Create Stored Procedure
            try {
                $ExistingStoredProcedure = Get-CosmosDbStoredProcedure -Connection $CosmosDbConnection -Database $Database.DatabaseName `
                    -CollectionId $Collection.CollectionName -Id $StoredProcedure.StoredProcedureName
            }
            catch {
            }
            $StoredProcedureFile = Get-ChildItem -Path (Resolve-Path $CosmosDbProjectFolderPath) -Filter "$($StoredProcedure.StoredProcedureName)*" `
                -Recurse -File | ForEach-Object { $_.FullName }
            if (!$StoredProcedureFile) {
                throw "Stored Procedure name $($StoredProcedure.StoredProcedureName) could not be found in $(Resolve-Path $CosmosDbProjectFolderPath)"
            }
            if ($StoredProcedureFile.GetType().Name -ne "String") {
                throw "Multiple Stored Procedures with name $($StoredProcedure.StoredProcedureName) found in $(Resolve-Path $CosmosDbProjectFolderPath)"
            }
            if (!$ExistingStoredProcedure) {
                Write-Host "Creating Stored Procedure: $($StoredProcedure.StoredProcedureName) in $($Collection.CollectionName) in $($Database.DatabaseName)"
                $null = New-CosmosDbStoredProcedure -Connection $CosmosDbConnection -Database $Database.DatabaseName `
                    -CollectionId $Collection.CollectionName -Id $StoredProcedure.StoredProcedureName -StoredProcedureBody (Get-Content $StoredProcedureFile -Raw)
            }
            elseif ($ExistingStoredProcedure.body -ne (Get-Content $StoredProcedureFile -Raw)) {
                Write-Host "Updating Stored Procedure: $($StoredProcedure.StoredProcedureName) in $($Collection.CollectionName) in $($Database.DatabaseName)"
                $null = Set-CosmosDbStoredProcedure -Connection $CosmosDbConnection -Database $Database.DatabaseName `
                    -CollectionId $Collection.CollectionName -Id $StoredProcedure.StoredProcedureName -StoredProcedureBody (Get-Content $StoredProcedureFile -Raw)
            }
        }
    }
}
