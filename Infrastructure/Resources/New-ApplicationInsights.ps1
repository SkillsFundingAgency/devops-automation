<#

.SYNOPSIS
Create a Service Bus Namespace and optionally create associated queues

.DESCRIPTION
Create a Service Bus Namespace and optionally create associated queues

.PARAMETER Location
The location of the Resource Group. This is limited to West Europe and North Europe

.PARAMETER ResourceGroupName
The name of the destination Resource Group for the resource

.PARAMETER Name
The name of the Application Insights instance

.EXAMPLE

#>

Param (
    [Parameter(Mandatory = $false)]
    [ValidateSet("West Europe", "North Europe")]
    [String]$Location = $ENV:Location,
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [String]$ResourceGroupName = $ENV:ResourceGroup,	
    [Parameter(Mandatory = $true)]
    [String[]]$Name
)

# --- Import Azure Helpers
Import-Module (Resolve-Path -Path $PSScriptRoot\..\Modules\Azure.psm1).Path
Import-Module (Resolve-Path -Path $PSScriptRoot\..\Modules\Helpers.psm1).Path

foreach ($Service in $Name) {
    try {
        Write-Log -LogLevel Information -Message "Checking for existing Application Insights: $Service"         
        $ApplicationInsights = Get-AzureRmResource -ResourceGroupName $ResourceGroupName -ResourceName $Service -ResourceType "Microsoft.Insights/components"
    } 
    catch {}

    if (!$ApplicationInsights) {
        Write-Log -LogLevel Information -Message "Creating Application Insights $Service"
        $ApplicationInsightsParameters = @{
            Location          = $Location
            ResourceGroupName = $ResourceGroupName
            ResourceName      = $Service
            ResourceType      = "Microsoft.Insights/components"
            PropertyObject    = @{"Application_Type" = "web"}
        }
        $ApplicationInsights = New-AzureRmResource @ApplicationInsightsParameters -Force
    }

    Write-Output ("##vso[task.setvariable variable=InstrumentationKey-$($Service);]$($ApplicationInsights.Properties.InstrumentationKey)")
}