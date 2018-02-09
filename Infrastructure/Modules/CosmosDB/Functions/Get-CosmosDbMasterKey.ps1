function Get-CosmosDbMasterKey {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $ResourceGroupName,
        [Parameter(Mandatory = $true)]
        $CosmosDbAccountName,
        [Parameter()]
        [switch]$Secondary
    )

    $IsLoggedIn = (Get-AzureRMContext -ErrorAction SilentlyContinue).Account
    if (!$IsLoggedIn) {
        throw "You are not logged in. Run Add-AzureRmAccount to continue"
    }

    $Keys = Invoke-AzureRmResourceAction -Action listKeys -ResourceType "Microsoft.DocumentDb/databaseAccounts" `
        -ApiVersion "2015-04-08" -ResourceGroupName $ResourceGroupName -Name $CosmosDbAccountName -Force

    if ($Secondary.IsPresent) {
        return $Keys.secondaryMasterKey
    }
    else {
        return $Keys.primaryMasterKey
    }
}
