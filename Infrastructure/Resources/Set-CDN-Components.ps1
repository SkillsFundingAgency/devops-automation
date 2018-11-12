<#

.SYNOPSIS
CDN

.DESCRIPTION
CDM

.PARAMETER Environment
The deployment environment


.EXAMPLE


#>

Param(
    [Parameter(Mandatory = $true)]
    [String]$Source,
    [Parameter(Mandatory = $true)]
    [String]$Destination,
    [Parameter(Mandatory = $true)]
    [String]$SaSToken
)


Import-Module (Resolve-Path -Path $PSScriptRoot\..\Modules\BlobCopy.psm1).Path
Import-Module (Resolve-Path -Path $PSScriptRoot\..\Modules\Helpers.psm1).Path





$DeploymentParameters = @{
    Source    = $Source
    Destination   = $Destination
    SaSToken     = $SaSToken

}

. "$PSScriptRoot\..\Modules\BlobCopy.psm1" @DeploymentParameters





