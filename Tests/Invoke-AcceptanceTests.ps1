<#

.SYNOPSIS
Test wrapper to invoke ASM or ARM acceptance tests

.DESCRIPTION
Test wrapper to invoke ASM or ARM acceptance tests

.PARAMETER Type
The type of test that will be executed. The parameter value can be either ARM or ASM

.EXAMPLE
Invoke-AcceptanceTests.ps1 -Type ASM

.EXAMPLE
Invoke-AcceptanceTests.ps1 -Type ARM

#>
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $true)]
    [ValidateSet("ARM", "ASM")]
    [String]$Type
)

$TestParameters = @{
    Tag          = "Acceptance-$Type"
    OutputFormat = 'NUnitXml'
    OutputFile   = "$PSScriptRoot\TEST-Acceptance-$Type.xml"
    Script       = "$PSScriptRoot"
    PassThru     = $True
}

# --- Supress logging
$null = New-Item -Name SUPRESSLOGGING -value $true -ItemType Variable -Path Env: -Force

# --- Invoke tests
$Result = Invoke-Pester @TestParameters

if ($Result.FailedCount -ne 0) { 
    Write-Error "Pester returned $($result.FailedCount) errors"
}