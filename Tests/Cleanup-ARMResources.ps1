[CmdletBinding()]
Param()
$Config = Get-Content $PSScriptRoot\..\Tests\Acceptance.Config.json -Raw | ConvertFrom-Json

$ResourceGroupName = "$($Config.resourceGroupName)$($Config.suffix)"
$CloudServiceName = "$($Config.cloudServiceName)$($Config.suffix)"
$StorageAccountName = "$($Config.classicStorageAccountName)$($Config.suffix)"

Write-Verbose -Message "Cleaning up Resource Group"
$ResourceGroup = Get-AzureRMResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
if ($ResourceGroup) {
    Remove-AzureRmResourceGroup -Name $ResourceGroupName -Force
}
else {
    Write-Verbose -Message "Resource group does not exist"    
}

Write-Verbose -Message "Cleaning up Cloud service Resource Group"
$CloudServiceResourceGroup = Get-AzureRmResourceGroup -Name $CloudServiceName -ErrorAction SilentlyContinue
if ($CloudServiceResourceGroup) {
    Remove-AzureRmResourceGroup -Name $CloudServiceName -Force
}
else {
    Write-Verbose -Message "Cloud Service resource group does not exist"
}

Write-Verbose -Message "Cleaning up Storage account Resource Group"
$StorageAccountResourceGroupResources = New-Object System.Collections.ArrayList
ForEach ($resource in (Find-AzureRmResource -ResourceGroupNameEquals "Default-Storage-$($Config.location.replace(' ',''))")) {
    $null = $StorageAccountResourceGroupResources.Add($resource)
}

if ($StorageAccountResourceGroupResources.Count -eq 1) {
    if ($StorageAccountResourceGroupResources[0].ResourceName -like $StorageAccountName) {
        Remove-AzureRmResourceGroup -Name "Default-Storage-$($Config.location.replace(' ',''))" -Force
    }
}
elseif ($StorageAccountResourceGroupResources.Count -gt 1) {
    Write-Verbose -Message "Default storage account resource group contains more than one resource, will not be deleted"
}