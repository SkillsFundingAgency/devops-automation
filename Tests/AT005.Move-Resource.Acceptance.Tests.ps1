$Config = Get-Content $PSScriptRoot\..\Tests\Acceptance.Config.json -Raw | ConvertFrom-Json
Push-Location -Path $PSScriptRoot\..\Infrastructure\Resources\

Describe "Move-Resource Tests" -Tag "Acceptance-ARM" {

    $DestinationResourceGroup = "$($Config.resourceGroupName)$($Config.suffix)"
    $CloudServiceName = "$($Config.cloudServiceName)$($Config.suffix)"
    $StorageAccountName = "$($Config.classicStorageAccountName)$($Config.suffix)"

    It "Should move given resources to a named Resource Group" {
        $Resources = @(
            "$($Config.classicStorageAccountName)$($Config.suffix)",
            "$($Config.cloudServiceName)$($Config.suffix)"
        )

        $null = .\Move-Resource.ps1 -ResourceName $Resources -DestinationResourceGroup $DestinationResourceGroup

        $ResourcesFound = 0
        $CloudServiceResourceGroup = (Find-AzureRmResource -ResourceNameEquals $CloudServiceName).ResourceGroupName
        if ($CloudServiceResourceGroup -eq $DestinationResourceGroup) {
            $ResourcesFound = $ResourcesFound + 1
        }

        $StorageAccountResourceGroup = (Find-AzureRmResource -ResourceNameEquals $StorageAccountName).ResourceGroupName
        if ($StorageAccountResourceGroup -eq $DestinationResourceGroup) {
            $ResourcesFound = $ResourcesFound + 1
        }
        $ResourcesFound | Should Be 2
    }

    It "Should remove the source Cloud Service Resource Group created" {
        {Get-AzureRmResourceGroup -Name $CloudServiceName -ErrorAction Stop} | Should Throw
    }

    It "Should remove the source Storage Account Resource group created" {
        $ResourceGroupName = "Default-Storage-$($Config.location.replace(' ',''))"
        Write-Host $ResourceGroupName
        {Get-AzureRmResourceGroup -Name $ResourceGroupName -ErrorAction Stop} | Should Throw
    }

}

Pop-Location