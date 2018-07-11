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
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "High")]
Param (
    [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
    [String[]]$SubscriptionName,
    [Parameter(Mandatory = $true)]
    [String]$ServerNamePattern,
    [Parameter(Mandatory = $true)]
    [String]$FirewallRuleConfigurationPath,
    [Parameter(Mandatory = $false)]
    [Switch]$RemoveLegacyRules,
    [Parameter(Mandatory = $false)]
    [Switch]$DryRun
)

Begin {
    # --- Import helper modules
    Import-Module (Resolve-Path -Path $PSScriptRoot\..\Infrastructure\Modules\Helpers.psm1).Path

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
        foreach ($Subscription in $SubscriptionName) {
            Write-Log -LogLevel Information -Message "Searching for Sql Servers matching $ServerNamePattern in $Subscription"
            $null = Select-AzureRmSubscription -SubscriptionName $Subscription

            #TODO: Migrate to version 6, ResourceNameContains logic may not be possible
            $SubscriptionSqlServers = Find-AzureRmResource -ResourceNameContains $ServerNamePattern -ResourceType "Microsoft.Sql/Servers"

            foreach ($SqlServer in $SubscriptionSqlServers) {
                # --- Set Resource Group Name
                $ResourceGroupName = $SQLServer.ResourceGroupName
                $ServerName = $SqlServer.Name

                Write-Log -LogLevel Information -Message "Processing Sql Server $ServerName"

                # --- Create or update firewall rules on the SQL Server instance
                foreach ($Rule in $Config) {

                    $FirewallRuleParameters = @{
                        ResourceGroupName = $ResourceGroupName
                        ServerName        = $ServerName
                        FirewallRuleName  = $Rule.Name
                        StartIpAddress    = $Rule.StartIpAddress
                        EndIPAddress      = $Rule.EndIPAddress
                    }

                    # --- Try to retrieve the firewall rule by name
                    $FirewallRule = Get-AzureRmSqlServerFirewallRule -FirewallRuleName $Rule.Name -ServerName $ServerName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue

                    if (!$FirewallRule) {
                        Write-Log -LogLevel Information -Message "  -> Creating firewall rule $($Rule.Name)"

                        if (!$DryRun.IsPresent) {
                            $null = New-AzureRmSqlServerFirewallRule @FirewallRuleParameters -ErrorAction Stop
                        }
                    }
                    else {
                        Write-Log -LogLevel Information -Message "  -> Updating firewall rule $($Rule.Name)"
                        if (!$DryRun.IsPresent) {
                            $null = Set-AzureRmSqlServerFirewallRule @FirewallRuleParameters -ErrorAction Stop
                        }
                    }
                }

                # --- If the rule exists in Azure but not in the config it should be removed
                if ($PSBoundParameters.ContainsKey("RemoveLegacyRules")) {
                    $ExistingRuleNames = Get-AzureRmSqlServerFirewallRule -ResourceGroupName $ResourceGroupName -ServerName $ServerName | Select-Object -ExpandProperty FirewallRuleName
                    $ConfigRuleNames = $Config | Select-Object -ExpandProperty Name
                    foreach ($ExistingRule in $ExistingRuleNames) {
                        if (!$ConfigRuleNames.Contains($ExistingRule)) {
                            Write-Log -LogLevel Warning -Message "Removing Firewall Rule $ExistingRule"
                            if (!$DryRun.IsPresent) {
                                $null = Remove-AzureRmSqlServerFirewallRule -ResourceGroupName $ResourceGroupName -ServerName $ServerName -FirewallRuleName $ExistingRule -Force
                            }
                        }
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
