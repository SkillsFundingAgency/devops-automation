
$Config = Get-Content $PSScriptRoot\..\Tests\Acceptance.Config.json -Raw | ConvertFrom-Json
Push-Location -Path $PSScriptRoot\..\Infrastructure\Resources\

Describe "Set-CloudServiceCertificate Tests" -Tag "Acceptance-ASM" {

    It "Should apply a Certificate to the Cloud Service and return no outputs" {        
        $Result = .\Set-CloudServiceCertificate.ps1 -ServiceName $config.cloudServiceName -CertificatePath $config.certificatePath -CertificatePassword $config.certificatePassword
        $Result.Count | Should Be 0
    }

    It "Applied thumbprint should exist on the cloud service" {
        $securePassword =  $config.certificatePassword | ConvertTo-SecureString -AsPlainText -Force
        $cert = Import-PfxCertificate -FilePath $config.certificatePath -Password  $securePassword -CertStoreLocation Cert:\CurrentUser\My
        $testCertThumbprint = $cert.Thumbprint
        $appliedCert = Get-AzureCertificate -ServiceName $config.cloudServiceName -ErrorAction SilentlyContinue        
        Write-Host $appliedCert.Thumbprint
        $appliedCert.Thumbprint | Should Be $testCertThumbprint
        Get-ChildItem Cert:\CurrentUser\My\$testCertThumbprint | Remove-Item
    }
}

Pop-Location