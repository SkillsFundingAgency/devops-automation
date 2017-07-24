<#

.SYNOPSIS
Create an Azure SQL Server and database

.DESCRIPTION
Create an Azure SQL Server and database

.PARAMETER Location
The location of the Resource Group. This is limited to West Europe and North Europe

.PARAMETER ResourceGroupName
The name of the destination Resource Group for the resource

.PARAMETER ServerName
The name of the Azure SQL Server

.PARAMETER ServerAdminUsername
The username of the SA account for the SQL Server

.PARAMETER FirewallRuleConfiguration
THe path to the firewall rule JSON configuration document

Configuration is an array of objects and should be represented as follows:

[
    {
        "Name": "AllowAllWindowsAzureIps",
        "StartIPAddress": "0.0.0.0",
        "EndIpAddress": "0.0.0.0"
    },
    {
        "Name": "Rule1",
        "StartIPAddress": "xxx.xxx.xxx.xxx",
        "EndIpAddress": "xxx.xxx.xxx.xxx"
    },
    {
        "Name": "Rule2",
        "StartIPAddress": "xxx.xxx.xxx.xxx",
        "EndIpAddress": "xxx.xxx.xxx.xxx"
    }
]

.PARAMETER DatabaseName
One or more database names to create on the given server

.PARAMETER DatabaseEdition
Specifies the edition to assign to the database. The acceptable values for this parameter are:

- Default
- None
- Premium
- Basic
- Standard
- DataWarehouse
- Free

.PARAMETER DatabaseServiceObjective
Specifies the name of the service objective to assign to the database. The default is S0

.EXAMPLE

$SQLInstanceParameters = @ {
    Location = "West Europe"
    ResourceGroupName = "RG01"
    KeyVaultName = "kv-01"
    KeyVaultSecretName = "secret01"
    ServerName = "sql-svr-01"
    ServerAdminUserName = "sql-sa"
    FirewallRuleConfiguration = ".\sql.firewall.rules.json"
    Database = "db01"
}
.\New-SQLInstance.ps1 @SQLInstanceParameters

#>

Param (
    [Parameter(Mandatory = $false)]
	[ValidateSet("West Europe", "North Europe")]
    [String]$Location = $ENV:Location,
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
	[String]$ResourceGroupName = $ENV:ResourceGroup,
    [Parameter(Mandatory = $false)]
    [String]$KeyVaultName,
    [Parameter(Mandatory = $true)]
    [String]$KeyVaultSecretName,
    [Parameter(Mandatory = $true)]    
    [String]$ServerName,
    [Parameter(Mandatory = $true)]
    [String]$ServerAdminUsername,
    [Parameter(Mandatory = $false)]
    [String]$FirewallRuleConfiguration,   
    [Parameter(Mandatory = $true)]
    [String[]]$DatabaseName,
    [Parameter(Mandatory = $false)]
    [ValidateSet("Default","None","Premium","Basic","Standard","DataWarehouse","Free")]
    [String]$DatabaseEdition = "Standard",
    [Parameter(Mandatory = $false)]
    [String]$DatabaseServiceObjective = "S0"
)

# --- Import helper modules
Import-Module (Resolve-Path -Path $PSScriptRoot\..\Modules\Azure.psm1).Path
Import-Module (Resolve-Path -Path $PSScriptRoot\..\Modules\Helpers.psm1).Path

# --- Check for an existing sql server in the subscription
Write-Verbose -Message "Checking for exiting SQL Server $ServerName"
$SQLServer = Find-AzureRmResource -ResourceNameEquals $ServerName

# --- Check for an existing key vault
Write-Verbose -Message "Checking for existing entry for $KeyVaultSecretName in Key Vault $KetVaultName"
$ServerAdminPassword = (Get-AzureKeyVaultSecret -VaultName $KeyVaultName -Name $KeyVaultSecretName).SecretValue

if (!$SQLServer){
    Write-Verbose -Message "Attempting to resolve SQL Server name $ServerName globally"
    if ($GloballyResolvable) {
        throw "The SQL Server name $ServerName is globally resolvable. It's possible that this name has already been taken."
    }

    try {

        # --- If a secret doesn't exist create a new password and save it to the vault
        if (!$ServerAdminPassword) {
            Write-Verbose -Message "Creating new entry for $KeyVaultSecretName in Key Vault $KetVaultName"
            $ServerAdminPassword = (New-Password).PasswordAsSecureString
            $null = Set-AzureKeyVaultSecret -VaultName $KeyVaultName -Name $KeyVaultSecretName -SecretValue $ServerAdminPassword
        }

        # --- Set up SQL Server parameters and create a new instance
        Write-Verbose -Message "Attempting to create SQL Server $ServerName"
        $ServerAdminCredentials = [PSCredential]::new($ServerAdminUsername,$ServerAdminPassword)

        $ServerParameters = @{
            Location = $Location
            ResourceGroupName = $ResourceGroupName
            ServerName = $ServerName
            SqlAdministratorCredentials = $ServerAdminCredentials
            ServerVersion = "12.0"
        }

        $Server = New-AzureRmSqlServer @ServerParameters
    } catch {
        throw "Could not create SQL Server $($ServerName): $_"
    }

}

# --- Create or update firewall rules on the SQL Server instance
if ($SQLServer) {
    $Config = Get-Content -Path (Resolve-Path -Path $FirewallRuleConfiguration).Path -Raw | ConvertFrom-Json
    foreach ($Rule in $Config) {

        $FirewallRuleParameters = @{
            ResourceGroupName = $ResourceGroupName
            ServerName = $ServerName
            FirewallRuleName = $Rule.Name
            StartIpAddress = $Rule.StartIpAddress
            EndIPAddress = $Rule.EndIPAddress
        }
        Set-SqlServerFirewallRule @FirewallRuleParameters -Verbose:$VerbosePreference
    }
}

# --- If the SQL Server exists in the subscription create databases
if ($Server -and !$GloballyResolvable) {
    foreach ($Database in $DatabaseName) {
        Write-Verbose -Message "Checking for Database $DatabaseName on SQL Server $ServerName"
        $SQLDatabase = Get-AzureRmSqlDatabase -DatabaseName $Database -ServerName $ServerName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue

        # --- If the database doesn't exist, create one
        if (!$SQLDatabase) {
            Write-Verbose -Message "Attempting to create Database $Database"
            try {
                $SQLDatabaseParameters = @{
                    ResourceGroupName = $ResourceGroupName
                    ServerName = $ServerName
                    DatabaseName = $Database
                    Edition = $DatabaseEdition
                    RequestedServiceObjectiveName = $DatabaseServiceObjective
                }

                $null = New-AzureRmSqlDatabase @SQLDatabaseParameters
            } catch {
                throw "Could not create database $($Database): $_"
            }
        }

        # --- Configure additional settings on the database
    }
}