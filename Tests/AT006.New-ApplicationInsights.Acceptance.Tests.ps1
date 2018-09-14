$Config = Get-Content $PSScriptRoot\..\Tests\Acceptance.Config.json -Raw | ConvertFrom-Json
Push-Location -Path $PSScriptRoot\..\Infrastructure\Resources\

$ValidGuid = [System.Guid]::NewGuid()

Describe "New-ApplicationInsights Tests" -Tag "Acceptance-ARM" {

    $ResourceGroupName = "$($Config.ResourceGroupName)$($Config.suffix)"
    $AppInsightsName = "$($Config.appInsightsName)$($Config.suffix)"

    It "Should create an ApplicationInsights and return a valid Instrumentation Key and App Id" {
        $Result = .\New-ApplicationInsights.ps1 -Location $Config.location -Name $AppInsightsName -ResourceGroupName $ResourceGroupName
        $Result.Count | Should Be 2
        $ik = $Result | Where-Object { $_.Contains("InstrumentationKey") }
        $ik.Contains("InstrumentationKey") | Should Be $true
        $ikguid = $ik.Split("]")[1]
        $Success = [System.Guid]::TryParse($ikguid, [ref]$ValidGuid);
        $Success | Should Be $true
        $aid = $Result | Where-Object { $_.Contains("AppId") }
        $aid.Contains("AppId") | Should Be $true
        $aidguid = $aid.Split("]")[1]
        $Success = [System.Guid]::TryParse($aidguid, [ref]$ValidGuid);
        $Success | Should Be $true
    }

    It "Should return a valid Instrumentation Key and App Id on subsequent runs" {
        $Result = .\New-ApplicationInsights.ps1 -Location $Config.location -Name $AppInsightsName -ResourceGroupName $ResourceGroupName
        $Result.Count | Should Be 2
        $ik = $Result | Where-Object { $_.Contains("InstrumentationKey") }
        $ik.Contains("InstrumentationKey") | Should Be $true
        $ikguid = $ik.Split("]")[1]
        $Success = [System.Guid]::TryParse($ikguid, [ref]$ValidGuid);
        $Success | Should Be $true
        $aid = $Result | Where-Object { $_.Contains("AppId") }
        $aid.Contains("AppId") | Should Be $true
        $aidguid = $aid.Split("]")[1]
        $Success = [System.Guid]::TryParse($aidguid, [ref]$ValidGuid);
        $Success | Should Be $true
    }
}

Pop-Location
