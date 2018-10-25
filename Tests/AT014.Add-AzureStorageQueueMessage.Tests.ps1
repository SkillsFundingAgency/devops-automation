$Config = Get-Content $PSScriptRoot\..\Tests\Acceptance.Config.json -Raw | ConvertFrom-Json
Push-Location -Path $PSScriptRoot\..\Infrastructure\Resources\
Describe "Add-AzureStorageQueueMessage Tests" -Tag "Acceptance-ARM" {

    $StorageAccountName = "$($Config.armStorageAccountName)$($Config.suffix)"
    $ResourceGroupName = "$($Config.resourceGroupName)$($Config.suffix)"
    $StorageQueueName = "$($Config.classicStorageQueueName)$($Config.suffix)"
    $StorageQueueMessage = "$($Config.classicStorageQueueMessage)$($Config.suffix)"

    try {
        # --- Check if storage account exists in our subscription
        if ((((Get-Module AzureRM -ListAvailable | Sort-Object { $_.Version.Major } -Descending).Version.Major))[0] -ge 5) {
            $StorageAccountResource = Get-AzureRmResource -Name $StorageAccountName -ResourceType "Microsoft.Storage/storageAccounts"
        }
        else {
            $StorageAccountResource = Find-AzureRmResource -ResourceNameEquals $StorageAccountName -ResourceType "Microsoft.Storage/storageAccounts"
        }

        if (!$StorageAccountResource) {
            "Could not find storage account $StorageAccountName. Create it."
            New-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName -Location "West Europe" -Name $StorageAccountName -SkuName Standard_LRS
        }

        $StorageAccountKey = (Get-AzureRmStorageAccountKey -ResourceGroupName $ResourceGroupName -Name $StorageAccountName)[0].Value
        $StorageAccountContext = New-AzureStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey
        $Queue = New-AzureStorageQueue -Name $StorageQueueName -Context $StorageAccountContext
    } catch {
        throw $_
    }

    It "Should complete succesfully and return one output with an empty message" {
        $null = .\Add-AzureStorageQueueMessage.ps1 -ResourceGroupName $ResourceGroupName -StorageAccountName $StorageAccountName `
                    -StorageQueueName $StorageQueueName
        $Output = $Queue.CloudQueue.GetMessage()
        $Queue.CloudQueue.DeleteMessage($Output)
        $Output.Count | Should Be 1
    }

    It "Should complete succesfully and return one output with a specific message" {
        $null = .\Add-AzureStorageQueueMessage.ps1 -ResourceGroupName $ResourceGroupName -StorageAccountName $StorageAccountName `
                    -StorageQueueName $StorageQueueName -MessageContent $StorageQueueMessage
        $Output = $Queue.CloudQueue.GetMessage()
        $Queue.CloudQueue.DeleteMessage($Output)
        $Output.Count | Should Be 1
        $Output.AsString | Should Be $StorageQueueMessage
    }

}

Pop-Location
