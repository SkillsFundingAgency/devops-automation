$Config = Get-Content $PSScriptRoot\..\Tests\Acceptance.Config.json -Raw | ConvertFrom-Json
Push-Location -Path $PSScriptRoot\..\Infrastructure\Resources\

Describe "New-ClassicStorageAccount Tests" -Tag "Acceptance-ASM" {

    It "Should create a Storage Account and return one output" {
        $Params = @{
            Location = $Config.location
            Name = $($Config.classicStorageAccountName+$Config.suffix)
            ContainerName = $Config.classicStorageContainerName
        }
        $Result = .\New-ClassicStorageAccount.ps1 @Params
        $Result.Count | Should Be 1
    }

    It "Should create a Storage Account with the correct name" {
        $Result = Get-AzureStorageAccount -StorageAccountName $($Config.classicStorageAccountName+$Config.suffix)
        $Result.StorageAccountName | Should Be $($Config.classicStorageAccountName+$Config.suffix)
    }

    It "Should create a Storage Account in the correct location" {
        $Result = Get-AzureStorageAccount -StorageAccountName $($Config.classicStorageAccountName+$Config.suffix)
        $Result.Location | Should Be $Config.location
    }

    It "Should create a Storage Container in the Storage Account" {
        $Subscription = Get-AzureSubscription -Current
        Set-AzureSubscription -CurrentStorageAccountName $($Config.classicStorageAccountName+$Config.suffix) -SubscriptionId $Subscription.SubscriptionId
        $Container = Get-AzureStorageContainer -Name $Container -ErrorAction SilentlyContinue
        $Container.Count | Should Be 1
    }

    It "Should create a Storage Container with the correct name" {
        $Container = (Get-AzureStorageContainer)[0]
        $Container.Name | Should Be $Config.classicStorageContainerName
    }
}

Pop-Location