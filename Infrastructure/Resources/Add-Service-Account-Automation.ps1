<#

.SYNOPSIS
Create, update, manage database service accounts

.DESCRIPTION
Create, update, manage database service accounts

.PARAMETER Environment
The deployment environment

.PARAMETER ResourceGroupName
The name of the Resource Group

.PARAMETER KeyVaultName
The name of the KeyVault to retrive and store the secrets

.PARAMETER ServiceAccountUsername
The username of the service account for the SQL Server

.PARAMETER ServerName
The name of the Azure SQL Server

.PARAMETER DatabaseName
The name of the Azure SQL database

.EXAMPLE

$DeploymentParameters = @ {
    Environment = "test"
    ResourceGroupName = "RG01"
    KeyVaultName = "kv-01"
    ServiceAccountUsername = "sa-01"
    ServerName = "sql-srv-01"
    DatabaseName = "db01"
}
.\Service-Account-Automation.ps1 $DeploymentParameters

#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('at', 'test', 'test2', 'pp', 'prd', 'mo', 'demo')]
    [String]$Environment,
    [Parameter(Mandatory = $true)]
    [String]$ResourceGroupName,
    [Parameter(Mandatory = $true)]
    [String]$KeyVaultName,
    [Parameter(Mandatory = $true)]
    [String]$ServiceAccountUserName,
    [Parameter(Mandatory = $true)]
    [String]$ServerName,
    [Parameter(Mandatory = $true)]
    [String]$DatabaseName

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

    Write-Host "    -> Retrieving secure password"
    $SqlServerPassword = (Get-AzureKeyVaultSecret -VaultName $KeyVaultName -Name $ServerName).SecretValueText
    if (!$SqlServerPassword) {
        throw "Could not retrieve secure password for $ServerName"
    }

    # --- Create a new password and store the entry in KeyVault for Service Account
    Write-Log -LogLevel Information -Message "Creating new entry for $ServiceAccountUserName in Key Vault $KeyVaultName"
    $ServiceAccountPassword = (New-Password).PasswordAsSecureString
    $null = Set-AzureKeyVaultSecret -VaultName $KeyVaultName -Name $Environment-$ServiceAccountUserName -SecretValue $ServiceAccountPassword

    # --- Retrieve secure password
    Write-Host "    -> Retrieving secure password"
    $ServiceAccountPassword = (Get-AzureKeyVaultSecret -VaultName $KeyVaultName -Name $Environment-$ServiceAccountUserName).SecretValueText
    if (!$ServiceAccountPassword) {
        throw "Could not retrieve secure password for $Environment-$ServiceAccountUserName"
    }

    # --- SQL Commands to create Service Account
    Write-Host "    -> Creating $($ServiceAccountUserName) and storing password in $($KeyVaultName)"
    $Server = "tcp:$($ServerResource.Properties.fullyQualifiedDomainName),1433"
    $ConnectionString = "Server=$server;Database=$DatabaseName;User ID=$SqlServerUserName;Password=$SqlServerPassword;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
    $Connection = New-Object -TypeName System.Data.SqlClient.SqlConnection($ConnectionString)
    if (!$Connection) {
        throw "Could not establish connection to the $Servername"
    }

    # --- Retrieve SQL query location and run command
    $QueryPath = "$PSScriptRoot\..\..\sql\create-service-account.sql"
    if (Test-Path $QueryPath) {
        Write-Log -LogLevel Information -Message "    -> Retrieving SQL Query location"
    }
    else {
        Write-Log -LogLevel Information -Message "    -> Could not locate SQL Query location"
        break
    }

    $query = [System.IO.File]::ReadAllText((Resolve-Path $queryPath))
    $command = New-Object -TypeName System.Data.SqlClient.SqlCommand($query, $connection)

    $username = New-Object -TypeName System.Data.SqlClient.SqlParameter("@Username", "$ServiceAccountUserName")
    $password = New-Object -TypeName System.Data.SqlClient.SqlParameter("@Password", "$ServiceAccountPassword")

    $command.Parameters.Add($username)
    $command.Parameters.Add($password)

    $connection.Open()
    $command.ExecuteNonQuery()
    $connection.Close()

}
catch {
    throw $_
}
# --- Retrieve password from vault and set outputs

