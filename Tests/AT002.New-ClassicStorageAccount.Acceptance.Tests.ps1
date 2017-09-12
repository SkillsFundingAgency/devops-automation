$Config = Get-Content $PSScriptRoot\..\Tests\Acceptance.Config.json -Raw | ConvertFrom-Json
Push-Location -Path $PSScriptRoot\..\Infrastructure\Resources\
Describe "New-ClassicStorageAccount Tests" -Tag "Acceptance-ASM" {

    $StorageAccountName = "$($Config.classicStorageAccountName)$($Config.suffix)"

    It "Should create a Storage Account and return one output" {
        $Params = @{
            Location = $Config.location
            Name = $StorageAccountName
            ContainerName = $Config.classicStorageContainerName
            TableName = $Config.classicStorageTableName
            QueueName = $Config.classicStorageQueueName
        }
        $Result = .\New-ClassicStorageAccount.ps1 @Params
        $Result.Count | Should Be 1
    }

    It "Should return one output on subsequent runs" {
        $Params = @{
            Location = $Config.location
            Name = $StorageAccountName
            ContainerName = $Config.classicStorageContainerName
        }
        $Result = .\New-ClassicStorageAccount.ps1 @Params
        $Result.Count | Should Be 1
    }

    It "Should create a Storage Account with the correct name" {
        $Result = Get-AzureStorageAccount -StorageAccountName $StorageAccountName
        $Result.StorageAccountName | Should Be $StorageAccountName
    }

    It "Should create a Storage Account in the correct location" {
        $Result = Get-AzureStorageAccount -StorageAccountName $StorageAccountName
        $Result.Location | Should Be $Config.location
    }

    It "Should create a Storage Container in the Storage Account" {
        $Subscription = Get-AzureSubscription -Current
        Set-AzureSubscription -CurrentStorageAccountName $StorageAccountName -SubscriptionId $Subscription.SubscriptionId
        $Container = Get-AzureStorageContainer -Name $Container -ErrorAction SilentlyContinue
        $Container.Count | Should Be 1
    }

    It "Should create a Storage Container with the correct name" {
        $Subscription = Get-AzureSubscription -Current
        Set-AzureSubscription -CurrentStorageAccountName $StorageAccountName -SubscriptionId $Subscription.SubscriptionId
        $Container = (Get-AzureStorageContainer)[0]
        $Container.Name | Should Be $Config.classicStorageContainerName
    }

    It "Should create a Storage Table with the correct name" {
        $Subscription = Get-AzureSubscription -Current
        Set-AzureSubscription -CurrentStorageAccountName $StorageAccountName -SubscriptionId $Subscription.SubscriptionId
        $Table = (Get-AzureStorageTable)[0]
        $Table.Name | Should Be $Config.classicStorageTableName
    }

    It "Should create a Storage Queue with the correct name" {
        $Subscription = Get-AzureSubscription -Current
        Set-AzureSubscription -CurrentStorageAccountName $StorageAccountName -SubscriptionId $Subscription.SubscriptionId
        $Queue = (Get-AzureStorageQueue)[0]
        $Queue.Name | Should Be $Config.classicStorageQueueName
    }
}

Pop-Location