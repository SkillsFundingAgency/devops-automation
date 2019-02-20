$Config = Get-Content $PSScriptRoot\..\Tests\Acceptance.Config.json -Raw | ConvertFrom-Json
Push-Location -Path $PSScriptRoot\..\Infrastructure\Resources\

# requires AT003.New-ClassicStorage.Acceptance.Tests.ps1 to have ran first!
Describe "GetConfigStorageKey Tests" -Tag "Acceptance-ARM" {

    $StorageAccountName = "$($Config.classicStorageAccountName)$($Config.suffix)"

    It "Should  return one output with one parameter" {
        $Result = .\Get-ConfigStorageKey.ps1 -name $StorageAccountName
        $Result.Count | Should Be 1
    }

    It "Should  return one output with two parameter" {

        $Result = .\Get-ConfigStorageKey.ps1 -name $StorageAccountName -useSecondary $true
        $Result.Count | Should Be 1
    }
}

Pop-Location
