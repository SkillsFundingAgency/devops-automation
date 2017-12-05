<#

.SYNOPSIS
Create a Resource Group

.DESCRIPTION
Create a Resource Groups in a geographical location

.PARAMETER Location
The location of the Resource Group. This is limited to West Europe and North Europe

.PARAMETER Name
The name of the Resource Group

.PARAMETER TagConfigPath
Path to the Tag configuration JSON file .contents example

{
    "Tags": [
        {
            "Name": "CP",
            "Value": {
                "BSA": "DAS",
                "SA": "DAS",
                "ENV": "PD",
                "WL": "TBD",
                "DC": "TBD",
                "BC": "DAS"
            }
        },
        {
            "Name": "DO",
            "Value": {
                "BSA": "TBD",
                "SA": "TBD",
                "ENV": "PJO",
                "WL": "MRO",
                "DC": "KEO",
                "BC": "DAS"
            }
        }
    ]
}

.EXAMPLE

.\New-ResourceGroup.ps1 -Name arm-rg-01 -Location "West Europe" 

.EXAMPLE

.\New-ResourceGroup.ps1 -Name arm-rg-01 -Location "West Europe" -TagConfigPath "c:\temp\TagConfig.json"

#>

Param (
    [Parameter(Mandatory = $True)]
    [ValidateSet("West Europe", "North Europe")]
    [String]$Location,
    [Parameter(Mandatory = $True)]
    [ValidateNotNullOrEmpty()]
    [String]$Name,
    [Parameter(Mandatory = $False)]
    [ValidateNotNullOrEmpty()]
    [String]$TagConfigPath
)
# --- Import Azure Helpers
Import-Module (Resolve-Path -Path $PSScriptRoot\..\Modules\Azure.psm1).Path
Import-Module (Resolve-Path -Path $PSScriptRoot\..\Modules\Helpers.psm1).Path
Write-Log -LogLevel Information -Message "Checking for existing Resource Group $Name"
$ExistingResourceGroup = Get-AzureRmResourceGroup -Name $Name -ErrorAction SilentlyContinue
# --- Create Resource Group if it doesn't exist
if (!$ExistingResourceGroup) {
    try {
        Write-Log -LogLevel Information -Message "Creating Resource Group"
        $null = New-AzureRmResourceGroup -Location $Location -Name $Name
    }
    catch {
        throw "Could not create Resource Group $Name : $_"
    }
}
$ExistingResourceGroup = Get-AzureRmResourceGroup -Name $Name -ErrorAction SilentlyContinue
# --- \\Tags Section\\
# --- If resource already exists check the Tags are present and hold the same values as the Config File 
If ($TagConfigPath) {
    $TagConfig = Get-Content -Path $TagConfigPath -Raw | ConvertFrom-Json
}
If ($ExistingResourceGroup -and $TagConfigPath) {
    try {
        $Tags = $ExistingResourceGroup.Tags
        Write-Log -LogLevel Information "Resource Exists - Checking for Valid Tags"
        # --- If statement needed to account for $null values
        If ($Tags) {
            # --- enumerate all tags in json
            foreach ($ConfigTag in $TagConfig.Tags) {
                if ($ConfigTag) {
                    $ConfigTagValue = $ConfigTag.Value | ConvertTo-Json
                    $ConfigTagName = $ConfigTag.Name
                    # --- enumerate all tags in retrived RG object        
                    foreach ($Tag in $Tags.GetEnumerator()) {
                        # --- See if the tag name and value match the Config values
                        If ($($Tag.Name) -eq $ConfigTagName -and $($Tag.Value) -ne $ConfigTagValue) {    
                            $TagPresentValueInCorrect = $True    
                        }
                        If ($($Tag.Name) -eq $ConfigTagName -and $($Tag.Value) -eq $ConfigTagValue) {    
                            $TagValueUpdated = $True    
                        }
                    }
                    # --- Overwrite value if Tag already present
                    If ($TagPresentValueInCorrect) {
                        $Tags[$TagConfig.Name] = $ConfigTagValue 
                        $null = Set-AzureRmResourceGroup -Tag $Tags -Name $Name
                        Write-Log -LogLevel Information "Existing Tag Value amended Name:$ConfigTagName Values:$ConfigTagValue "
                        $TagValueUpdated = $True
                    }
                    # --- Create Tag & Value if it doesn't exist
                    If (!$TagValueUpdated) {
                        $Tags += @{$ConfigTagName = $ConfigTagValue}
                        $null = Set-AzureRmResourceGroup -Tag $Tags -Name $Name
                        Write-Log -LogLevel Information "Tag & Value Created  Name:$ConfigTagName Values:$ConfigTagValue "
                    }
                    $TagPresentValueInCorrect = $null
                    $TagValueUpdated = $null
                }
            }
        }
    }  
    catch {
        throw "Could not amend Tags . The Error is : $_"
    }      
}
Write-Output ("##vso[task.setvariable variable=ResourceGroup;]$Name")
Write-Output ("##vso[task.setvariable variable=Location;]$Location")