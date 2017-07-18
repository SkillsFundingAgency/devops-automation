<#

.SYNOPSIS
Add a certificate to one or more Cloud Services

.DESCRIPTION
Add a certificate to one or more Cloud Services

.PARAMETER ServiceName
The names of one or more Cloud Services

.PARAMETER CertificatePath
The path to the pfx file

.PARAMETER CertificatePassword
The password for the pfx

.EXAMPLE
$CertificatePasswrod = "P@ssw0rd1!" | ConvertTo-SecureString -AsPlainText -Force
.\Set-CloudServiceCertificate.ps1 -ServiceName cloud-service-01 -CertificatePath c:\certificates\cs01.pfx -CertificatePassword $CertificatePassword

.EXAMPLE
$CertificatePasswrod = "P@ssw0rd1!" | ConvertTo-SecureString -AsPlainText -Force
.\Set-CloudServiceCertificate.ps1 -ServiceName cloud-service-01, cloud-service-02 -CertificatePath c:\certificates\cs01.pfx -CertificatePassword $CertificatePassword

.EXAMPLE
When using this script in the Azure PowerShell VSTS:

* The password should be a secure variable
* Set the CertificatePassword parameter to ('$(SecurePassword)' | ConvertTo-SecureString -AsPlainText -Force) in Script Arguments

-CertificatePassword ('$(SecurePassword)' | ConvertTo-SecureString -AsPlainText -Force)

#>

Param(
    [Parameter(Mandatory = $true)]
    [String[]]$ServiceName,
    [Parameter(Mandatory = $true)]  
    [String]$CertificatePath,
    [Parameter(Mandatory = $true)]
    [String]$CertificatePassword
)

# --- Import Azure Helpers
Import-Module (Resolve-Path -Path $PSScriptRoot\..\Modules\Azure.psm1).Path

foreach ($Service in $ServiceName) {

    $CloudService = Get-AzureService -ServiceName $Service -ErrorAction SilentlyContinue
    Write-Host "Found Cloud Service: $($CloudService.Label)"

    If ($CloudService) {    
        
        $Certificate = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
        $Certificate.Import($CertificatePath, $CertificatePassword, 'DefaultKeySet')

        $OldCert = Get-AzureCertificate -ServiceName $Service -Thumbprint $Certificate.Thumbprint -ThumbprintAlgorithm sha1 -ErrorAction SilentlyContinue

        if ($OldCert) {
            Write-Host "Certificate already exists"
        }
        else {
            Write-Host "Installing certificate"
            $null = Add-AzureCertificate -ServiceName $Service -CertToDeploy $CertificatePath -Password $CertificatePassword
        }
    }
    else {
        Write-Host "Cloud Service $Service not found"
    }
}