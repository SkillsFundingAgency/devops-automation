<#

.SYNOPSIS
Create a Cloud Service

.DESCRIPTION
Create a Cloud Service and wait for it to come online

.PARAMETER Location
The location of the resource

.PARAMETER Name
The names of one or more Cloud Services to create

.EXAMPLE
.\New-CloudService.ps1 -Name cloud-service-01,cloud-service-02

#>

Param(
	[Parameter(Mandatory = $false)]
	[ValidateNotNullOrEmpty()]
    [String]$Location = $ENV:Location,	
    [Parameter(Mandatory = $true)]
    [String[]]$Name
)

# --- Import Azure Helpers
Import-Module (Resolve-Path -Path $PSScriptRoot\..\Modules\Azure.psm1).Path

# --- Create Cloud Service
foreach ($Service in $Name) {

	Write-Host "Checking for Cloud Service $Service"			 
	$ExistingCloudService = Get-AzureService -ServiceName $Service -ErrorAction SilentlyContinue

	# --- If the Cloud Service doesn't exist, create it
	if(!$ExistingCloudService){		
		try {
			Write-Host "Creating Cloud Service $Service"
			$null = New-AzureService -ServiceName $Service -Location $Location
			Wait-AzureRmResource -ResourceGroupName $Service -ResourceName $Service
		} catch {
			throw "Could not create Cloud Service $Service : $_"
		}
	}

	Write-Host "[Service Online: $Service]" -ForegroundColor Green
}