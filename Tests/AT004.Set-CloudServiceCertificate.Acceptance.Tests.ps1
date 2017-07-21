$Config = Get-Content $PSScriptRoot\..\Tests\Acceptance.Config.json -Raw | ConvertFrom-Json
Push-Location -Path $PSScriptRoot\..\Infrastructure\Resources\

Describe "Set-CloudServiceCertificate Tests" -Tag "Acceptance-ASM" {
    # --- Set up test certificate
    $SecurePassword = $Config.certificatePassword | ConvertTo-SecureString -AsPlainText -Force
    $Cert = Import-PfxCertificate -FilePath $Config.certificatePath -Password $SecurePassword -CertStoreLocation Cert:\CurrentUser\My

    It "Should apply a Certificate to the Cloud Service and return no outputs" {        
        $Result = .\Set-CloudServiceCertificate.ps1 -ServiceName $($Config.cloudServiceName+$Config.suffix) -CertificatePath $Config.certificatePath -CertificatePassword $Config.certificatePassword
        $Result.Count | Should Be 0
    }

    It "Applied thumbprint should exist on the cloud service" {
        $AppliedCert = Get-AzureCertificate -ServiceName $($Config.cloudServiceName+$Config.suffix) -ErrorAction SilentlyContinue        
        $AppliedCert.Thumbprint | Should Be $Cert.Thumbprint
    }
    
    Get-ChildItem Cert:\CurrentUser\My\$Cert.Thumbprint | Remove-Item -Confirm:$false
}

# --- Remove test certificate from local store


Pop-Location