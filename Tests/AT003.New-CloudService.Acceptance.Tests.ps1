$Config = Get-Content $PSScriptRoot\..\Tests\Acceptance.Config.json -Raw | ConvertFrom-Json
Push-Location -Path $PSScriptRoot\..\Infrastructure\Resources\

Describe "New-CloudService Tests" -Tag "Acceptance-ASM" {

    $CloudServiceName = "$($Config.cloudServiceName)$($Config.suffix)"

    It "Should create a Cloud Service and return no outputs" {
        $Result = .\New-CloudService.ps1 -Location $Config.location -Name $CloudServiceName
        $Result.Count | Should Be 0
    }

    It "Should not throw on subsequent runs" {
        .\New-CloudService.ps1 -Location $Config.location -Name $CloudServiceName | Should not throw
    }

    It "Should create a Cloud Service with the correct name" {
        $Result = Get-AzureService -ServiceName $CloudServiceName -ErrorAction SilentlyContinue
        $Result.ServiceName | Should Be $CloudServiceName
    }

    It "Should create a Cloud Service in the correct location" {
        $Result = Get-AzureService -ServiceName $CloudServiceName -ErrorAction SilentlyContinue
        $Result.Location | Should Be $Config.location
    }
}

Pop-Location