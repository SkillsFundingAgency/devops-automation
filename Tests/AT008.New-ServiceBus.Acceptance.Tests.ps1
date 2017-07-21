$Config = Get-Content $PSScriptRoot\..\Tests\Acceptance.Config.json -Raw | ConvertFrom-Json
Push-Location -Path $PSScriptRoot\..\Infrastructure\Resources\

Describe "New-ServiceBus Tests" -Tag "Acceptance-ARM" {

    It "Should create a Service Bus and return one output" {
        $Params = @{
            Location = $Config.location
            ResourceGroupName = $($Config.resourceGroupName+$Config.suffix)
            NamespaceName = $($Config.serviceBusNamespaceName+$Config.suffix)
            QueueName = $Config.serviceBusQueueName
        }
        $Result = .\New-ServiceBus.ps1 @params
        $Result.Count | Should Be 1
    }

    It "Should create a Service Bus in the correct location" {
        $Result = Get-AzureRmServiceBusNamespace -Name $($Config.serviceBusNamespaceName+$Config.suffix) -ResourceGroup $($Config.resourceGroupName+$Config.suffix)
        $Result.Location | Should Be $Config.location
    }

    It "Should create specified Service Bus queues" {
        foreach($Queue in $Config.serviceBusQueueName){
            $Queue.Trim()
            $ExistingQueue = Get-AzureRmServiceBusQueue -ResourceGroup $($Config.resourceGroupName+$Config.suffix) -NamespaceName $($Config.serviceBusNamespaceName+$Config.suffix) -QueueName $Queue
            $ExistingQueue.Name | Should Be $Queue
        }
    }
}

Pop-Location