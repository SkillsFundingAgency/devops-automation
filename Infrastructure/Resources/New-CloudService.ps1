<#

.SYNOPSIS
Create a Cloud Service

.DESCRIPTION
Create a Cloud Service and wait for it to come online

.PARAMETER Location
The location of the Resource Group. This is limited to West Europe and North Europe

.PARAMETER Name
The names of one or more Cloud Services to create

.EXAMPLE
.\New-CloudService.ps1 -Name cloud-service-01,cloud-service-02

#>

Param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("West Europe", "North Europe")]
    [String]$Location = $ENV:Location,
    [Parameter(Mandatory = $true)]
    [String[]]$Name
)

# --- Import Azure Helpers
Import-Module (Resolve-Path -Path $PSScriptRoot\..\Modules\Azure.psm1).Path
Import-Module (Resolve-Path -Path $PSScriptRoot\..\Modules\Helpers.psm1).Path

# --- Create Cloud Service
foreach ($Service in $Name) {

    Write-Log -LogLevel Information -Message "Checking for Cloud Service $Service"
    # --- Check if storage account exists in our subscription
    $CloudService = Get-AzureService -ServiceName $Service -ErrorAction SilentlyContinue

    # --- Check if the resource name has been taken elsewhere
    $CloudServiceAccountNameTest = Test-AzureName -Service $Service	

    # --- If the Cloud Service doesn't exist, create it
    if (!$CloudService -and !$CloudServiceAccountNameTest) {
        try {
            Write-Log -LogLevel Information -Message "Creating Cloud Service $Service"
            $CloudService = New-AzureService -ServiceName $Service -Location $Location
        }
        catch {
            throw "Could not create Cloud Service $Service : $_"
        }
    }
}