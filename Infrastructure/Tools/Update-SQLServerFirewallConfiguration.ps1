<#

.SYNOPSIS
Update the firewall of an Azure SQL Server

.DESCRIPTION
Update the firewall of an Azure SQL Server

.PARAMETER ServerName
The name of the Azure SQL Server

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

.EXAMPLE
Update-SQLServerFirewallConfiguration -ServerName "svr-01" -FirewallRuleConfiguration c:\test\FirewallConfiguration.json

.EXAMPLE
Update-SQLServerFirewallConfiguration -ServerName "svr-01" -FirewallRuleConfiguration c:\test\FirewallConfiguration.json -RemoveLegacyRules

.NOTES
- Depends on Azure.psm1 and Helpers.psm1
- You must be in the same subscription as the resource

#>

Param (
    [Parameter(Mandatory = $true)]    
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

# --- Import helper modules
Import-Module (Resolve-Path -Path $PSScriptRoot\..\Modules\Helpers.psm1).Path

try {

    if (!((Get-AzureRmContext).Account)) {
        throw "You need to log in first"
    }

    # --- Retrieve configuration and parse
    $Config = Get-Content -Path (Resolve-Path -Path $FirewallRuleConfigurationPath).Path -Raw | ConvertFrom-Json

    foreach ($Subscription in $SubscriptionName) {
        Write-Log -LogLevel Information -Message "Searching for Sql Servers matching $ServerNamePattern in $Subscription"
        $null = Select-AzureRmSubscription -SubscriptionName $Subscription
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

                $FirewallRule = Get-AzureRmSqlServerFirewallRule -FirewallRuleName $Rule.Name -ServerName $ServerName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue

                if (!$FirewallRule) {
                    Write-Log -LogLevel Information -Message "  -> Creating firewall rule $($Rule.Name)"

                    if (!$DryRun.IsPresent){
                        $null = New-AzureRmSqlServerFirewallRule @FirewallRuleParameters -ErrorAction Stop
                    }
                } else {
                    Write-Log -LogLevel Information -Message "  -> Updating firewall rule $($Rule.Name)"
                    if (!$DryRun.IsPresent){
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