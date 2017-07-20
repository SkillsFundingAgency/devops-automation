$Config = Get-Content $PSScriptRoot\..\Tests\Acceptance.Config.json -Raw | ConvertFrom-Json
Push-Location -Path $PSScriptRoot\..\Infrastructure\Resources\

Describe "Move-Resource Tests" -Tag "Acceptance-ARM" {

    It "Should move given resources to a named Resource Group" {
        $Resources = @(
            $Config.classicStorageAccountName,
            $Config.cloudServiceName
        )

        $null = .\Move-Resource.ps1 -ResourceName $Resources -DestinationResourceGroup $Config.resourceGroupName

        $ResourcesFound = 0
        $CloudServiceResourceGroup = (Find-AzureRmResource -ResourceNameEquals $Config.cloudServiceName).ResourceGroupName
        if ($CloudServiceResourceGroup -eq $Config.resourceGroupName) {
            $ResourcesFound = $ResourcesFound+1
        }

        $StorageAccountResourceGroup = (Find-AzureRmResource -ResourceNameEquals $Config.classicStorageAccountName).ResourceGroupName
        if ($StorageAccountResourceGroup -eq $Config.resourceGroupName){
            $ResourcesFound = $ResourcesFound+1
        }
        $ResourcesFound | Should Be 2
    }

    It "Should remove the source Cloud Service Resource Group created" {
        {Get-AzureRmResourceGroup -Name $Config.cloudServiceName -ErrorAction Stop} | Should Throw
    }

    It "Should remove the source Storage Account Resource group created" {
        $ResourceGroupName = "Default-Storage-$($Config.location.replace(' ',''))"
        Write-Host $ResourceGroupName
        {Get-AzureRmResourceGroup -Name $ResourceGroupName -ErrorAction Stop} | Should Throw
    }

}

Pop-Location