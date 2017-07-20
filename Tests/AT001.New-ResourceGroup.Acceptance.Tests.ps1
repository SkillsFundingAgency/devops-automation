$Config = Get-Content $PSScriptRoot\..\Tests\Acceptance.Config.json -Raw | ConvertFrom-Json
Push-Location -Path $PSScriptRoot\..\Infrastructure\Resources\

Describe "New-ResourceGroup Tests" -Tag "Acceptance-ARM" {

    It "Should create a Resouce Group and return two outputs" {
        $Result = .\New-ResourceGroup.ps1 -Location "$($Config.location)" -Name $Config.resourceGroupName
        $Result.Count | Should Be 2
    }

    It "Should create a Resource Group with the correct name" {
        $Result = Get-AzureRMResourceGroup -Name $Config.resourceGroupName -ErrorAction SilentlyContinue
        $Result.ResourceGroupName | Should Be $Config.resourceGroupName
    }

    It "Should create a Resource Group in the correct location" {
        $Result = Get-AzureRMResourceGroup -Name $Config.resourceGroupName -Location "$Config.location"
        $Result.location | Should Be $Config.location.Replace(" ","").ToLower()
    }
}

Pop-Location