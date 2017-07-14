$Seed = "efgh"
$Location = "West Europe"
$ResourceGroupName = "env-$Seed-rg"
$ClassicStorageAccountName = "env$($Seed)str"
$CloudServiceName = "env-$Seed-cs"
$AppServicePlanName = "env-$Seed-asp"
$AppServiceName = "env-$($Seed)-as"
$ServiceBusNamespaceName = "env-$Seed-ns"
$AppInsightsName = "env-$seed-ai"

.\Resources\New-ResourceGroup.ps1 -Location $Location -Name $ResourceGroupName

.\Resources\New-ClassicStorageAccount.ps1 -Name $ClassicStorageAccountName -ContainerName public,private

.\Resources\New-CloudService.ps1 -Name $CloudServiceName

.\Resources\Move-Resource.ps1 -ResourceName $CloudServiceName,$ClassicStorageAccountName -DestinationResourceGroup $ENV:ResourceGroupName

.\Resources\New-ApplicationInsights.ps1 -Name $AppInsightsName

.\Resources\New-AppService -AppServicePlanName $AppServicePlanName -AppServiceName $AppServiceName

.\Resources\New-ServiceBus.ps1 -NamespaceName $ServiceBusNamespaceName -QueueName q1,q2