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
    [Parameter(Mandatory = $true, Position = 0)]    
    [String]$ServerName,
    [Parameter(Mandatory = $true, Position = 1)]
    [String]$FirewallRuleConfiguration,
    [Parameter(Mandatory = $false, Position = 2)]
    [Switch]$RemoveLegacyRules
)

# --- Import helper modules
Import-Module (Resolve-Path -Path $PSScriptRoot\..\Modules\Azure.psm1).Path
Import-Module (Resolve-Path -Path $PSScriptRoot\..\Modules\Helpers.psm1).Path

# --- Check for an existing sql server in the subscription
Write-Log -LogLevel Information -Message "Checking for SQL Server $ServerName"
$SQLServer = Find-AzureRmResource -ResourceNameEquals $ServerName

if (!$SQLServer) {
    Write-Log -LogLevel Error -Message "Could not find SQL Server with name $ServerName"
    throw "Could not find SQL Server with name $ServerName"
}

# --- Set Resource Group Name
$ResourceGroupName = $SQLServer.ResourceGroupName

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
    Write-Log -LogLevel Information -Message "Creating firewall entry $($Rule.Name)"
    Set-SqlServerFirewallRule @FirewallRuleParameters -Verbose:$VerbosePreference -Confirm:$false
}

# --- If the rule exists in Azure but not in the config it should be removed
if ($PSBoundParameters.ContainsKey("RemoveLegacyRules")) {
    $ExistingRuleNames = Get-AzureRmSqlServerFirewallRule -ResourceGroupName $ResourceGroupName -ServerName $ServerName | Select-Object -ExpandProperty FirewallRuleName
    $ConfigRuleNames = $Config | Select-Object -ExpandProperty Name
    foreach ($ExistingRule in $ExistingRuleNames) {
        if (!$ConfigRuleNames.Contains($ExistingRule)) {
            Write-Log -LogLevel Warning -Message "Removing Firewall Rule $ExistingRule"
            $null = Remove-AzureRmSqlServerFirewallRule -ResourceGroupName $ResourceGroupName -ServerName $ServerName -FirewallRuleName $ExistingRule -Force
        }
    }
}