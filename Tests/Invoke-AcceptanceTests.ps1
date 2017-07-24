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
    OutputFile   = "TEST-Acceptance.xml"
    Script       = "$PSScriptRoot"
}

Invoke-Pester @TestParameters