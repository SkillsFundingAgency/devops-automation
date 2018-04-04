[CmdletBinding(DefaultParametersetName='None', SupportsShouldProcess = $true, ConfirmImpact = "High")]
Param (
    [Parameter(Mandatory=$false, ValueFromPipeline=$true)]
    [String[]]$SubscriptionName,
    [Parameter(Mandatory=$true)]
    [String]$ServerNamePattern,
    [Parameter(Mandatory=$true)]
    [String]$FirewallRuleConfigurationPath,
    [Parameter(Mandatory=$false)]
    [Bool]$RemoveLegacyRules,
    [Parameter(ParameterSetName='RemoveDbRules', Mandatory=$false)]
    [Switch]$RemoveDatabaseRules,
    [Parameter(ParameterSetName='RemoveDbRules', Mandatory=$true)]
    [String]$KeyVaultName,
    [Parameter(ParameterSetName='RemoveDbRules', Mandatory=$true)]
    [string]$KeyName
)

<#

.SYNOPSIS
Update the firewall of an Azure SQL Server

.DESCRIPTION
Update the firewall of an Azure SQL Server

.PARAMETER SubscriptionName
One or more subscriptions to interogate

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

.PARAMETER RemoveLegacyRules
If the rule exists in Azure but not in the configuration supplied it will be removed

.PARAMETER DryRun
Make a test pass with the supplied parameters. No changes will be made if this switch is passed.

.EXAMPLE
$Subscriptions = @(
    "Sub1",
    "Sub2"
)
Update-SQLServerFirewallConfiguration -SubscriptionName $SubScriptions -ServerNamePattern "test-sql" -FirewallRuleConfiguration c:\test\FirewallConfiguration.json

.EXAMPLE
$Subscriptions = @(
    "Sub1",
    "Sub2"
)
Update-SQLServerFirewallConfiguration -SubscriptionName $SubScriptions -ServerNamePattern "test-sql" -FirewallRuleConfiguration c:\test\FirewallConfiguration.json -RemoveLegacyRules -DryRun

.EXAMPLE
$Subscriptions = @(
    "Sub1",
    "Sub2"
)
Update-SQLServerFirewallConfiguration -SubscriptionName $SubScriptions -ServerNamePattern "test-sql" -FirewallRuleConfiguration c:\test\FirewallConfiguration.json -RemoveLegacyRules

.NOTES
- Depends on and Helpers.psm1
#>
function Update-SQLServerFirewallConfiguration {
    [CmdletBinding(DefaultParametersetName='None', SupportsShouldProcess = $true, ConfirmImpact = "High")]
    Param (
        [Parameter(Mandatory=$false, ValueFromPipeline=$true)]
        [String[]]$SubscriptionName,
        [Parameter(Mandatory=$true)]
        [String]$ServerNamePattern,
        [Parameter(Mandatory=$true)]
        [String]$FirewallRuleConfigurationPath,
        [Parameter(Mandatory=$false)]
        [Bool]$RemoveLegacyRules,
        [Parameter(ParameterSetName='RemoveDbRules', Mandatory=$false)]
        [Switch]$RemoveDatabaseRules,
        [Parameter(ParameterSetName='RemoveDbRules', Mandatory=$true)]
        [String]$KeyVaultName,
        [Parameter(ParameterSetName='RemoveDbRules', Mandatory=$true)]
        [string]$KeyName
    )

    Begin {
        # --- Import helper modules
        Import-Module (Resolve-Path -Path $PSScriptRoot\..\Infrastructure\Modules\Helpers.psm1).Path

        # --- Install SqlServer module
        Write-Log -LogLevel Information -Message "Installing SqlServer PS module"
        Install-Module SqlServer -Scope CurrentUser -Force
        Import-Module SqlServer

        # --- Check if there is a session open
        if (!((Get-AzureRmContext).Account)) {
            throw "You need to log in first"
        }

        # --- If SubscriptionName is null get the current subscription from the context
        if (!$PSBoundParameters.ContainsKey("SubscriptionName")) {
            $SubscriptionName = (Get-AzureRmContext).Subscription.Name

            # --- Fall back to old property structure
            if (!$SubscriptionName) {
                $SubscriptionName = (Get-AzureRmContext).Subscription.SubscriptionName
            }

            if (!$SubscriptionName) {
                throw "Could not retrieve subscription name from context"
            }
        }

        # --- Retrieve configuration and parse
        $Config = Get-Content -Path (Resolve-Path -Path $FirewallRuleConfigurationPath).Path -Raw | ConvertFrom-Json
    }

    Process {
        try {
            ##TO DO: test Find-AzureRmResource with -TenantLevel switch
            foreach ($Subscription in $SubscriptionName) {
                Write-Log -LogLevel Information -Message "Searching for Sql Servers matching $ServerNamePattern in $Subscription"
                $null = Select-AzureRmSubscription -SubscriptionName $Subscription -WhatIf:$false
                $SubscriptionSqlServers = Find-AzureRmResource -ResourceNameContains $ServerNamePattern -ResourceType "Microsoft.Sql/Servers" -ExpandProperties

                foreach ($SqlServer in $SubscriptionSqlServers) {
                    # --- Set Resource Group Name
                    $ResourceGroupName = $SQLServer.ResourceGroupName
                    $ServerName = $SqlServer.Name

                    Write-Log -LogLevel Information -Message "Processing Sql Server $ServerName"

                    # --- Create or update firewall rules on the SQL Server instance
                    foreach ($Rule in $Config) {

                        Update-SqlServerFirewallRule -ResourceGroupName $ResourceGroupName -ServerName $ServerName -Rule $Rule

                    }

                    if ($RemoveLegacyRules) {

                        Remove-NonStandardSqlServerFirewallRules -ResourceGroupName $ResourceGroupName -ServerName $ServerName -Config $Config

                    }

                    # --- Remove firewall rules from each database on the SQL Server instance
                    if($RemoveDatabaseRules) {
                        $SqlAdministratorPassword = Get-AzureKeyVaultSecret -VaultName $KeyVaultName -Name $KeyName
                        if ($SqlAdministratorPassword) {
                            Remove-SqlDatabaseFirewallRules -ResourceGroupName $ResourceGroupName -SqlServer $SqlServer -SqlServerFqdn $SqlServer.Properties.fullyQualifiedDomainName -SqlAdministrationPassword $SqlAdministratorPassword
                        }
                    }


                }
            }
        }
        catch {
            throw $_
        }
    }

    End {

    }
}

function Remove-NonStandardSqlServerFirewallRules {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "High")]
    param(
        [Parameter(Mandatory=$true)]
        [String]$ResourceGroupName,
        [Parameter(Mandatory=$true)]
        [String]$ServerName,
        [Parameter(Mandatory=$true)]
        [PSObject]$Config
    )

    # --- If the rule exists in Azure but not in the config it should be removed
    $ExistingRuleNames = Get-AzureRmSqlServerFirewallRule -ResourceGroupName $ResourceGroupName -ServerName $ServerName -WhatIf:$false | Select-Object -ExpandProperty FirewallRuleName
    $ConfigRuleNames = $Config | Select-Object -ExpandProperty Name
    foreach ($ExistingRule in $ExistingRuleNames) {
        if (!$ConfigRuleNames.Contains($ExistingRule)) {

            Write-Log -LogLevel Warning -Message "Removing Firewall Rule $ExistingRule"
            if ($PSCmdlet.ShouldProcess($ExistingRule, "Remove-AzureRmSqlServerFirewallRule")) {

                $null = Remove-AzureRmSqlServerFirewallRule -ResourceGroupName $ResourceGroupName -ServerName $ServerName -FirewallRuleName $ExistingRule -Force

            }
        }

    }

}

function Remove-SqlDatabaseFirewallRules {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "High")]
    param(

        [Parameter(Mandatory=$true)]
        [String]$ResourceGroupName,
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$SqlServer,
        [Parameter(Mandatory=$true)]
        [String]$SqlServerFqdn,
        [Parameter(Mandatory=$true)]
        [Microsoft.Azure.Commands.KeyVault.Models.Secret]$SqlAdministrationPassword

    )

    # --- Get databases
    $SqlServerDatabases = Get-AzureRmSqlDatabase -ResourceGroupName $ResourceGroupName -ServerName $ServerName -WhatIf:$false

    # --- Get sa credential
    $SqlAdministratorLogin = $SqlServer.Properties.administratorLogin
    $Credential = [PSCredential]::new($SqlAdministratorLogin, $SqlAdministratorPassword.SecretValue)

    foreach ($Database in $SqlServerDatabases) {

        Write-Log -LogLevel Information -Message "Processing Sql Database $($Database.DatabaseName))"

        $SqlCmdParameters = @{
            ServerInstance    = $SqlServerFqdn
            Database          = $Database.DatabaseName
            Username          = $Credential.UserName
            Password          = $Credential.GetNetworkCredential().Password
            EncryptConnection = $true
            Query             = "SELECT * FROM sys.database_firewall_rules"
        }

        $DatabaseFirewallRules = Invoke-SqlCmd @SqlCmdParameters

        foreach ($Rule in $DatabaseFirewallRules) {

            $SqlCmdParameters.Query = "EXECUTE sp_delete_database_firewall_rule N'$($Rule.name)';"
            Write-Log -LogLevel Warning -Message "Removing Firewall Rule $($Rule.name) from $($Database.DatabaseName) by invoking $($SqlCmdParameters.Query)"
            if ($PSCmdlet.ShouldProcess($($SqlCmdParameters.Query), "Invoke-SqlCmd")) {

                ##TO DO: test this command works
                Invoke-SqlCmd @SqlCmdParameters

            }

        }
    }
}

function Update-SqlServerFirewallRule {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "High")]
    param(
        [Parameter(Mandatory=$true)]
        [String]$ResourceGroupName,
        [Parameter(Mandatory=$true)]
        [String]$ServerName,
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$Rule
    )

    $FirewallRuleParameters = @{
        ResourceGroupName = $ResourceGroupName
        ServerName        = $ServerName
        FirewallRuleName  = $Rule.Name
        StartIpAddress    = $Rule.StartIpAddress
        EndIPAddress      = $Rule.EndIPAddress
    }

    # --- Try to retrieve the firewall rule by name
    $FirewallRule = Get-AzureRmSqlServerFirewallRule -FirewallRuleName $Rule.Name -ServerName $ServerName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue -WhatIf:$false

    if (!$FirewallRule) {
        Write-Log -LogLevel Information -Message "  -> Creating firewall rule $($Rule.Name)"

        if ($PSCmdlet.ShouldProcess($($Rule.Name), "New-AzureRmSqlServerFirewallRule")) {
            $null = New-AzureRmSqlServerFirewallRule @FirewallRuleParameters -ErrorAction Stop
        }
    }
    else {
        Write-Log -LogLevel Information -Message "  -> Updating firewall rule $($Rule.Name)"
        if ($PSCmdlet.ShouldProcess($($Rule.Name), "Set-AzureRmSqlServerFirewallRule")) {
            $null = Set-AzureRmSqlServerFirewallRule @FirewallRuleParameters -ErrorAction Stop
        }
    }
}
<#
$Params = @{
    SubscriptionName = $SubscriptionName
    ServerNamePattern = $ServerNamePattern
    FirewallRuleConfigurationPath = $FirewallRuleConfigurationPath
    RemoveLegacyRules = $RemoveLegacyRules.IsPresent
}
#>
$Params = @{
    SubscriptionName              = "SFA-DAS-Dev/Test"
    ServerNamePattern             = "das-at-"
    FirewallRuleConfigurationPath = "C:\Users\nick\Documents\Work - DFE\config.json"
    RemoveLegacyRules             = $true
    RemoveDatabaseRules           = $true
    KeyVaultName                  = "das-dev-shared-kv"
    KeyName                       = "at-sqladminpassword"
}

Update-SQLServerFirewallConfiguration @Params -WhatIf -Verbose
