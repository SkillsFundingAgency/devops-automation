<#

.SYNOPSIS
Create a classic Storage Account.

.DESCRIPTION
Create a classic Storage Account. Optionally this script supports adding containers to the account

.PARAMETER Location
The location of the Resource Group. This is limited to West Europe and North Europe

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
    [ValidateSet("West Europe", "North Europe")]
    [String]$Location = $ENV:Location,
    [Parameter(Mandatory = $true)]
    [String]$Name,
    [Parameter(Mandatory = $false)]
    [String[]]$ContainerName
)

# --- Import Azure Helpers
Import-Module (Resolve-Path -Path $PSScriptRoot\..\Modules\Azure.psm1).Path

Write-Verbose -Message "Checking for existing Storage Account"
# --- Check if storage account exists in our subscrption 
$StorageAccount = Get-AzureStorageAccount -StorageAccountName $Name -ErrorAction SilentlyContinue
 
# --- Check if the resource name has been taken elsewhere
$StorageAccountNameTest = Test-AzureName -Storage $Name

# --- If the Storage Account doesn't exist, create it
if (!$StorageAccount -and !$StorageAccountNameTest) {
    try {
        Write-Verbose -Message "Creating Storage Account $Name"
        $StorageAccount = New-AzureStorageAccount -Location $Location -StorageAccountName $Name
    }
    catch {
        throw "Could not create Storage Account $Name"
    }
}

# --- Create containers in the storage account if required
if ($ContainerName -and $StorageAccount) {
    $Subscription = Get-AzureSubscription -Current
    Set-AzureSubscription -CurrentStorageAccountName $Name -SubscriptionId $Subscription.SubscriptionId
    foreach ($Container in $ContainerName) {
        $ContainerExists = Get-AzureStorageContainer -Name $Container -ErrorAction SilentlyContinue
        if (!$ContainerExists) {
            try {
                Write-Verbose -Message "Creating container $Container"
                $null = New-AzureStorageContainer -Name $Container -Permission Off 
            }
            catch {
                throw "Could not create container $Container : $_"
            }
        }
    }
}

# --- If the storage account exists in this subscription get the key and set the env variable
if ($StorageAccount) {
    $Key = (Get-AzureStorageKey -StorageAccountName $Name).Primary	
    $ConnectionString = "DefaultEndpointsProtocol=https;AccountName=$($Name);AccountKey=$($Key)"
    Write-Output ("##vso[task.setvariable variable=StorageConnectionString;]$($ConnectionString)")
}