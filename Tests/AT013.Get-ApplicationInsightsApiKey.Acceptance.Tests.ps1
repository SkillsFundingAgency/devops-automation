$Config = Get-Content $PSScriptRoot\..\Tests\Acceptance.Config.json -Raw | ConvertFrom-Json
Push-Location -Path $PSScriptRoot\..\Infrastructure\Resources\

# requires AT006.New-ApplicationInsights.Acceptance.Tests.ps1 to have ran first!
$global:firstkey = $null

Describe "Get-ApplicationInsightsApiKey Tests" -Tag "Acceptance-ARM" {

    $ResourceGroupName = "$($Config.ResourceGroupName)$($Config.suffix)"
    $AppInsightsName = "$($Config.appInsightsName)$($Config.suffix)"

    It "Should return an API Key" {
        $Result = .\Get-ApplicationInsightsApiKey.ps1 -AppInsightName $AppInsightsName -ResourceGroupName $ResourceGroupName
        $Result.Count | Should Be 1
        $Result.Contains("appInsightApiKey") | Should Be $true
        $global:firstkey = $Result.Split("]")[1]
    }

    It "Should generate new API Key on subsequent runs" {
        $Result = .\Get-ApplicationInsightsApiKey.ps1 -AppInsightName $AppInsightsName -ResourceGroupName $ResourceGroupName
        $Result.Count | Should Be 1
        $Result.Contains("appInsightApiKey") | Should Be $true
        $Result.Split("]")[1] | Should Not Be $global:firstkey
    }

}

Pop-Location
