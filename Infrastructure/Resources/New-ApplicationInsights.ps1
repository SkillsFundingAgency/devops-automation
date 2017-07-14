<#

.SYNOPSIS
Create a Service Bus Namespace and optionally create associated queues

.DESCRIPTION
Create a Service Bus Namespace and optionally create associated queues

.PARAMETER Location
The location of the resource

.PARAMETER ResourceGroupName
The name of the destination Resource Group for the resource

.PARAMETER Name
The name of the Application Insights instance

.EXAMPLE

#>

Param (
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [String]$Location = $ENV:Location,
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [String]$ResourceGroupName = $ENV:ResourceGroupName,	
    [Parameter(Mandatory = $true)]
    [String]$Name
)

# --- Import Azure Helpers
Import-Module (Resolve-Path -Path $PSScriptRoot\..\Modules\Azure.psm1).Path

try {
	Write-Host "Checking for existing Application Insights: $Name"         
    $ApplicationInsights = Get-AzureRmResource -ResourceGroupName $ResourceGroupName -ResourceName $Name -ResourceType "Microsoft.Insights/components"
} 
catch {}

if (!$ApplicationInsights) {
    Write-Host "Creating Application Insights $Name"
	$ApplicationInsightsParameters = @{
		Location = $Location
		ResourceGroupName = $ResourceGroupName
		ResourceName = $Name
		ResourceType = "Microsoft.Insights/components"
		PropertyObject = @{"Application_Type" = "web"}
	}
    $ApplicationInsights = New-AzureRmResource @ApplicationInsightsParameters -Force
}

Write-Host "[Service Online: $Name]" -ForegroundColor Green
Write-Output ("##vso[task.setvariable variable=InstrumentationKey;]$($ApplicationInsights.Properties.InstrumentationKey)")


