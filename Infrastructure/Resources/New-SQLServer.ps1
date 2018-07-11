<#

.SYNOPSIS
Create an Azure SQL Server

.DESCRIPTION
Create an Azure SQL Server

.PARAMETER Location
The location of the Resource Group. This is limited to West Europe and North Europe

.PARAMETER ResourceGroupName
The name of the destination Resource Group for the resource

.PARAMETER KeyVaultName
The name of the key vault where credentials are stored

.PARAMETER KeyVaultSecretName
The name of the key vault secret to retrieve or create

.PARAMETER ServerName
The name of the Azure SQL Server

.PARAMETER ServerAdminUsername
The username of the SA account for the SQL Server

.PARAMETER ActiveDirectoryAdministrator
The name of the principal to add as an active directory administrator

.PARAMETER FirewallRuleConfiguration
The path to the firewall rule JSON configuration document

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

.PARAMETER AuditingStorageAccountName
The storage account to be used for audit logging

.PARAMETER ThreatDetectionNotificationRecipient
An array of email addresses to which alerts are sent

.EXAMPLE

$SQLServerParameters = @ {
    Location = "West Europe"
    ResourceGroupName = "RG01"
    KeyVaultName = "kv-01"
    KeyVaultSecretName = "secret01"
    ServerName = "sql-svr-01"
    ServerAdminUserName = "sql-sa"
    ActiveDirectoryAdministrator = "SQL ADMIN GROUP"
    FirewallRuleConfiguration = ".\sql.firewall.rules.json"
}
.\New-SQLServer.ps1 @SQLServerParameters

#>

Param (
    [Parameter(Mandatory = $false)]
    [ValidateSet("West Europe", "North Europe")]
    [String]$Location = $ENV:Location,
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [String]$ResourceGroupName = $ENV:ResourceGroup,
    [Parameter(Mandatory = $true)]
    [String]$KeyVaultName,
    [Parameter(Mandatory = $true)]
    [String]$KeyVaultSecretName,
    [Parameter(Mandatory = $true)]
    [String]$ServerName,
    [Parameter(Mandatory = $true)]
    [String]$ServerAdminUsername,
    [Parameter(Mandatory = $false)]
    [String]$ActiveDirectoryAdministrator,
    [Parameter(Mandatory = $true)]
    [String]$FirewallRuleConfiguration,
    [Parameter(Mandatory = $true)]
    [String]$AuditingStorageAccountName,
    [Parameter(Mandatory = $true)]
    [String[]]$ThreatDetectionNotificationRecipient
)

# --- Import helper modules
Import-Module (Resolve-Path -Path $PSScriptRoot\..\Modules\Azure.psm1).Path
Import-Module (Resolve-Path -Path $PSScriptRoot\..\Modules\Helpers.psm1).Path

# --- Check for an existing sql server in the subscription
Write-Log -LogLevel Information -Message "Checking for existing SQL Server $ServerName"
if ((((Get-Module AzureRM -ListAvailable | Sort-Object { $_.Version.Major } -Descending).Version.Major))[0] -gt 5) {
    $SQLServer = Get-AzureRmResource -Name $ServerName
}
else {
    $SQLServer = Find-AzureRmResource -ResourceNameEquals $ServerName
}

# --- Ensure KeyVaultSecretName is lower case
$KeyVaultSecretName = $KeyVaultSecretName.ToLower()

# --- Check for an existing key vault
Write-Log -LogLevel Information -Message "Checking for existing entry for $KeyVaultSecretName in Key Vault $KeyVaultName"
$ServerAdminPassword = (Get-AzureKeyVaultSecret -VaultName $KeyVaultName -Name $KeyVaultSecretName).SecretValue

# --- Check for to see whether the SQLServer has been deployed in another subscription
$GloballyResolvable = Resolve-AzureRMResource -PublicResourceFqdn "$($ServerName).database.windows.net"

if (!$SQLServer) {
    Write-Log -LogLevel Information -Message "Attempting to resolve SQL Server name $ServerName globally"
    if ($GloballyResolvable) {
        throw "The SQL Server name $ServerName is globally resolvable. It's possible that this name has already been taken."
    }

    try {

        # --- If a secret doesn't exist create a new password and save it to the vault
        if (!$ServerAdminPassword) {
            Write-Log -LogLevel Information -Message "Creating new entry for $KeyVaultSecretName in Key Vault $KetVaultName"
            $ServerAdminPassword = (New-Password).PasswordAsSecureString
            $null = Set-AzureKeyVaultSecret -VaultName $KeyVaultName -Name $KeyVaultSecretName -SecretValue $ServerAdminPassword
        }

        # --- Set up SQL Server parameters and create a new instance
        Write-Log -LogLevel Information -Message "Attempting to create SQL Server $ServerName"
        $ServerAdminCredentials = [PSCredential]::new($ServerAdminUsername, $ServerAdminPassword)

        $ServerParameters = @{
            Location                    = $Location
            ResourceGroupName           = $ResourceGroupName
            ServerName                  = $ServerName
            SqlAdministratorCredentials = $ServerAdminCredentials
            ServerVersion               = "12.0"
        }

        $SQLServer = New-AzureRmSqlServer @ServerParameters
    }
    catch {
        throw "Could not create SQL Server $($ServerName): $_"
    }
}

if ($SQLServer) {

    # --- If the ActiveDirectoryAdministrator parameter has been passed, add the principal to the server
    if ($PSBoundParameters.ContainsKey("ActiveDirectoryAdministrator")) {
        Write-Log -LogLevel Information -Message "Setting an Active Directory Administrator $ActiveDirectoryAdministrator"
        $ServerActiveDirectoryAdministrator = Get-AzureRmSqlServerActiveDirectoryAdministrator -ResourceGroupName $ResourceGroupName -ServerName $ServerName

        if ($ServerActiveDirectoryAdministrator -ne $ActiveDirectoryAdministrator) {
            try {
                $null = Set-AzureRmSqlServerActiveDirectoryAdministrator -ResourceGroupName $ResourceGroupName -ServerName $ServerName -DisplayName $ActiveDirectoryAdministrator
            }
            catch {
                throw "Could not set an Active Directory Administrator on server $($ServerName): $_"
            }
        }
    }

    # --- If the server exists and there is no associated secret, throw an error
    if (!$ServerAdminPassword) {
        throw "A secret entry for $KeyVaultSecretName does not exist in the Key Vault"
    }

    # --- Create or update firewall rules on the SQL Server instance
    $Config = Get-Content -Path (Resolve-Path -Path $FirewallRuleConfiguration).Path -Raw | ConvertFrom-Json
    foreach ($Rule in $Config) {

        $FirewallRuleParameters = @{
            ResourceGroupName = $ResourceGroupName
            ServerName        = $ServerName
            FirewallRuleName  = $Rule.Name
            StartIpAddress    = $Rule.StartIpAddress
            EndIPAddress      = $Rule.EndIPAddress
        }
        Set-SqlServerFirewallRule @FirewallRuleParameters -Verbose:$VerbosePreference -Confirm:$false
    }

    # --- Configure Auditing and Threat Detection
    Write-Log -LogLevel Information -Message "Configuring auditing policy"
    if ((((Get-Module AzureRM -ListAvailable | Sort-Object { $_.Version.Major } -Descending).Version.Major))[0] -gt 5) {
        $AuditingPolicyParameters = @{
            ResourceGroupName  = $ResourceGroupName
            ServerName         = $ServerName
            StorageAccountName = $AuditingStorageAccountName
            RetentionInDays    = 90
            State              = "Enabled"
        }
        Set-AzureRmSqlServerAuditing @AuditingPolicyParameters
    }
    else {
        $AuditingPolicyParameters = @{
            ResourceGroupName  = $ResourceGroupName
            ServerName         = $ServerName
            StorageAccountName = $AuditingStorageAccountName
            AuditType          = "Blob"
            EventType          = "All"
            RetentionInDays    = 90
        }
        Set-AzureRmSqlServerAuditingPolicy @AuditingPolicyParameters
    }

    Write-Log -LogLevel Information -Message "Configuring threat detection policy"
    $ThreatDetectionPolicyParameters = @{
        ResourceGroupName            = $ResourceGroupName
        ServerName                   = $ServerName
        NotificationRecipientsEmails = $ThreatDetectionNotificationRecipient -join ";"
        StorageAccountName           = $AuditingStorageAccountName
        RetentionInDays              = 90
        ExcludedDetectionType        = "None"
    }
    Set-AzureRmSqlServerThreatDetectionPolicy @ThreatDetectionPolicyParameters
}

# --- Retrieve password from vault and set outputs
$SQLServerAdminPasswordAsText = (Get-AzureKeyVaultSecret -VaultName $KeyVaultName -Name $KeyVaultSecretName).SecretValueText
Write-Output ("##vso[task.setvariable variable=SQLServerFQDN;]$($ServerName).database.windows.net")
Write-Output ("##vso[task.setvariable variable=SQLServerAdminPassword; issecret=true;]$SQLServerAdminPasswordAsText")
