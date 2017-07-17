function Wait-AzureRmResource() {
    [CmdletBinding(DefaultParameterSetName="ResourceGroup")]
    Param (
        [Parameter(Mandatory=$true, ParameterSetName="ResourceGroup")]
        [String]$ResourceGroupName,
        [Parameter(Mandatory=$true, ParameterSetName="ResourceGroup")]
        [Parameter(Mandatory=$true, ParameterSetName="Standard")]
        [String]$ResourceName,
        [Parameter(Mandatory=$false, ParameterSetName="ResourceGroup")]
        [Parameter(Mandatory=$false, ParameterSetName="Standard")]        
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
                $resource = Find-AzureRmResource -ResourceName $ResourceName
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