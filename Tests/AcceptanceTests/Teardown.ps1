$ResourceGroup = Get-AzureRmResourceGroup -Name $ENV:CONFIG_ResourceGroupName -ErrorAction SilentlyContinue

if ($ResourceGroup) {

    $ApplicationInsights = Get-AzureRmResource -ResourceGroupName $ENV:CONFIG_ResourceGroupName -ResourceName $ENV:CONFIG_AppInsightsName -ResourceType "Microsoft.Insights/components"

    if ($ApplicationInsights) {
        Remove-AzureRmResource -$ApplicationInsights.ResourceId
    }

    $AppService = Get-AzureRmWebApp -ResourceGroupName $ENV:CONFIG_ResourceGroupName -Name $ENV:CONFIG_AppServiceName -ErrorAction SilentlyContinue

    if ($AppService) {
        Remove-AzureRmResource -$AppService.ResourceId
    }

    $ExistingAppServicePlan = Get-AzureRmAppServicePlan -ResourceGroupName $ENV:CONFIG_ResourceGroupName -Name $ENV:CONFIG_AppServicePlanName -ErrorAction SilentlyContinue

    if ($ExistingAppServicePlan) {
        Remove-AzureRmResource -$ExistingAppServicePlan.ResourceId
    }

    $StorageAccount = Get-AzureRmResource -ResourceGroupName $ENV:CONFIG_ResourceGroupName -ResourceName $ENV:CONFIG_StorageAccountName -ResourceType "Microsoft.ClassicStorage/storageAccounts"

    if ($StorageAccount) {
        Remove-AzureRmResource -$StorageAccount.ResourceId
    }

    $ExistingCloudService = Get-AzureRmResource -ResourceGroupName $ENV:CONFIG_ResourceGroupName -ResourceName $ENV:CONFIG_CloudServiceName

    if ($ExistingCloudService) {
        Remove-AzureRmResource -$ExistingCloudService.ResourceId
    }

    $ServiceBus = Get-AzureRmServiceBusNamespace  -Name $ENV:CONFIG_ServiceBusName -ResourceGroup $ENV:CONFIG_ResourceGroupName -ErrorAction SilentlyContinue

    if ($ServiceBus) {
        Remove-AzureRmResource -$ServiceBus.ResourceId
    }

    Remove-AzureRmResourceGroup -Name $ENV:CONFIG_ResourceGroupName
    
} else {
    Write-Host "Resource group was not created" -ForegroundColor Yellow
}