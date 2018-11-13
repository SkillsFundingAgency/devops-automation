
<#
.SYNOPSIS
Takes ARM template output and turns them into VSTS variables

.DESCRIPTION
Takes the ARM template output (usually from the Azure Deployment task in VSTS) and creates VSTS variables of the same name with the values so they can be used in subsequent tasks.

.PARAMETER ARMOutput
The JSON output from the ARM template to convert into variables.
If using the Azure Deployment task in an Azure Pipeline, you can set the output to a variable by specifying `Outputs > Deployment outputs`.

.PARAMETER rename
[Optional] Allows you to create a VSTS variable with a different name to the output name.
Takes a dictionary where the key is the name of the ARM template output and the value is the desired name of the VSTS variable.

.EXAMPLE
ConvertTo-VSTSVariables.ps1 -ARMOutput '$(ARMOutputs)'
where ARMOutputs is the name from Outputs > Deployment outputs from the Azure Deployment task

#>

param (
    [Parameter(Mandatory=$true)][string]$ARMOutput,
    [hashtable] $rename
)

# Output from ARM template is a JSON document
$jsonvars = $ARMOutput | convertfrom-json

# the outputs with be of type noteproperty, get a list of all of them
foreach ($outputname in ($jsonvars | Get-Member -MemberType NoteProperty).name) {
    # get the type and value for each output
    $outtypevalue = $jsonvars | Select-Object -ExpandProperty $outputname
    $outtype = $outtypevalue.type
    $outvalue = $outtypevalue.value

    # Check if variable name needs renaming
    if ($outputname -in $rename.keys) {
        $oldname = $outputname
        $outputname = $rename[$outputname]
        Write-Output "Creating VSTS variable $outputname from $oldname"
    }
    else {
        Write-Output "Creating VSTS variable $outputname"
    }

    # Set VSTS variable
    if ($outtype.toLower() -eq 'securestring') {
        Write-Output "##vso[task.setvariable variable=$outputname;issecret=true]$outvalue"
    }
    else {
        Write-Output "##vso[task.setvariable variable=$outputname]$outvalue"
    }
}

