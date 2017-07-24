$Config = Get-Content $PSScriptRoot\..\Tests\Acceptance.Config.json -Raw | ConvertFrom-Json
Push-Location -Path $PSScriptRoot\..\Infrastructure\Resources\

Describe "New-ServiceBus Tests" -Tag "Acceptance-ARM" {

    $ResourceGroupName = "$($Config.resourceGroupName)$($Config.suffix)"
    $ServiceBusName = "$($Config.serviceBusNamespaceName)$($Config.suffix)"

    It "Should create a Service Bus and return one output" {
        $Params = @{
            Location = $Config.location
            ResourceGroupName = $ResourceGroupName
            NamespaceName = $ServiceBusName
            QueueName = $Config.serviceBusQueueName
        }
        $Result = .\New-ServiceBus.ps1 @params
        $Result.Count | Should Be 1
    }

    It "Should create a Service Bus in the correct location" {
        $Result = Get-AzureRmServiceBusNamespace -Name $ServiceBusName -ResourceGroup $ResourceGroupName
        $Result.Location | Should Be $Config.location
    }

    It "Should create specified Service Bus queues" {
        foreach($Queue in $Config.serviceBusQueueName){
            $Queue.Trim()
            $ExistingQueue = Get-AzureRmServiceBusQueue -ResourceGroup $ResourceGroupName -NamespaceName $ServiceBusName -QueueName $Queue
            $ExistingQueue.Name | Should Be $Queue
        }
    }
}

Pop-Location