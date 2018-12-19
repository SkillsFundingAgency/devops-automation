<#

.SYNOPSIS
Create, update, manage database service accounts

.DESCRIPTION
Create, update, manage database service accounts

.PARAMETER KeyVaultName
The name of the KeyVault to retrive and store the secrets

.PARAMETER ServiceAccountUsername
The username of the service account for the SQL Server

.PARAMETER ServerName
The name of the Azure SQL Server

.PARAMETER DatabaseName
The name of the Azure SQL database

.PARAMETER ResourceGroupName
The name of the Resource Group

.EXAMPLE

$DeploymentParameters = @ {
    KeyVaultName = "kv-01"
    ServiceAccountUsername = "sa-01"
    ServerName = "sql-srv-01"
    DatabaseName = "db01"
    ResourceGroupName = "RG01"
}
.\Service-Account-Automation.ps1 $DeploymentParameters

#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory = $true)]
    [String]$KeyVaultName,
    [Parameter(Mandatory = $true)]
    [String]$ServiceAccountUserName,
    [Parameter(Mandatory = $true)]
    [String]$ServerName,
    [Parameter(Mandatory = $true)]
    [String]$DatabaseName,
    [Parameter(Mandatory = $true)]
    [String]$ResourceGroupName
)

# --- Import helper modules
Import-Module (Resolve-Path -Path $PSScriptRoot\..\Modules\Helpers.psm1).Path

try {
    # --- Retrieve server resource and extract resource group
    Write-Host "Searching for SQL server resource $ServerName"
    $ServerResource = Get-AzureRmResource -Name $ServerName -ResourceType "Microsoft.Sql/servers" -ResourceGroupName $ResourceGroupName
    if (!$ServerResource) {
        throw "Could not find SQL server resource $ServerName"
    }

    # --- Retrieve SQL Administrator login details
    Write-Host "Retrieving login for $ServerName"
    $SqlServerUserName = (Get-AzureRmSqlServer -ResourceGroupName $ServerResource.ResourceGroupName -ServerName $ServerName).SqlAdministratorLogin

    Write-Host "    -> Retrieving secure server password"
    $SqlServerPassword = (Get-AzureKeyVaultSecret -VaultName $KeyVaultName -Name $ServerName).SecretValueText
    if (!$SqlServerPassword) {
        throw "Could not retrieve secure password for $ServerName"
    }

    # --- Retrieve secure password
    Write-Host "    -> Retrieving secure service account password"

    # -- Ensure consistency with existing entries
    $EnvironmentName = $ENV:EnvironmentName.ToLower()
    switch ($EnvironmentName) {
        'preprod' {
            $EnvironmentName = "pp"
            break
        }

        'prod' {
            $EnvironmentName = "prd"
            break
        }
    }

    $ServiceAccountPassword = (Get-AzureKeyVaultSecret -VaultName $KeyVaultName -Name "$($EnvironmentName)-$($ServiceAccountUserName)").SecretValueText
    if (!$ServiceAccountPassword) {
        Write-Host "    -> Creating new entry for $ServiceAccountUserName in Key Vault $KeyVaultName"
        $Password = New-Password
        $ServiceAccountPassword = $Password.PasswordAsString
        $null = Set-AzureKeyVaultSecret -VaultName $KeyVaultName -Name "$($EnvironmentName)-$($ServiceAccountUserName)" -SecretValue $Password.PasswordAsSecureString
    }

    # --- SQL Commands to create Service Account
    Write-Host "    -> Creating $($ServiceAccountUserName) and storing password in $($KeyVaultName)"

    $QueryText = @"
        DECLARE @UserSQL AS nvarchar(max)
        DECLARE @GrantSQL AS nvarchar(max)

        -- Create user if it does not exist
        IF NOT EXISTS (SELECT name FROM sys.database_principals WHERE NAME = '$ServiceAccountUserName') BEGIN
            SET @UserSQL = 'CREATE USER [$($ServiceAccountUserName)] WITH PASSWORD = '' $($ServiceAccountPassword) '''
            EXECUTE(@UserSQL)
        END

        -- Add user to db roles
        EXEC sp_addrolemember 'db_datareader', [$($ServiceAccountUserName)]
        EXEC sp_addrolemember 'db_datawriter', [$($ServiceAccountUserName)]

        -- Add Grants
        SET @GrantSQL = 'GRANT EXECUTE TO [$($ServiceAccountUserName)]'
        EXEC(@GrantSQL)
"@

    $SqlCmdParameters = @{
        ServerInstance    = "$($ServerName).database.windows.net"
        Database          = $DatabaseName
        Username          = $SqlServerUserName
        Password          = $SqlServerPassword
        Query             = $QueryText
        EncryptConnection = $true
    }

    Invoke-Sqlcmd @SqlCmdParameters -ErrorAction Stop

    $Server = "tcp:$($ServerResource.Properties.fullyQualifiedDomainName),1433"
    $ConnectionString = "Server=$Server;Database=$DatabaseName;User ID=$SqlServerUserName;Password=$SqlServerPassword;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
    Write-Output ("##vso[task.setvariable variable=ServiceAccountConnectionString; issecret=true]$($ConnectionString)")
}
catch {
    throw $_
}
