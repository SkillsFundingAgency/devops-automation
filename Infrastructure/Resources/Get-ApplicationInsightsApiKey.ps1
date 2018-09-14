<#

.SYNOPSIS
Gets an App Insight API key for annotations

.DESCRIPTION
Gets an App Insight API key for annotations

.PARAMETER AppInsightName
The name of the App Insight resource

.PARAMETER ResourceGroupName
The name of the Resource Group of the App Insight resource

.PARAMETER KeyName
Optional name for the API key (defaults to VSTSAnnotateKey)

.EXAMPLE

#>

param (
    [Parameter(Mandatory=$true)]
    [String[]]$AppInsightName,
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [String]$ResourceGroupName = $ENV:ResourceGroup,
    [Parameter(Mandatory = $false)]
    [String]$KeyName = "VSTSAnnotateKey"
)

# --- Import Helpers
Import-Module (Resolve-Path -Path $PSScriptRoot\..\Modules\Helpers.psm1).Path

foreach ($Service in $AppInsightName) {

    Get-AzureRmApplicationInsightsApiKey -ResourceGroupName $ResourceGroupName -Name $Service |
        Where-Object { $_.Description -eq $KeyName } | ForEach-Object {
            Write-Log -LogLevel Information -Message "Deleting $($_.Description) [$($_.Id)]"
            Remove-AzureRmApplicationInsightsApiKey -ResourceGroupName $ResourceGroupName -Name $Service -ApiKeyId $_.Id
    }

    $apikey = New-AzureRmApplicationInsightsApiKey -ResourceGroupName $ResourceGroupName -Name $Service -Permissions WriteAnnotations -Description $KeyName
    Write-Output "##vso[task.setvariable variable=appInsightApiKey-$($Service);]$($apikey.ApiKey)"

}
