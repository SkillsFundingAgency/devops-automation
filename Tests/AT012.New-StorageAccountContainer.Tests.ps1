$Config = Get-Content $PSScriptRoot\..\Tests\Acceptance.Config.json -Raw | ConvertFrom-Json
Push-Location -Path $PSScriptRoot\..\Infrastructure\Resources\
Describe "New-StorageAccountContainer Tests" -Tag "Acceptance-ARM" {

    $StorageAccountName = "$($Config.armStorageAccountName)$($Config.suffix)"
    $ResourceGroupName = "$($Config.resourceGroupName)$($Config.suffix)"
    $ContainerName = "$($Config.classicStorageContainerName)$($Config.suffix)"

    try {
        $null = New-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName -Location "West Europe" -Name $StorageAccountName -SkuName Standard_LRS
        $StorageAccountKey = (Get-AzureRmStorageAccountKey -ResourceGroupName $ResourceGroupName -Name $StorageAccountName)[0].Value
        $StorageAccountContext = New-AzureStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey
    } catch {
        throw $_
    }

    It "Should create a Storage Container in a Storage Account" {
        $null = .\New-StorageAccountContainer.ps1 -Location "West Europe" -Name $StorageAccountName -ContainerName $ContainerName
        $Container = Get-AzureStorageContainer -Context $StorageAccountContext -Name $ContainerName -ErrorAction SilentlyContinue
        $Container.Name | Should Be $ContainerName
    }

    It "Should complete succesfully and return one output" {
        $Output = .\New-StorageAccountContainer.ps1 -Location "West Europe" -Name $StorageAccountName -ContainerName $ContainerName
        $Output.Count | Should Be 1
    }

}

Pop-Location
