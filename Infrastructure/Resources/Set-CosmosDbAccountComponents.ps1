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

if (!(Get-Module CosmosDB | Where-Object { $_.Version.ToString() -eq "2.0.3.190" })) {
    Install-Module CosmosDB -RequiredVersion "2.0.3.190" -Scope CurrentUser -Force
    Import-Module CosmosDB -RequiredVersion "2.0.3.190"
}
Import-Module (Resolve-Path -Path $PSScriptRoot\..\Modules\Helpers.psm1).Path

Write-Log -Message "Searching for existing account" -LogLevel Verbose
$FindCosmosDbAccountParameters = @{
    ResourceType       = "Microsoft.DocumentDb/databaseAccounts"
    ResourceGroupName  = $ResourceGroupName
    ResourceNameEquals = $CosmosDbAccountName
}
$ExistingAccount = Find-AzureRmResource @FindCosmosDbAccountParameters

if (!$ExistingAccount) {
    Write-Log -Message "CosmosDb Account could not be found, make sure it has been deployed." -LogLevel Error
    throw "$_"
}

try {
    if ($PSCmdlet.ParameterSetName -eq "AsFilePath") {
        if (!(Test-Path $CosmosDbConfigurationFilePath)) {
            Write-Log -Message "Configuration File Path can not be found" -LogLevel Error
            throw "$_"
        }
        $CosmosDbConfiguration = [CosmosDbSchema](Get-Content $CosmosDbConfigurationFilePath | ConvertFrom-Json)
    }
    elseif ($PSCmdlet.ParameterSetName -eq "AsString") {
        $CosmosDbConfiguration = [CosmosDbSchema]($CosmosDbConfigurationString | ConvertFrom-Json)
    }
}
catch {
    Write-Log -Message "Config deserialization failed, check JSON is valid" -LogLevel Error
    throw "$_"
}

$CosmosDbContext = New-CosmosDbContext -Account $CosmosDbAccountName -ResourceGroup $ResourceGroupName -MasterKeyType 'PrimaryMasterKey'

foreach ($Database in $CosmosDbConfiguration.Databases) {
    # --- Create Database
    try {
        $ExistingDatabase = $null
        $ExistingDatabase = Get-CosmosDbDatabase -Context $CosmosDbContext -Id $Database.DatabaseName
    }
    catch {
    }
    if (!$ExistingDatabase) {
        Write-Log -Message "Creating Database: $($Database.DatabaseName)" -LogLevel Information
        $null = New-CosmosDbDatabase -Context $CosmosDbContext -Id $Database.DatabaseName
    }

    foreach ($Collection in $Database.Collections) {
        # --- Create or Update Collection
        try {
            $ExistingCollection = $null
            $GetCosmosDbDatabaseParameters = @{
                Context = $CosmosDbContext
                Database   = $Database.DatabaseName
                Id         = $Collection.CollectionName
            }
            $ExistingCollection = Get-CosmosDbCollection @GetCosmosDbDatabaseParameters
        }
        catch {
        }
        if (!$ExistingCollection) {
            Write-Log -Message "Creating Collection: $($Collection.CollectionName) in $($Database.DatabaseName)" -LogLevel Information
            $NewCosmosDbCollectionParameters = @{
                Context      = $CosmosDbContext
                Database        = $Database.DatabaseName
                Id              = $Collection.CollectionName
                OfferThroughput = $Collection.OfferThroughput
                PartitionKey    = $Collection.PartitionKey
            }
            $null = New-CosmosDbCollection @NewCosmosDbCollectionParameters
        }

        foreach ($StoredProcedure in $Collection.StoredProcedures) {
            # --- Create Stored Procedure
            try {
                $ExistingStoredProcedure = $null
                $GetCosmosDbStoredProcParameters = @{
                    Context   = $CosmosDbContext
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
                Write-Log -Message "Stored Procedure name $($StoredProcedure.StoredProcedureName) could not be found in $(Resolve-Path $CosmosDbProjectFolderPath)" -LogLevel Error
                throw "$_"
            }
            if ($StoredProcedureFile.GetType().Name -ne "String") {
                Write-Log -Message "Multiple Stored Procedures with name $($StoredProcedure.StoredProcedureName) found in $(Resolve-Path $CosmosDbProjectFolderPath)" -LogLevel Error
                throw "$_"
            }
            if (!$ExistingStoredProcedure) {
                Write-Log -Message "Creating Stored Procedure: $($StoredProcedure.StoredProcedureName) in $($Collection.CollectionName) in $($Database.DatabaseName)" -LogLevel Information
                $NewCosmosDbStoredProcParameters = @{
                    Context          = $CosmosDbContext
                    Database            = $Database.DatabaseName
                    CollectionId        = $Collection.CollectionName
                    Id                  = $StoredProcedure.StoredProcedureName
                    StoredProcedureBody = (Get-Content $StoredProcedureFile -Raw)
                }
                $null = New-CosmosDbStoredProcedure @NewCosmosDbStoredProcParameters
            }
            elseif ($ExistingStoredProcedure.body -ne (Get-Content $StoredProcedureFile -Raw)) {
                Write-Log -Message "Updating Stored Procedure: $($StoredProcedure.StoredProcedureName) in $($Collection.CollectionName) in $($Database.DatabaseName)" -LogLevel Information
                $SetCosmosDbStoredProcParameters = @{
                    Context          = $CosmosDbContext
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
