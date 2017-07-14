function Wait-AzureRmResource($ResourceGroupName, $ResourceName, $timeout = 200) {
    $i = 1
    $exists = $false
    while (!$exists) {
        Write-host "Checking deployment status in $($i*5) seconds"
        Start-Sleep -s ($i * 5)
        if ($i -lt 12) { 
            $i++
        } 
        try {
            $resource = Get-AzureRmResource -ResourceGroupName $ResourceGroupName -ResourceName $ResourceName
            if ($resource) {
                $exists = $true
            }
        }
        catch {}
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