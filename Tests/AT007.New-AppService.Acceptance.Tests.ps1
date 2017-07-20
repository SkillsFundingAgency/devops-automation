$Config = Get-Content $PSScriptRoot\..\Tests\Acceptance.Config.json -Raw | ConvertFrom-Json
Push-Location -Path $PSScriptRoot\..\Infrastructure\Resources\

Describe "New-AppService Tests" -Tag "Acceptance-ARM" {

    It "Should create an App service and return no outputs" {
        $params = @{
            Location = $Config.location
            ResourceGroupName =  $Config.resourceGroupName
            AppServicePlanName = $Config.appServicePlanName
            AppServiceName = $Config.appServiceName
        }
        $Result = .\New-AppService.ps1 @params
        $Result.Count | Should Be 0
    }

    It "Should create an App service in the correct location" {
        $Result = Get-AzureRmWebApp -ResourceGroupName $Config.resourceGroupName -Name $Config.appServiceName
        $Result.Location | Should Be $Config.location
    }

    It "Should create an App service with the correct name" {
        $Result = Get-AzureRmWebApp -ResourceGroupName $Config.resourceGroupName -Name $Config.appServiceName
        $Result.Name | Should Be $Config.appServiceName
    }

    It "Should create an App service plan with the correct location" {
        $Result = Get-AzureRmAppServicePlan -ResourceGroupName $Config.resourceGroupName -Name $Config.appServicePlanName
        $Result.Location | Should Be $Config.location
    }

    It "Should create an App service plan with the correct name" {
        $Result = Get-AzureRmAppServicePlan -ResourceGroupName $Config.resourceGroupName -Name $Config.appServicePlanName
        $Result.Name | Should Be $Config.appServicePlanName
    }


}

Pop-Location