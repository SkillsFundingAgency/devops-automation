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

.PARAMETER TableName
The names of one or more Tables to create in the Storage Account

.PARAMETER QueueName
The names of one or more Queues to create in the Storage Account

.EXAMPLE
.\New-ClassicStorageAccount.ps1 -Location "West Europe" -Name stracc

.EXAMPLE
.\New-ClassicStorageAccount.ps1 -Location "West Europe" -Name stracc -ContainerName public,private,images

.EXAMPLE
.\New-ClassicStorageAccount.ps1 -Location "West Europe" -Name stracc -ContainerName public,private,images -TableName strtbl -QueueName q1,q2

#>

Param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("West Europe", "North Europe")]
    [String]$Location = $ENV:Location,
    [Parameter(Mandatory = $true)]
    [String]$Name,
    [Parameter(Mandatory = $false)]
    [String[]]$ContainerName,
    [Parameter(Mandatory = $false)]
    [String[]]$TableName,
    [Parameter(Mandatory = $false)]
    [String[]]$QueueName
)

# --- Import Azure Helpers
Import-Module (Resolve-Path -Path $PSScriptRoot\..\Modules\Azure.psm1).Path
Import-Module (Resolve-Path -Path $PSScriptRoot\..\Modules\Helpers.psm1).Path

Write-Log -LogLevel Information -Message "Checking for existing Storage Account"
# --- Check if storage account exists in our subscription 
$StorageAccount = Get-AzureStorageAccount -StorageAccountName $Name -ErrorAction SilentlyContinue
 
# --- Check if the resource name has been taken elsewhere
$StorageAccountNameTest = Test-AzureName -Storage $Name

# --- If the Storage Account doesn't exist, create it
if (!$StorageAccount -and !$StorageAccountNameTest) {
    try {
        Write-Log -LogLevel Information -Message "Creating Storage Account $Name"
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
                Write-Log -LogLevel Information -Message "Creating container $Container"
                $null = New-AzureStorageContainer -Name $Container -Permission Off 
            }
            catch {
                throw "Could not create container $Container : $_"
            }
        }
    }
}

# --- Create tables in the storage account if required
if ($TableName -and $StorageAccount) {
    $Subscription = Get-AzureSubscription -Current
    Set-AzureSubscription -CurrentStorageAccountName $Name -SubscriptionId $Subscription.SubscriptionId
    foreach ($Table in $TableName) {
        $TableExists = Get-AzureStorageTable -Name $Table -ErrorAction SilentlyContinue
        if (!$TableExists) {
            try {
                Write-Log -LogLevel Information -Message "Creating table $Table"
                $null = New-AzureStorageTable -Name $Table
            } catch {
                throw "Could not create table $Table : $_"
            }
        }
    }
}

# --- Create queues in the storage account if required
if ($QueueName -and $StorageAccount) {
    $Subscription = Get-AzureSubscription -Current
    Set-AzureSubscription -CurrentStorageAccountName $Name -SubscriptionId $Subscription.SubscriptionId
    foreach ($Queue in $QueueName) {
        $QueueExists = Get-AzureStorageQueue -Name $Queue -ErrorAction SilentlyContinue
        if (!$QueueExists) {
            try {
                Write-Log -LogLevel Information -Message "Creating queue $Queue"
                $null = New-AzureStorageQueue -Name $Queue
            } catch {
                throw "Could not create queue $QueueName : $_"
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