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
$CosmosDbParameters = @{
    ResourceGroupName = $ResourceGroupName
    CosmosDbAccountName = $CosmosDbAccountName
    CosmosDbConfigurationFilePath = $ConfigurationFilePath
    CosmosDbProjectFolderPath = $MongoDbProjectFolderPath
}
.\Set-CosmosDbAccountComponents @CosmosDbParameters
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
$FindCosmosDbAccountParameters = @{
    ResourceType       = "Microsoft.DocumentDb/databaseAccounts"
    ResourceGroupName  = $ResourceGroupName
    ResourceNameEquals = $CosmosDbAccountName
}
$ExistingAccount = Find-AzureRmResource @FindCosmosDbAccountParameters

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
            $GetCosmosDbDatabaseParameters = @{
                Connection = $CosmosDbConnection
                Database   = $Database.DatabaseName
                Id         = $Collection.CollectionName
            }
            $ExistingCollection = Get-CosmosDbCollection @GetCosmosDbDatabaseParameters
        }
        catch {
        }
        if (!$ExistingCollection) {
            Write-Host "Creating Collection: $($Collection.CollectionName) in $($Database.DatabaseName)"
            $NewCosmosDbCollectionParameters = @{
                Connection      = $CosmosDbConnection
                Database        = $Database.DatabaseName
                Id              = $Collection.CollectionName
                OfferThroughput = $Collection.OfferThroughput
            }
            $null = New-CosmosDbCollection @NewCosmosDbCollectionParameters
        }

        foreach ($StoredProcedure in $Collection.StoredProcedures) {
            # --- Create Stored Procedure
            try {
                $GetCosmosDbStoredProcParameters = @{
                    Connection   = $CosmosDbConnection
                    Database     = $Database.DatabaseName
                    CollectionId = $Collection.CollectionName
                    Id           = $StoredProcedure.StoredProcedureName
                }
                $ExistingStoredProcedure = Get-CosmosDbStoredProcedure @GetCosmosDbStoredProcParameters
            }
            catch {
            }
            $FindStoredProcFileParameters = @{
                Path    = (Resolve-Path $CosmosDbProjectFolderPath)
                Filter  = "$($StoredProcedure.StoredProcedureName)*"
                Recurse = $true
                File    = $true
            }
            $StoredProcedureFile = Get-ChildItem @FindStoredProcFileParameters | ForEach-Object { $_.FullName }
            if (!$StoredProcedureFile) {
                throw "Stored Procedure name $($StoredProcedure.StoredProcedureName) could not be found in $(Resolve-Path $CosmosDbProjectFolderPath)"
            }
            if ($StoredProcedureFile.GetType().Name -ne "String") {
                throw "Multiple Stored Procedures with name $($StoredProcedure.StoredProcedureName) found in $(Resolve-Path $CosmosDbProjectFolderPath)"
            }
            if (!$ExistingStoredProcedure) {
                Write-Host "Creating Stored Procedure: $($StoredProcedure.StoredProcedureName) in $($Collection.CollectionName) in $($Database.DatabaseName)"
                $NewCosmosDbStoredProcParameters = @{
                    Connection          = $CosmosDbConnection
                    Database            = $Database.DatabaseName
                    CollectionId        = $Collection.CollectionName
                    Id                  = $StoredProcedure.StoredProcedureName
                    StoredProcedureBody = (Get-Content $StoredProcedureFile -Raw)
                }
                $null = New-CosmosDbStoredProcedure @NewCosmosDbStoredProcParameters
            }
            elseif ($ExistingStoredProcedure.body -ne (Get-Content $StoredProcedureFile -Raw)) {
                Write-Host "Updating Stored Procedure: $($StoredProcedure.StoredProcedureName) in $($Collection.CollectionName) in $($Database.DatabaseName)"
                $SetCosmosDbStoredProcParameters = @{
                    Connection          = $CosmosDbConnection
                    Database            = $Database.DatabaseName
                    CollectionId        = $Collection.CollectionName
                    Id                  = $StoredProcedure.StoredProcedureName
                    StoredProcedureBody = (Get-Content $StoredProcedureFile -Raw)
                }
                $null = Set-CosmosDbStoredProcedure @SetCosmosDbStoredProcParameters
            }
        }
    }
}
