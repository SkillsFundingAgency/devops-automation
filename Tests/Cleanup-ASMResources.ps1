[CmdletBinding()]
Param()
$Config = Get-Content $PSScriptRoot\..\Tests\Acceptance.Config.json -Raw | ConvertFrom-Json

$CloudServiceName = "$($Config.cloudServiceName)$($Config.suffix)"
$StorageAccountName = "$($Config.classicStorageAccountName)$($Config.suffix)"

Write-Verbose "Cleaning up cloud service"
$CloudService = Get-AzureService -ServiceName $CloudServiceName -ErrorAction SilentlyContinue
if ($CloudService) {
    Write-Error "Cloud service resource group has not been removed and it cannot be removed using ASM authentication."
    Remove-AzureService -ServiceName $CloudServiceName -Force
}
else {
    Write-Verbose "Cloud service does not exist"
}

Write-Verbose "Cleaning up storage account"
$StorageAccount = Get-AzureStorageAccount -StorageAccountName $StorageAccountName -ErrorAction SilentlyContinue
if ($StorageAccount) {
    Remove-AzureStorageAccount -StorageAccountName $StorageAccountName
}
else {
    Write-Verbose "Storage account does not exist"
}