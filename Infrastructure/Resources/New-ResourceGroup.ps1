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
Path to the configuration JSON file

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
    [Parameter(Mandatory = $True)]
    [ValidateNotNullOrEmpty()]
    [String]$TagConfigPath        
)

# --- Enumerate Tag Value's from Config File
$TagConfig = Get-Content $TagConfigPath -Raw | ConvertFrom-Json
$ConfigTagValue = $TagConfig.Value | ConvertTo-Json
$ConfigTagName = $TagConfig.Name 

# --- Import Azure Helpers
Import-Module (Resolve-Path -Path $PSScriptRoot\..\Modules\Azure.psm1).Path
Import-Module (Resolve-Path -Path $PSScriptRoot\..\Modules\Helpers.psm1).Path

Write-Log -LogLevel Information -Message "Checking for existing Resource Group $Name"			 
$ExistingResourceGroup = Get-AzureRmResourceGroup -Name $Name -ErrorAction SilentlyContinue


# --- Create Resource Group if it doesnt exist
if (!$ExistingResourceGroup) {
    try {
        Write-Log -LogLevel Information -Message "Creating Resource Group"
        $null = New-AzureRmResourceGroup -Location $Location -Name $Name -Tag @{$TagConfig.Name = $ConfigTagValue}
    }
    catch {
        throw "Could not create Resource Group $Name : $_"
    }
}


# --- Define & Set variables for Tags
$TagPresentValueCorrect = $True 
$TagValueUpdated = $False
$Tags = $ExistingResourceGroup.Tags

# --- If resource already exists check the Core Platform Tags are present and hold the same values as the Config File       
if ($ExistingResourceGroup) {
    try {
        Write-Log -LogLevel Information "Resource Exists - Checking for Valid Core Platform Tag"
    
        # --- Enumerate all tags
        foreach ($Tag in $Tags.GetEnumerator()) {
            # --- See if the tag name and value match the Config values
            If ($($Tag.Name) -eq $TagConfig.Name -and $($Tag.Value) -ne $ConfigTagValue) {    
                $TagPresentValueCorrect = $False    
            }   
            If ($($Tag.Name) -eq $TagConfig.Name -and $($Tag.Value) -eq $ConfigTagValue) {    
                $TagValueUpdated = $True    
            }         
        }

        # --- Once all tags enumerated 

        # --- Set a value if tag already present
        If (!$TagPresentValueCorrect) {
            $Tags[$TagConfig.Name] = $ConfigTagValue 
            Set-AzureRmResourceGroup -Tag $Tags -Name $Name
            Write-Log -LogLevel Information "Existing Tag Value ammended Name:$ConfigTagName Values:$ConfigTagValue "
            $TagValueUpdated = $True
        }

        # --- Create Tag & Value if it doesn't exist
        If (!$TagValueUpdated) {
            $Tags += @{$TagConfig.Name = $ConfigTagValue}
            Set-AzureRmResourceGroup -Tag $Tags -Name $Name
            Write-Log -LogLevel Information "Tag & Value Created  Name:$ConfigTagName Values:$ConfigTagValue "
        }

    }  
    catch {throw "Could not ammend Core Platform Tag . The Error is : $_" }
}
 



Write-Output ("##vso[task.setvariable variable=ResourceGroup;]$Name")
Write-Output ("##vso[task.setvariable variable=Location;]$Location")