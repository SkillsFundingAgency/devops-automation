$Config = Get-Content $PSScriptRoot\..\Tests\Acceptance.Config.json -Raw | ConvertFrom-Json
Push-Location -Path $PSScriptRoot\..\Infrastructure\Resources\

Describe "New-ApplicationInsights Tests" -Tag "Acceptance-ARM" {

    It "Should create an ApplicationInsights and return a valid instrumentation key" {
        $Result = .\New-ApplicationInsights.ps1 -Location $Config.location -Name $($Config.appInsightsName+$Config.suffix) -ResourceGroupName $($Config.ResourceGroupName+$Config.suffix)
        $Result.Count | Should Be 1
        $Result.Contains("InstrumentationKey") | Should Be $true
        $Result = $Result.Replace("##vso[task.setvariable variable=InstrumentationKey;]", "")
        $ValidGuid = [System.Guid]::NewGuid()
        $Success = [System.Guid]::TryParse($Result,[ref]$ValidGuid);
        $Success | Should Be $true
    }
}

Pop-Location