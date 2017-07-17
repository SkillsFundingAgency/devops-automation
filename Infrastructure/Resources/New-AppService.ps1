<#

.SYNOPSIS
Create an App Service Plan and App Service

.DESCRIPTION
Create an App Service Plan and App Service and set configuration properties. The script will also check the availability 
of the chosen name for the App Service.

.PARAMETER Location
The location of the Resource

.PARAMETER ResourceGroupName
The name of the destination Resource Group for the resource

.PARAMETER AppServicePlanName
The name of the App Service Plan

.PARAMETER AppServicePlanTier
The pricing tier of the App Service plan. Supported values are: Basic, Free, Premium, Shared, Standard

The parameter has a default value of Basic

.PARAMETER AppServiceName
The name of the App Service

.PARAMETER AppServiceProperties
Optionally override the properties that are being set on the App Service

.EXAMPLE
.\New-AppService.ps1 -Location "West Europe" -ResourceGroupName arm-rg-01 -AppServicePlanName appsvcplan01 -AppServiceName webapp01

.EXAMPLE
.\New-AppService.ps1 -Location "West Europe" -ResourceGroupName arm-rg-01 -AppServicePlanName appsvcplan01 -AppServicePlanTier Standard -AppServiceName webapp01

.EXAMPLE
$AppServiceProperties = @{
	alwaysOn = $false
}

.\New-AppService.ps1 -Location "West Europe" -ResourceGroupName arm-rg-01 -AppServicePlanName appsvcplan01 -AppServicePlanTier Standard -AppServiceName webapp01 -AppServiceProperties $AppServiceProperties

#>

Param (
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [String]$Location = $ENV:Location,
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
	[String]$ResourceGroupName = $ENV:ResourceGroup,
	[Parameter(Mandatory = $false)]	
    [String]$AppServicePlanName,
	[Parameter(Mandatory = $false)]
	[ValidateSet("Basic", "Free", "Premium", "Shared", "Standard")]
    [String]$AppServicePlanTier = "Basic",
    [Parameter(Mandatory = $true)]
    [String]$AppServiceName,
	[Parameter(Mandatory = $false)]
    [Hashtable]$AppServiceProperties
)

# --- Import Azure Helpers
Import-Module (Resolve-Path -Path $PSScriptRoot\..\Modules\Azure.psm1).Path

# --- Check for an existing App Service Plan, create on if it doesn't exist
Write-Host "Checking for existing App Service Plan: $AppServicePlanName"
$ExistingAppServicePlan = Get-AzureRmAppServicePlan -ResourceGroupName $ResourceGroupName -Name $AppServicePlanName -ErrorAction SilentlyContinue

If (!$ExistingAppServicePlan) {
	try {
		Write-Host "Creating $AppServicePlanName in $ResourceGroupName"
		$null = New-AzureRmAppServicePlan -Location $Location -Tier $AppServicePlanTier -Name $AppServicePlanName -ResourceGroupName $ResourceGroupName
	} catch {
		throw "Could not create app service plan $AppServicePlanName : $_"
	}
}

# --- Check for an existing App Service, create on if it doesn't exist
Write-Host "Checking for existing App Service: $AppServiceName"
$AppService = Get-AzureRmWebApp -ResourceGroupName $ResourceGroupName -Name $AppServiceName -ErrorAction SilentlyContinue

# --- Check whether the dns name is globally resolvable, if it is then it probably exists in another tenant/subscription
$GloballyResolvable = Resolve-AzureRMResource -PublicResourceFqdn "$($AppServiceName.ToLower()).azurewebsites.net"

If (!$AppService) {
	# --- If the App Service doesn't exist in the Resource Group but is globally resolvable, throw an error
	if ($GloballyResolvable){
		throw "The App Service name $AppServiceName is globaly resolvable. It's possible that this name has already been taken."
	}

	try {
		Write-Host "Creating App Service $AppServiceName in App Service Plan $AppServiceName"
		$AppService = New-AzureRmWebApp -ResourceGroupName $ResourceGroupName -Name $AppServiceName -Location $Location -AppServicePlan $AppServicePlanName
	} catch {
		throw "Could not create App Service $AppService : $_"
	}
}

# --- Set alwaysOn to true if the app service is not in the free tier
if  ($AppService -and $AppServicePlanTier -ne "Free") {
	try {

		if (!$PSBoundParameters.ContainsKey("AppServiceProperties")) {
			$AppServiceProperties = @{alwaysOn = $true }
		}

		Write-Host "Setting properties on App Service $($AppServiceName):`n$($AppServiceProperties | ConvertTo-Json)"
		$SetAzureResourceParameters = @{
			ResourceGroup = $ResourceGroupName
			PropertyObject = $AppServiceProperties
			ResourceType = "Microsoft.Web/sites/config"
			ResourceName = "$AppServiceName/web"
			APIVersion = "2015-08-01"
		}
		$null = Set-AzureRmResource @SetAzureResourceParameters -Force -ErrorAction Stop
		Write-Host "Restarting App Service $AppServiceName"
		$null = Restart-AzureRmWebApp -ResourceGroupName $ResourceGroupName -Name $AppServiceName
	} catch {
		throw "Could not set properties on $($AppServiceName): $($_.Exception.Message)"
	}
}

Write-Host "[Service Online: $AppServiceName]" -ForegroundColor Green
