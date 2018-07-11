<#

.SYNOPSIS
Update the firewall of an Cosmos Db Account

.DESCRIPTION
Update the firewall of an Cosmos Db Account

.PARAMETER SubscriptionName
One or more subscriptions to interogate

.PARAMETER ServerNamePattern
One or more subscriptions to interogate

.PARAMETER FirewallRuleConfiguration
The path to the firewall rule JSON configuration document

Configuration is an array of objects and should be represented as follows:

[
    {
        "Name": "AllowAllWindowsAzureIps",
        "ipRangeFilter": "0.0.0.0"
    },
    {
        "Name": "Rule1",
        "ipRangeFilter": "xxx.xxx.xxx.xxx"
    },
    {
        "Name": "Rule2",
        "ipRangeFilter": "xxx.xxx.xxx.xxx"
    }
]

.PARAMETER RemoveLegacyRules
If the rule exists in Azure but not in the configuration supplied it will be removed

.PARAMETER DryRun
Make a test pass with the supplied parameters. No changes will be made if this switch is passed.

.EXAMPLE

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
            Write-Log -LogLevel Information -Message "Searching for Cosmos DB Accounts matching $ServerNamePattern in $Subscription"
            $null = Select-AzureRmSubscription -SubscriptionName $Subscription

            #TODO: Migrate to version 6, ResourceNameContains logic may not be possible
            $SubscriptionCosmosDbAccs = Find-AzureRmResource -ResourceNameContains $ServerNamePattern -ResourceType "Microsoft.DocumentDb/databaseAccounts"

            foreach ($CosmosDbAcc in $SubscriptionCosmosDbAccs) {
                $ServerName = $CosmosDbAcc.Name
                Write-Log -LogLevel Information -Message "Processing Cosmos DB Account $ServerName"
                $CosmosDb = Get-AzureRmResource -ResourceId $CosmosDbAcc.ResourceId

                if ($PSBoundParameters.ContainsKey("RemoveLegacyRules")) {
                    # if the rule exists in Azure but not in the config it should be removed
                    # so rebuild the ipRangeFilter from scratch
                    $irf = @()
                }
                else {
                    # load the existing rules
                    $irf = $CosmosDb.Properties.ipRangeFilter -split ','
                }

                $FirewallChanged = $false
                # --- Create or update firewall rules on the Cosmos Db Account
                foreach ($Rule in $Config) {
                    if (-not ($irf -contains $Rule.ipRangeFilter)) {
                        Write-Log -LogLevel Information "Adding $($Rule.ipRangeFilter) to ipRangeFilter"
                        $irf += $Rule.ipRangeFilter
                        $FirewallChanged = $true
                    }
                }

                if ($PSBoundParameters.ContainsKey("RemoveLegacyRules")) {
                    $testirf = $irf -join ','
                    $FirewallChanged = $testirf -ne $CosmosDb.Properties.ipRangeFilter

                    if (!$FirewallChanged) {
                        Write-Log -LogLevel Information -Message "New rule matches existing rule, not updating"
                    }
                }

                if ($FirewallChanged -and (!$DryRun.IsPresent)) {
                    $FirewallRuleParameters = @{
                        "databaseAccountOfferType" = $CosmosDb.Properties.databaseAccountOfferType
                        "ipRangeFilter"            = $irf -join ','
                    }
                    Write-Log -LogLevel Information -Message "Updating $ServerName with $($FirewallRuleParameters.ipRangeFilter)"
                    Set-AzureRmResource -ResourceId $CosmosDbAcc.ResourceId -Properties $FirewallRuleParameters -Force
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
