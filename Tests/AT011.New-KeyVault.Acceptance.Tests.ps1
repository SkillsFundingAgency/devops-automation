$Config = Get-Content $PSScriptRoot\..\Tests\Acceptance.Config.json -Raw | ConvertFrom-Json
Push-Location -Path $PSScriptRoot\..\Infrastructure\Resources\

Describe "New-KeyVault Tests" -Tag "Acceptance-ARM" {

    $ResourceGroupName = "$($Config.ResourceGroupName)$($Config.suffix)"
    $KeyVaultName = "$($Config.keyVaultName)$($Config.suffix)"

    It "Should create an Azure Keyvault and return an output" {
        $KeyVaultParameters = @{
            Location                 = $config.location
            ResourceGroupName        = $ResourceGroupName
            Name                     = $KeyVaultName
            ServicePrincipalObjectId = $config.servicePrincipalObjectId
            SecretName               = $config.keyVaultSecretName
            SecretValue              = $config.keyVaultSecretValue
        }

        $Result = .\New-KeyVault.ps1 @KeyVaultParameters
        $Result.Count | Should Be 1
    }

    It "Should create a KeyVault with the correct access policy" {
        $Keyvault = Get-AzureRmKeyVault -VaultName $KeyVaultName -ResourceGroupName $ResourceGroupName
        ($KeyVault.AccessPolicies | Where-Object {$_.ObjectId -eq $config.servicePrincipalObjectId}).Count | Should be 1
    }
}

Pop-Location
