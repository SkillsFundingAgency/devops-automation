<#

.SYNOPSIS
Create an Application Insights instance

.DESCRIPTION
Create an Application Insights instance

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

    Write-Verbose -Message "Checking for existing Application Insights: $Service"
    if ((((Get-Module AzureRM -ListAvailable | Sort-Object { $_.Version.Major } -Descending).Version.Major))[0] -gt 5) {
        $ApplicationInsights = Get-AzureRmResource -Name $Service -ResourceType "Microsoft.Insights/components"
    }
    else {
        $ApplicationInsights = Find-AzureRmResource -ResourceNameEquals $Service -ResourceType "Microsoft.Insights/components"
    }

    if (!$ApplicationInsights) {
        Write-Log -LogLevel Information -Message "Creating Application Insights $Service"
        if ((((Get-Module AzureRM -ListAvailable | Sort-Object { $_.Version.Major } -Descending).Version.Major))[0] -gt 5) {
            $ApplicationInsightsParameters = @{
                Location          = $Location
                ResourceGroupName = $ResourceGroupName
                Name              = $Service
                Kind              = "web"
            }
            $ApplicationInsights = New-AzureRmApplicationInsights @ApplicationInsightsParameters
        }
        else {
            $ApplicationInsightsParameters = @{
                Location          = $Location
                ResourceGroupName = $ResourceGroupName
                ResourceName      = $Service
                ResourceType      = "Microsoft.Insights/components"
                PropertyObject    = @{"Application_Type" = "web"}
            }
            $ApplicationInsights = New-AzureRmResource @ApplicationInsightsParameters -Force
        }
    }
    else {
        if ((((Get-Module AzureRM -ListAvailable | Sort-Object { $_.Version.Major } -Descending).Version.Major))[0] -gt 5) {
            $ApplicationInsights = Get-AzureRmApplicationInsights -ResourceGroupName $ResourceGroupName -Name $Service
        }
        else {
            $ApplicationInsights = Get-AzureRmResource -ResourceId $ApplicationInsights.ResourceId
        }
    }
    if ((((Get-Module AzureRM -ListAvailable | Sort-Object { $_.Version.Major } -Descending).Version.Major))[0] -gt 5) {
        Write-Output ("##vso[task.setvariable variable=InstrumentationKey-$($Service);]$($ApplicationInsights.InstrumentationKey)")
        Write-Output ("##vso[task.setvariable variable=AppId-$($Service);]$($ApplicationInsights.AppId)")
    }
    else {
        Write-Output ("##vso[task.setvariable variable=InstrumentationKey-$($Service);]$($ApplicationInsights.Properties.InstrumentationKey)")
        Write-Output ("##vso[task.setvariable variable=AppId-$($Service);]$($ApplicationInsights.Properties.AppId)")
    }
}
