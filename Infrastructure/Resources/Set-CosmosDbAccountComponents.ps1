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

.Parameter PartitionKeyFix
Use fix for cosmosdb shard keys as per https://blog.olandese.nl/2017/12/13/create-a-sharded-mongodb-in-azure-cosmos-db/

.Parameter UpdateIndexPolicyFix
Use fix for cosmosdb indexing policy default until this is fixed https://github.com/PlagueHO/CosmosDB/issues/140

.EXAMPLE
$CosmosDbParameters = @{
    ResourceGroupName = $ResourceGroupName
    CosmosDbAccountName = $CosmosDbAccountName
    CosmosDbConfigurationFilePath = $CosmosDbConfigurationFilePath
    CosmosDbProjectFolderPath = $CosmosDbProjectFolderPath
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
    [string]$CosmosDbProjectFolderPath,
    [Parameter(Mandatory = $false)]
    [switch]$PartitionKeyFix,
    [Parameter(Mandatory = $false)]
    [switch]$UpdateIndexPolicyFix
)

Class CosmosDbStoredProcedure {
    [string]$StoredProcedureName
}

Class CosmosDbIndex {
    [string]$kind
    [string]$dataType
    [int32]$precision
}

Class CosmosDbIncludedPath {
    [string]$path
    [CosmosDbIndex[]]$indexes
}

Class CosmosDbExcludedPath {
    [string]$path
}

Class CosmosDbIndexingPolicy {
    [CosmosDbIncludedPath[]]$includedPaths
    [CosmosDbExcludedPath[]]$excludedPaths
    [bool]$automatic
    [string]$indexingMode
}

Class CosmosDbCollection {
    [string]$CollectionName
    [string]$PartitionKey = $null
    [int]$OfferThroughput
    [CosmosDbIndexingPolicy]$IndexingPolicy
    [CosmosDbStoredProcedure[]]$StoredProcedures
    [int]$DefaultTtl
}

Class CosmosDbDatabase {
    [string]$DatabaseName
    [CosmosDbCollection[]]$Collections
}

Class CosmosDbSchema {
    [CosmosDbDatabase[]]$Databases
}

Import-Module (Resolve-Path -Path $PSScriptRoot\..\Modules\Helpers.psm1).Path

$CosmosDBModuleVersion = "2.1.3.528"

if (!(Get-Module CosmosDB | Where-Object { $_.Version.ToString() -eq $CosmosDBModuleVersion })) {
    Write-Log -Message "Minimum module version is not imported." -LogLevel Verbose
    if (!(Get-InstalledModule CosmosDB -MinimumVersion $CosmosDBModuleVersion -ErrorAction SilentlyContinue)) {
        Write-Log -Message "Minimum module version is not installed." -LogLevel Verbose
        Install-Module CosmosDB -MinimumVersion $CosmosDBModuleVersion -Scope CurrentUser -Force
    }
    Import-Module CosmosDB -MinimumVersion $CosmosDBModuleVersion
}

Write-Log -Message "Searching for existing account" -LogLevel Verbose
if ((((Get-Module AzureRM -ListAvailable | Sort-Object { $_.Version.Major } -Descending).Version.Major))[0] -gt 5) {
    $GetCosmosDbAccountParameters = @{
        Name              = $CosmosDbAccountName
        ResourceGroupName = $ResourceGroupName
        ExpandProperties  = $true
        ResourceType      = "Microsoft.DocumentDB/databaseAccounts"
    }
    $ExistingAccount = Get-AzureRmResource @GetCosmosDbAccountParameters
}
else {
    $GetCosmosDbAccountParameters = @{
        ResourceType      = "Microsoft.DocumentDb/databaseAccounts"
        ResourceGroupName = $ResourceGroupName
        ResourceName      = $CosmosDbAccountName
    }
    $ExistingAccount = Get-AzureRmResource @GetCosmosDbAccountParameters
}

if (!$ExistingAccount -or $ExistingAccount.Properties.provisioningState -ne "Succeeded") {
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
                Context  = $CosmosDbContext
                Database = $Database.DatabaseName
                Id       = $Collection.CollectionName
            }
            $ExistingCollection = Get-CosmosDbCollection @GetCosmosDbDatabaseParameters
        }
        catch {
        }

        if (!$ExistingCollection) {

            Write-Log -Message "Creating Collection: $($Collection.CollectionName) in $($Database.DatabaseName)" -LogLevel Information

            if ($Collection.IndexingPolicy) {
                [CosmosDB.IndexingPolicy.Path.IncludedPath[]]$IndexIncludedPaths = @()
                [CosmosDB.IndexingPolicy.Path.ExcludedPath[]]$IndexExcludedPaths = @()

                foreach ($includedPath in $Collection.IndexingPolicy.includedPaths) {
                    [CosmosDB.IndexingPolicy.Path.Index[]]$IndexRanges = @()

                    foreach ($index in $includedPath.indexes) {
                        if ($index.kind -eq "Spatial") {
                            [CosmosDB.IndexingPolicy.Path.IndexSpatial]$thisIndex = New-CosmosDbCollectionIncludedPathIndex -Kind $index.kind -DataType $index.dataType
                            Write-Log -Message "IncludedPathIndex kind: $($thisIndex.kind) index: $($thisIndex.DataType)" -LogLevel Information
                        }
                        elseif ($index.kind -eq "Range") {
                            [CosmosDB.IndexingPolicy.Path.IndexRange]$thisIndex = New-CosmosDbCollectionIncludedPathIndex -Kind $index.kind -DataType $index.dataType -Precision $index.precision
                            Write-Log -Message "IncludedPathIndex kind: $($thisIndex.kind) index: $($thisIndex.DataType) precision: $($thisIndex.precision)" -LogLevel Information
                        }
                        elseif ($index.kind -eq "Hash") {
                            [CosmosDB.IndexingPolicy.Path.IndexHash]$thisIndex = New-CosmosDbCollectionIncludedPathIndex -Kind $index.kind -DataType $index.dataType -Precision $index.precision
                            Write-Log -Message "IncludedPathIndex kind: $($thisIndex.kind) index: $($thisIndex.DataType) precision: $($thisIndex.precision)" -LogLevel Information
                        }
                        $IndexRanges += $thisIndex
                    }

                    $indexIncludedPath = New-CosmosDbCollectionIncludedPath -Path $includedPath.path -Index $indexRanges
                    $IndexIncludedPaths += $indexIncludedPath

                    Write-Log -Message "indexIncludedPath path: $($includedPath.path.GetType()) index: $($indexRanges.GetType())" -LogLevel Information
                    Write-Log -Message "indexIncludedPath indexes (object): $($indexRanges)" -LogLevel Information
                }

                Write-Log -Message "indexIncludedPaths: $($IndexIncludedPaths)" -LogLevel Information

                foreach ($excludedPath in $Collection.IndexingPolicy.excludedPaths) {
                    $indexExcludedPath = New-CosmosDbCollectionExcludedPath -Path $excludedPath.path
                    $IndexExcludedPaths += $indexExcludedPath

                    Write-Log -Message "indexExcludedPath path: $($excludedPath.path)" -LogLevel Information
                }

                Write-Log -Message "indexExcludedPaths: $($IndexExcludedPaths)" -LogLevel Information

                $IndexingPolicy  = New-CosmosDbCollectionIndexingPolicy -Automatic $Collection.IndexingPolicy.automatic -IndexingMode $Collection.IndexingPolicy.indexingMode -IncludedPath $IndexIncludedPaths -ExcludedPath $IndexExcludedPaths -Debug
                Write-Log -Message "Created New-CosmosDbCollectionIndexingPolicy: Automatic: $($IndexingPolicy.Automatic) Mode: $($IndexingPolicy.IndexingMode) IPs: $($IndexIncludedPaths.GetType()) EPs: $($IndexExcludedPaths.GetType())" -LogLevel Information
                $NewCosmosDbCollectionParameters = @{
                    Context         = $CosmosDbContext
                    Database        = $Database.DatabaseName
                    Id              = $Collection.CollectionName
                    OfferThroughput = $Collection.OfferThroughput
                    IndexingPolicy  = $IndexingPolicy
                }

            }
            elseif (!$Collection.IndexingPolicy) {
                Write-Log -Message "No IndexingPolicy for Collection: $($Collection.CollectionName)" -LogLevel Information

                $NewCosmosDbCollectionParameters = @{
                    Context         = $CosmosDbContext
                    Database        = $Database.DatabaseName
                    Id              = $Collection.CollectionName
                    OfferThroughput = $Collection.OfferThroughput
                }
            }

            if ($Collection.PartitionKey) {
                if ($PartitionKeyFix.IsPresent) {
                    $NewCosmosDbCollectionParameters.Add('PartitionKey', "'`$v'/$($Collection.PartitionKey)/'`$v'")
                }
                else {
                    $NewCosmosDbCollectionParameters.Add('PartitionKey', $Collection.PartitionKey)
                }
            }

            if ($Collection.DefaultTtl) {
                Write-Log -Message "Add DefaultTtl: $($Collection.DefaultTtl)" -LogLevel Information
                $NewCosmosDbCollectionParameters += @{
                    DefaultTimeToLive = $Collection.DefaultTtl
                }
            }

            $null = New-CosmosDbCollection @NewCosmosDbCollectionParameters

            Write-Log -Message "Collection Details: Context: Account - $($CosmosDbContext.Account), BaseUri - $($CosmosDbContext.BaseUri); Database: $($Database.DatabaseName); IndexingPolicy: $($IndexingPolicy)" -LogLevel Information
        }
        else {
            Write-Log -Message "Updating Collection: $($Collection.CollectionName) in $($Database.DatabaseName)" -LogLevel Information

            # Check for any indexes and update
            if ($Collection.IndexingPolicy) {
                [CosmosDB.IndexingPolicy.Path.IncludedPath[]]$IndexIncludedPaths = @()
                [CosmosDB.IndexingPolicy.Path.ExcludedPath[]]$IndexExcludedPaths = @()

                foreach ($includedPath in $Collection.IndexingPolicy.includedPaths) {
                    [CosmosDB.IndexingPolicy.Path.Index[]]$IndexRanges = @()

                    foreach ($index in $includedPath.indexes) {
                        if ($index.kind -eq "Spatial") {
                            [CosmosDB.IndexingPolicy.Path.IndexSpatial]$thisIndex = New-CosmosDbCollectionIncludedPathIndex -Kind $index.kind -DataType $index.dataType
                            Write-Log -Message "IncludedPathIndex kind: $($thisIndex.kind) index: $($thisIndex.DataType)" -LogLevel Information
                        }
                        elseif ($index.kind -eq "Range") {
                            [CosmosDB.IndexingPolicy.Path.IndexRange]$thisIndex = New-CosmosDbCollectionIncludedPathIndex -Kind $index.kind -DataType $index.dataType -Precision $index.precision
                            Write-Log -Message "IncludedPathIndex kind: $($thisIndex.kind) index: $($thisIndex.DataType) precision: $($thisIndex.precision)" -LogLevel Information
                        }
                        elseif ($index.kind -eq "Hash") {
                            [CosmosDB.IndexingPolicy.Path.IndexHash]$thisIndex = New-CosmosDbCollectionIncludedPathIndex -Kind $index.kind -DataType $index.dataType -Precision $index.precision
                            Write-Log -Message "IncludedPathIndex kind: $($thisIndex.kind) index: $($thisIndex.DataType) precision: $($thisIndex.precision)" -LogLevel Information
                        }
                        $IndexRanges += $thisIndex
                    }

                    $indexIncludedPath = New-CosmosDbCollectionIncludedPath -Path $includedPath.path -Index $indexRanges
                    $IndexIncludedPaths += $indexIncludedPath

                    Write-Log -Message "indexIncludedPath path: $($includedPath.path.GetType()) index: $($indexRanges.GetType())" -LogLevel Information
                    Write-Log -Message "indexIncludedPath indexes (object): $($indexRanges)" -LogLevel Information
                }

                Write-Log -Message "indexIncludedPaths: $($IndexIncludedPaths)" -LogLevel Information

                foreach ($excludedPath in $Collection.IndexingPolicy.excludedPaths) {
                    $indexExcludedPath = New-CosmosDbCollectionExcludedPath -Path $excludedPath.path
                    $IndexExcludedPaths += $indexExcludedPath

                    Write-Log -Message "indexExcludedPath path: $($excludedPath.path)" -LogLevel Information
                }

                Write-Log -Message "indexExcludedPaths: $($IndexExcludedPaths)" -LogLevel Information

                $IndexingPolicy  = New-CosmosDbCollectionIndexingPolicy -Automatic $Collection.IndexingPolicy.automatic -IndexingMode $Collection.IndexingPolicy.indexingMode -IncludedPath $IndexIncludedPaths -ExcludedPath $IndexExcludedPaths -Debug
                Write-Log -Message "Created New-CosmosDbCollectionIndexingPolicy: Automatic: $($IndexingPolicy.Automatic) Mode: $($IndexingPolicy.IndexingMode) IPs: $($IndexIncludedPaths.GetType()) EPs: $($IndexExcludedPaths.GetType())" -LogLevel Information

                $UpdatedCosmosDbCollectionParameters = @{
                    Context        = $CosmosDbContext
                    Database       = $Database.DatabaseName
                    Id             = $Collection.CollectionName
                    IndexingPolicy = $IndexingPolicy
                }
            }
            elseif (!$Collection.IndexingPolicy) {
                Write-Log -Message "No IndexingPolicy for Collection: $($Collection.CollectionName)" -LogLevel Information
                if ($UpdateIndexPolicyFix.IsPresent) {
                    $DefaultIndexString = New-CosmosDbCollectionIncludedPathIndex -Kind Hash -DataType String -Precision 3
                    $DefaultIndexNumber = New-CosmosDbCollectionIncludedPathIndex -Kind Range -DataType Number -Precision -1
                    $DefaultIndexIncludedPath = New-CosmosDbCollectionIncludedPath -Path '/*' -Index $DefaultIndexString,$DefaultIndexNumber
                    $DefaultIndexingPolicy  = New-CosmosDbCollectionIndexingPolicy -Automatic $true -IndexingMode Consistent -IncludedPath $DefaultIndexIncludedPath

                    $UpdatedCosmosDbCollectionParameters = @{
                        Context        = $CosmosDbContext
                        Database       = $Database.DatabaseName
                        Id             = $Collection.CollectionName
                        IndexingPolicy = $DefaultIndexingPolicy
                    }
                }
                else {
                    $UpdatedCosmosDbCollectionParameters = @{
                        Context  = $CosmosDbContext
                        Database = $Database.DatabaseName
                        Id       = $Collection.CollectionName
                    }
                }

            }

            if ($Collection.DefaultTtl) {
                Write-Log -Message "Add DefaultTtl: $($Collection.DefaultTtl)" -LogLevel Information
                $UpdatedCosmosDbCollectionParameters += @{
                    DefaultTimeToLive = $Collection.DefaultTtl
                }
            }

            Write-Log -Message "Set Cosmos Collection: $($Collection.CollectionName)" -LogLevel Information
            $null = Set-CosmosDbCollection @UpdatedCosmosDbCollectionParameters
        }

        foreach ($StoredProcedure in $Collection.StoredProcedures) {
            # --- Create Stored Procedure
            try {
                $ExistingStoredProcedure = $null
                $GetCosmosDbStoredProcParameters = @{
                    Context      = $CosmosDbContext
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
                    Context             = $CosmosDbContext
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
                    Context             = $CosmosDbContext
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
