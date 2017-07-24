$Config = Get-Content $PSScriptRoot\..\Tests\Acceptance.Config.json -Raw | ConvertFrom-Json
Push-Location -Path $PSScriptRoot\..\Infrastructure\Resources\

Describe "New-AppService Tests" -Tag "Acceptance-ARM" {

    $ResourceGroupName = "$($Config.resourceGroupName)$($Config.suffix)"
    $AppServicePlanName = "$($Config.appServicePlanName)$($Config.suffix)"
    $AppServiceName = "$($Config.appServiceName)$($Config.suffix)"

    It "Should create an App service and return no outputs" {
        $Params = @{
            Location           = $Config.location
            ResourceGroupName  = $ResourceGroupName
            AppServicePlanName = $AppServicePlanName
            AppServiceName     = $AppServiceName
        }
        $Result = .\New-AppService.ps1 @params
        $Result.Count | Should Be 0
    }

    It "Should not throw on subsequent runs" {
        $Params = @{
            Location           = $Config.location
            ResourceGroupName  = $ResourceGroupName
            AppServicePlanName = $AppServicePlanName
            AppServiceName     = $AppServiceName
        }
        {.\New-AppService.ps1 @params} | Should not throw
    }

    It "Should create an App service in the correct location" {
        $Result = Get-AzureRmWebApp -ResourceGroupName $ResourceGroupName -Name $AppServiceName
        $Result.Location | Should Be $Config.location
    }

    It "Should create an App service with the correct name" {
        $Result = Get-AzureRmWebApp -ResourceGroupName $ResourceGroupName -Name $AppServiceName
        $Result.Name | Should Be $AppServiceName
    }

    # It "Should create an App service with the correct properties" {
        
    # }

    It "Should create an App service plan with the correct location" {
        $Result = Get-AzureRmAppServicePlan -ResourceGroupName $ResourceGroupName -Name $AppServicePlanName
        $Result.Location | Should Be $Config.location
    }

    It "Should create an App service plan with the correct name" {
        $Result = Get-AzureRmAppServicePlan -ResourceGroupName $ResourceGroupName -Name $AppServicePlanName
        $Result.Name | Should Be $AppServicePlanName
    }

}

Pop-Location