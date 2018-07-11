$Config = Get-Content $PSScriptRoot\..\Tests\Acceptance.Config.json -Raw | ConvertFrom-Json
Push-Location -Path $PSScriptRoot\..\Infrastructure\Resources\

Describe "New-ServiceBus Tests" -Tag "Acceptance-ARM" {

    $ResourceGroupName = "$($Config.resourceGroupName)$($Config.suffix)"
    $ServiceBusName = "$($Config.serviceBusNamespaceName)$($Config.suffix)"

    # --- Define global properties for this test block
    $TopicDefinitionPath = "TestDrive:\sbq.topic.definition.json"
    $null = $Config.ServiceBusTopicDefinition | ConvertTo-Json | Set-Content -Path $TopicDefinitionPath

    It "Should create a Service Bus and return two outputs" {
        $Params = @{
            Location          = $Config.location
            ResourceGroupName = $ResourceGroupName
            NamespaceName     = $ServiceBusName
        }
        $Result = .\New-ServiceBus.ps1 @params
        $Result.Count | Should Be 2
    }

    It "Should create a Service Bus in the correct location" {
        $Result = Get-AzureRmServiceBusNamespace -Name $ServiceBusName -ResourceGroup $ResourceGroupName
        $Result.Location | Should Be $Config.location
    }

    It "Should create a Queue on an existing service bus" {
        $Params = @{
            Location          = $Config.location
            ResourceGroupName = $ResourceGroupName
            NamespaceName     = $ServiceBusName
            QueueName         = $Config.serviceBusQueueName
        }
        $Result = .\New-ServiceBus.ps1 @params

        foreach ($Queue in $Config.serviceBusQueueName) {
            $Queue.Trim()
            $ExistingQueue = Get-AzureRmServiceBusQueue -ResourceGroup $ResourceGroupName -NamespaceName $ServiceBusName -QueueName $Queue
            $ExistingQueue.Name | Should Be $Queue
        }

    }

    It "Should create a Topic on an existing service bus" {

        # --- Re run creation script this but this time use the Topic parameter set
        $Params = @{
            Location          = $Config.location
            ResourceGroupName = $ResourceGroupName
            NamespaceName     = $ServiceBusName
            TopicDefinition   = $TopicDefinitionPath
        }

        $Result = .\New-ServiceBus.ps1 @params

        $TopicName = $Config.ServiceBusTopicDefinition[0].TopicName
        $Result = Get-AzureRmServiceBusTopic -ResourceGroup $ResourceGroupName -NamespaceName $ServiceBusName -TopicName $TopicName -ErrorAction SilentlyContinue
        $Result.Name | Should Be $TopicName
    }

    It "Should create a subscription on an existing topic" {

        $TopicName = $Config.ServiceBusTopicDefinition[0].TopicName
        $SubscriptionName = $Config.ServiceBusTopicDefinition[0].Subscription[0]
        $Result = Get-AzureRmServiceBusSubscription -ResourceGroup $ResourceGroupName -NamespaceName $ServiceBusName -TopicName $TopicName -SubscriptionName $SubscriptionName -ErrorAction SilentlyContinue
        $Result.Name | Should Be $SubscriptionName
    }

    # --- Access Policies
    It "Should create an authorization rule named ReadWrite" {
        {
            if ((((Get-Module AzureRM -ListAvailable | Sort-Object { $_.Version.Major } -Descending).Version.Major))[0] -gt 5) {
                Get-AzureRmServiceBusAuthorizationRule -ResourceGroupName $ResourceGroupName -Namespace $ServiceBusName -AuthorizationRuleName ReadWrite
            }
            else {
                Get-AzureRmServiceBusNamespaceAuthorizationRule -ResourceGroup $ResourceGroupName -NamespaceName $ServiceBusName -AuthorizationRuleName ReadWrite
            }
        } | Should Not Throw
    }

    It "Should create an authorization rule with Send and Listen rights" {
        if ((((Get-Module AzureRM -ListAvailable | Sort-Object { $_.Version.Major } -Descending).Version.Major))[0] -gt 5) {
            $AuthorizationRule = Get-AzureRmServiceBusAuthorizationRule -ResourceGroupName $ResourceGroupName -Namespace $ServiceBusName -AuthorizationRuleName ReadWrite
        }
        else {
            $AuthorizationRule = Get-AzureRmServiceBusNamespaceAuthorizationRule -ResourceGroup $ResourceGroupName -NamespaceName $ServiceBusName -AuthorizationRuleName ReadWrite
        }
        $Eval = $AuthorizationRule.Rights -contains "Send" -and $AuthorizationRule.Rights -contains "Listen"
        $Eval | Should Be $true
    }

    It "Should create an authorization rule named Read" {
        {
            if ((((Get-Module AzureRM -ListAvailable | Sort-Object { $_.Version.Major } -Descending).Version.Major))[0] -gt 5) {
                Get-AzureRmServiceBusAuthorizationRule -ResourceGroupName $ResourceGroupName -Namespace $ServiceBusName -AuthorizationRuleName Read
            }
            else {
                Get-AzureRmServiceBusNamespaceAuthorizationRule -ResourceGroup $ResourceGroupName -NamespaceName $ServiceBusName -AuthorizationRuleName Read
            }
        } | Should Not Throw
    }

    It "Should create an authorization rule with Listen rights" {
        if ((((Get-Module AzureRM -ListAvailable | Sort-Object { $_.Version.Major } -Descending).Version.Major))[0] -gt 5) {
            $AuthorizationRule = Get-AzureRmServiceBusAuthorizationRule -ResourceGroupName $ResourceGroupName -Namespace $ServiceBusName -AuthorizationRuleName Read
        }
        else {
            $AuthorizationRule = Get-AzureRmServiceBusNamespaceAuthorizationRule -ResourceGroup $ResourceGroupName -NamespaceName $ServiceBusName -AuthorizationRuleName Read
        }
        $Eval = $AuthorizationRule.Rights -contains "Listen"
        $Eval | Should Be $true
    }
}

Pop-Location
