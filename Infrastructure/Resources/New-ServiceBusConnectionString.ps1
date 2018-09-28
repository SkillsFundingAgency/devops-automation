<#

.SYNOPSIS
Get a connection string for a servicebus namespace

.DESCRIPTION
Get a connection string for a servicebus namespace. If one does not exist with the given name, it will be created

.PARAMETER ResourceGroupName
The name of the destination Resource Group for the resource

.PARAMETER NamespaceName
The name of the Service Bus Namespace

.PARAMETER AuthorizationRuleName
The name of the authorization rule to be created

.PARAMETER Rights
A list of rights. This can be one or all of the following:
Listen
Send
Manage

.PARAMETER ConnectionStringType
The connection string to return. This can be either Primary or Secondary.

.EXAMPLE
.\New-ServiceBusConnectionString.ps1 -NamespaceName test-namespace -AuthorizationRuleName auth1 -Rights Listen, Send, Manage -ConnectionStringType Secondary

#>

[CmdletBinding()]
Param (
    [Parameter(Mandatory = $true)]
    [String]$NamespaceName,
    [Parameter(Mandatory = $true)]
    [String]$AuthorizationRuleName,
    [Parameter(Mandatory = $true)]
    [ValidateSet("Listen", "Send", "Manage")]
    [String[]]$Rights,
    [Parameter(Mandatory = $false)]
    [ValidateSet("Primary", "Secondary")]
    [String[]]$ConnectionStringType = "Primary"
)

try {
    # --- Import Azure Helpers
    Import-Module (Resolve-Path -Path $PSScriptRoot\..\Modules\Helpers.psm1).Path

    Write-Log -LogLevel Information -Message "Checking for existing Service Bus Namespace: $NamespaceName"
    $ServiceBusResource = Get-AzureRMResource -Name $NamespaceName
    if (!$ServiceBusResource) {
        throw "Could not find servicebus namespace $NamespaceName"
    }

    $AuthorizationRule = Get-AzureRmServiceBusAuthorizationRule -ResourceGroupName $ServiceBusResource.ResourceGroupName -Namespace $NameSpaceName -Name $AuthorizationRuleName -ErrorAction SilentlyContinue
    if (!$AuthorizationRule) {
        Write-Log -LogLevel Information -Message "Creating authorization rule with name $AuthorizationRuleName"
        $AuthorizationRuleParameters = @{
            ResourceGroupName = $ServiceBusResource.ResourceGroupName
            Namespace         = $NamespaceName
            Name              = $AuthorizationRuleName
            Rights            = $Rights
        }
        $null = New-AzureRmServiceBusAuthorizationRule @AuthorizationRuleParameters
    }

    Write-Log -LogLevel Information -Message "Retrieving $ConnectionStringType connection string"
    $ServiceBusKey = Get-AzureRmServiceBusKey -ResourceGroupName $ServiceBusResource.ResourceGroupName -Namespace $NamespaceName -Name $AuthorizationRuleName

    switch ($ConnectionStringType) {
        'Primary' {
            $ConnectionString = $ServiceBusKey.PrimaryConnectionString
            break
        }
        'Secondary' {
            $ConnectionString = $ServiceBusKey.SecondaryConnectionString
            break
        }
    }

    Write-Log -LogLevel Information -Message "Publishing VSTS variable: ServiceBusConnectionString"
    Write-Output ("##vso[task.setvariable variable=ServiceBusConnectionString; issecret=true]$($ConnectionString)")

}
catch {
    throw $_
}
