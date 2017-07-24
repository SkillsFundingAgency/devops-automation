$Config = Get-Content $PSScriptRoot\..\Tests\Acceptance.Config.json -Raw | ConvertFrom-Json
Push-Location -Path $PSScriptRoot\..\Infrastructure\Resources\

# --- Certificate file must exist in the same folder as this test script
$CertPath = "$PSScriptRoot\$($Config.certificateName)"

Describe "Set-CloudServiceCertificate Tests" -Tag "Acceptance-ASM" {

    $CloudServiceName = "$($Config.cloudServiceName)$($Config.suffix)"

    # --- Set up test certificate
    $SecurePassword = $Config.certificatePassword | ConvertTo-SecureString -AsPlainText -Force
    $Cert = Import-PfxCertificate -FilePath $CertPath -Password $SecurePassword -CertStoreLocation Cert:\CurrentUser\My

    It "Should apply a Certificate to the Cloud Service and return no outputs" {        
        $Result = .\Set-CloudServiceCertificate.ps1 -ServiceName $CloudServiceName -CertificatePath $CertPath -CertificatePassword $Config.certificatePassword
        $Result.Count | Should Be 0
    }

    It "Should not throw on subsequent runs" {        
        {.\Set-CloudServiceCertificate.ps1 -ServiceName $CloudServiceName -CertificatePath $CertPath -CertificatePassword $Config.certificatePassword} | Should not throw        
    }

    It "Applied thumbprint should exist on the cloud service" {
        $AppliedCert = Get-AzureCertificate -ServiceName $CloudServiceName -ErrorAction SilentlyContinue        
        $AppliedCert.Thumbprint | Should Be $Cert.Thumbprint
    }
    
    # --- Remove test certificate from local store    
    Get-ChildItem Cert:\CurrentUser\My\$Cert.Thumbprint | Remove-Item -Confirm:$false
}

Pop-Location
