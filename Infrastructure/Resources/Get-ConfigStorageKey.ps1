<#

.SYNOPSIS
Return either the Primary or Seconday connection String to the Consig Storage account and Write to a VSTS variable.

.DESCRIPTION
Return either the Primary or Seconday connection String to the Consig Storage account and Write to a VSTS variable.

.PARAMETER Name
The name of the Storage Account

.PARAMETER useSecondary
Boolean Switch to Return Secondary String

.EXAMPLE
.\Get-ConfigStorageKey.ps1  -Name stracc

.EXAMPLE
.\Get-ConfigStorageKey.ps1  -Name stracc -useSecondary

#>

Param(
    [Parameter(Mandatory = $true)]
    [String]$Name,
    [Parameter(Mandatory = $false)]
    [switch]$UseSecondary = $false)


# --- Import Azure H
Import-Module (Resolve-Path -Path $PSScriptRoot\..\Modules\Azure.psm1).Path
Import-Module (Resolve-Path -Path $PSScriptRoot\..\Modules\Helpers.psm1).Path
try {

    Write-Log -LogLevel Information -Message "Checking for existing Storage Account"
    # --- Check if storage account exists in our subscription

    $StorageAccount = Get-AzureRmResource -ResourceName $Name -ErrorAction SilentlyContinue

    # --- If the Storage Account doesn't exist, erorr
    if (!$StorageAccount) {
        Write-Log -LogLevel Information -Message "StorageAccount $Name Does not exist"
    }

    # --- If the storage account exists in this subscription get the key and set the env variable
    if ($StorageAccount -and !$UseSecondary ) {
        $Key = (Invoke-AzureRmResourceAction -Action listKeys -ResourceType "Microsoft.ClassicStorage/storageAccounts" -ApiVersion "2016-11-01" -ResourceGroupName $($StorageAccount.ResourceGroupName) -ResourceName $($StorageAccount.Name) -force).primaryKey
        $ConnectionString = "DefaultEndpointsProtocol=https;AccountName=$($Name);AccountKey=$($Key)"
        Write-Output ("##vso[task.setvariable variable=ConfigurationStorageConnectionString;issecret=true]$($ConnectionString)")
    }
    elseif ($StorageAccount) {
        $Key = (Invoke-AzureRmResourceAction -Action listKeys -ResourceType "Microsoft.ClassicStorage/storageAccounts" -ApiVersion "2016-11-01" -ResourceGroupName $($StorageAccount.ResourceGroupName)  -ResourceName $($StorageAccount.Name) -force).secondaryKey
        $ConnectionString = "DefaultEndpointsProtocol=https;AccountName=$($Name);AccountKey=$($Key)"
        Write-Output ("##vso[task.setvariable variable=ConfigurationStorageConnectionString;issecret=true]$($ConnectionString)")
    }
    else {
        Write-log -LogLevel Information -Message "No Account Found"
    }
}
catch {
    throw "$_"
}
