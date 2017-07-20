$Config = Get-Content $PSScriptRoot\..\Tests\Acceptance.Config.json -Raw | ConvertFrom-Json
Push-Location -Path $PSScriptRoot\..\Infrastructure\Resources\

Describe "New-ServiceBus Tests" -Tag "Acceptance-ARM" {

    It "Should create a Service Bus and return one output" {
        $params = @{
            Location = $Config.location
            ResourceGroupName =  $Config.resourceGroupName
            NamespaceName = $Config.serviceBusNamespaceName
            QueueName = [string[]]$Config.serviceBusQueueName
        }
        $Result = .\New-ServiceBus.ps1 @params
        $Result.Count | Should Be 1
    }

    It "Should create a Service Bus in the correct location" {
        $Result = Get-AzureRmServiceBusNamespace  -Name $Config.serviceBusNamespaceName -ResourceGroup $Config.resourceGroupName
        $Result.Location | Should Be $Config.location
    }

    It "Should create specified Service Bus queues" {
        foreach($queue in [string[]]$Config.serviceBusQueueName){
            $queue.Trim()
            $ExistingQueue = Get-AzureRmServiceBusQueue -ResourceGroup $Config.resourceGroupName -NamespaceName $Config.serviceBusNamespaceName -QueueName $queue
            $ExistingQueue.Name | Should Be $queue
        }
    }
}

Pop-Location