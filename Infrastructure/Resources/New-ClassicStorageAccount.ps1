<#

.SYNOPSIS
Create a classic Storage Account.

.DESCRIPTION
Create a classic Storage Account. Optionally this script supports adding containers to the account

.PARAMETER Location
The location of the classic Storage Account

.PARAMETER Name
The name of the Storage Account

.PARAMETER ContainerName
The names of one or more Containers to create in the Storage Account

.EXAMPLE
.\New-ClassicStorageAccount.ps1 -Location "West Europe" -Name stracc

.EXAMPLE
.\New-ClassicStorageAccount.ps1 -Location "West Europe" -Name stracc -ContainerName public,private,images

#>

Param(
	[Parameter(Mandatory = $false)]
	[ValidateNotNullOrEmpty()]
    [String]$Location = $ENV:Location,
    [Parameter(Mandatory = $true)]
    [String]$Name,
    [Parameter(Mandatory = $false)]
    [String[]]$ContainerName
)

# --- Import Azure Helpers
Import-Module (Resolve-Path -Path $PSScriptRoot\..\Modules\Azure.psm1).Path

Write-Host "Checking for existing Storage Account"	 
$ExistingStorageAccount = Get-AzureStorageAccount -StorageAccountName $Name -ErrorAction SilentlyContinue
 
# --- If the Storage Account doesn't exist, create it
if (!$ExistingStorageAccount) {
	try {
		Write-Host "Creating Storage Account $Name"
		$null = New-AzureStorageAccount -Location $Location -StorageAccountName $Name
	} catch {
		throw "Could not create Storage Account $Name"
	}
}

# --- Create containers in the storage account if required
if ($ContainerName) {
	$Subscription = Get-AzureSubscription -Current
	Set-AzureSubscription -CurrentStorageAccountName $Name -SubscriptionId $Subscription.SubscriptionId
	foreach ($Container in $ContainerName) {
		$ContainerExists = Get-AzureStorageContainer -Name $Container -ErrorAction SilentlyContinue
		if (!$ContainerExists) {
			try {
				Write-Host "Creating container $Container"
				$null = New-AzureStorageContainer -Name $Container -Permission Off 
			} catch {
				throw "Could not create container $Container : $_"
			}
		}
	}
}

Write-Host "[Service Online: $Name]" -ForegroundColor Green

$Key = Get-AzureStorageKey -StorageAccountName $Name
$ConnectionString = "DefaultEndpointsProtocol=https;AccountName=$($Name);AccountKey=$($key.Primary)"
Write-Output ("##vso[task.setvariable variable=StorageConnectionString;]$($ConnectionString)")