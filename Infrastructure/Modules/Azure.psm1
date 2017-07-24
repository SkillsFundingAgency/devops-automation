function Wait-AzureRmResource {
    [CmdletBinding(DefaultParameterSetName="Standard")]
    Param (
        [Parameter(Mandatory=$true, ParameterSetName="ResourceGroup")]
        [String]$ResourceGroupName,
        [Parameter(Mandatory=$true)]
        [String]$ResourceName,
        [Parameter(Mandatory=$false)]
        [Int]$TimeOut = 200
    )
    
    $i = 1
    $exists = $false
    while (!$exists) {
        Write-host "Checking deployment status in $($i*5) seconds"
        Start-Sleep -s ($i * 5)
        if ($i -lt 12) { 
            $i++
        } 
        try {
            
            if ($PSCmdlet.ParameterSetName -eq "ResourceGroup") {
                $resource = Get-AzureRmResource -ResourceGroupName $ResourceGroupName -ResourceName $ResourceName
            } else {
                $resource = Find-AzureRmResource -ResourceNameEquals $ResourceName
            }

            if ($resource) {
                $exists = $true
            }
        } catch {
            Write-Host "$($_.Exception)"
        }
    }
}

function Resolve-AzureRmResource {
    <#
        .DESCRIPTION
        Use Resolve-DnsName to determine whether a resource name has been taken by another tenant/subscription

    #>
    Param (
        [Parameter(Mandatory=$true, Position=0)]
        [String]$PublicResourceFqdn
    )
    
    $NSLookupResult = Resolve-DnsName -Name $PublicResourceFqdn.ToLower() -ErrorAction SilentlyContinue
	if ($NSLookupResult.Count -gt 0 -and $NSLookupResult.IPAddress -notcontains "81.200.64.50"){
        $ResourceExists = $true
	}
    $ResourceExists
}

Function Set-SQLServerFirewallRule {
    <#

    .SYNOPSIS
    Create or update a firewall rule on an Azure SQL Server instance

    .DESCRIPTION
    Create or update a firewall rule on an Azure SQL Server instance

    .PARAMETER ResourceGroupName
    The name of the SQL Servers resource group

    .PARAMETER ServerName
    The name of the Azure SQL Server

    .PARAMETER FirewallRuleName
    The name of the firewall rule

    .PARAMETER StartIpAddress
    The start ip address in the allowed range

    .PARAMETER EndIpAddress
    The end ip address in the allowed range

    .EXAMPLE
    Set-AzureSqlServerFirewallRule -FirewallRuleName "SFA Purple" -StartIpAddress "62.253.71.89" -EndIpAddress "62.253.71.89" -ServerName $ServerName -ResourceGroupName $ResourceGroupName

    #>    
    Param (
        [Parameter(Mandatory=$true)]
        [String]$ResourceGroupName, 
        [Parameter(Mandatory=$true)]
        [String]$ServerName,                   
        [Parameter(Mandatory=$true)]
        [String]$FirewallRuleName,
        [Parameter(Mandatory=$true)]
        [String]$StartIpAddress,      
        [Parameter(Mandatory=$true)]
        [String]$EndIpAddress
    )

    try {

        # --- Does the firewall rule exist on the server?
        $FirewallRule = Get-AzureRmSqlServerFirewallRule -FirewallRuleName $FirewallRuleName -ServerName $ServerName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue

        # --- If the firewall doesn't exist, create it. If it does, update it
        $FirewallRuleParameters = @{
            ResourceGroupName = $ResourceGroupName
            ServerName = $ServerName
            FirewallRuleName = $FirewallRuleName
            StartIpAddress = $StartIpAddress
            EndIpAddress = $EndIpAddress
        }

        if (!$FirewallRule) {
            Write-Verbose -Message "Creating firewall rule $FireWallRuleName"
            $null = New-AzureRmSqlServerFirewallRule @FirewallRuleParameters -ErrorAction Stop
        } else {
            Write-Verbose -Message "Updating firewall rule $FirewallRuleName"
            $null = Set-AzureRmSqlServerFirewallRule @FirewallRuleParameters -ErrorAction Stop
        }
    }catch {
        throw "Could not set SQL server firewall rule $FirewallRuleName on $($ServerName): $_"
    }
}