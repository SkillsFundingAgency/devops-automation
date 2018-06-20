<#

.SYNOPSIS
Create an ARM Storage Container.

.DESCRIPTION
Create one or more containers in a storage account

.PARAMETER Location
The location of the Resource Group. This is limited to West Europe and North Europe

.PARAMETER Name
The name of the Storage Account

.PARAMETER ContainerName
The names of one or more Containers to create in the Storage Account

.EXAMPLE
.\New-StorageAccountContainer.ps1 -Location "West Europe" -Name stracc -ContainerName public

.EXAMPLE
.\New-StorageAccountContainer.ps1 -Location "West Europe" -Name stracc -ContainerName public,private,images

#>

Param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("West Europe", "North Europe")]
    [String]$Location = $ENV:Location,
    [Parameter(Mandatory = $true)]
    [String]$Name,
    [Parameter(Mandatory = $true)]
    [String[]]$ContainerName
)

try {
    # --- Import Azure Helpers
    Import-Module (Resolve-Path -Path $PSScriptRoot\..\Modules\Azure.psm1).Path
    Import-Module (Resolve-Path -Path $PSScriptRoot\..\Modules\Helpers.psm1).Path

    Write-Log -LogLevel Information -Message "Resolving storage account"
    # --- Check if storage account exists in our subscription
    if ((((Get-Module AzureRM -ListAvailable | Sort-Object { $_.Version.Major } -Descending).Version.Major))[0] -gt 5) {
        $StorageAccountResource = Get-AzureRmResource -Name $Name -ResourceType "Microsoft.Storage/storageAccounts"
    }
    else {
        $StorageAccountResource = Find-AzureRmResource -ResourceNameEquals $Name -ResourceType "Microsoft.Storage/storageAccounts"
    }
    if (!$StorageAccountResource) {
        throw "Could not find storage account $Name"
    }

    $StorageAccount = Get-AzureRmStorageAccount -ResourceGroupName $StorageAccountResource.ResourceGroupName -Name $Name
    $StorageAccountKey = (Get-AzureRmStorageAccountKey -ResourceGroupName $StorageAccountResource.ResourceGroupName -Name $Name)[0].Value
    $StorageAccountContext = New-AzureStorageContext -StorageAccountName $Name -StorageAccountKey $StorageAccountKey

    # --- Create containers in the storage account if required
    if ($ContainerName -and $StorageAccount) {
        foreach ($Container in $ContainerName) {
            Write-Log -LogLevel Information -Message "Checking for existing container"
            $ContainerExists = Get-AzureStorageContainer -Context $StorageAccountContext -Name $Container -ErrorAction SilentlyContinue
            if (!$ContainerExists) {
                try {
                    Write-Log -LogLevel Information -Message "Creating container $Container"
                    $null = New-AzureStorageContainer -Context $StorageAccountContext -Name $Container -Permission Off
                }
                catch {
                    throw "Could not create container $Container : $_"
                }
            }
        }
    }

    # --- If the storage account exists in this subscription get the key and set the env variable
    if ($StorageAccount) {
        $ConnectionString = "DefaultEndpointsProtocol=https;AccountName=$($Name);AccountKey=$($StorageAccountKey)"
        Write-Output ("##vso[task.setvariable variable=StorageConnectionString; issecret=true;]$($ConnectionString)")
    }
}
catch {
    throw $_
}
