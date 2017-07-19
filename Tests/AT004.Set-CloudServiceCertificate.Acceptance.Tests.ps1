
$Config = Get-Content $PSScriptRoot\..\Tests\Acceptance.Config.json -Raw | ConvertFrom-Json
Push-Location -Path $PSScriptRoot\..\Infrastructure\Resources\

Describe "Set-CloudServiceCertificate Tests" -Tag "Acceptance-ASM" {
    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
    $cert.Import($config.certificatePath, $config.certificatePassword, [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]"DefaultKeySet")    
    $testCertThumbprint = $cert.Thumbprint

    It "Should apply a Certificate to the Cloud Service and return no outputs" {        
        $Result = .\Set-CloudServiceCertificate.ps1 -ServiceName $config.cloudServiceName -CertificatePath $config.certificatePath -CertificatePassword $config.certificatePassword
        $Result.Count | Should Be 0
    }

    It "Applied thumbprint should exist on the cloud service" {
        $appliedCert = Get-AzureCertificate -ServiceName $config.cloudServiceName -ErrorAction SilentlyContinue        
        Write-Host $appliedCert.Thumbprint
        $appliedCert.Thumbprint | Should Be $testCertThumbprint
    }
}

Pop-Location