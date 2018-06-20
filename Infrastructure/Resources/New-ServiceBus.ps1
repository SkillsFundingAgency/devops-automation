<#

.SYNOPSIS
Create a Service Bus Namespace and optionally create associated queues

.DESCRIPTION
Create a Service Bus Namespace and optionally create associated queues

.PARAMETER Location
The location of the Resource Group. This is limited to West Europe and North Europe

.PARAMETER ResourceGroupName
The name of the destination Resource Group for the resource

.PARAMETER NamespaceName
The name of the Service Bus Namespace

.PARAMETER Sku
The Sku of the Service Bus Namespace

.PARAMETER QueueName
One or more queues to create in the Service Bus Namespace

.Parameter TopicDefinition
A file containing an array of topics and their subscribers. This file is managed by the developers of the solution.

For Example:

[
    {
        "topicName": "test_topic",
        "subscription": [
            "test_sub1",
            "test_sub2",
            "test_sub3"
       ]
    }
]

.EXAMPLE
.\New-ServiceBus.ps1 -Location "West Europe" -ResourceGroupName arm-rg-01 -ServiceBusNamespaceName svcbusns01

.EXAMPLE
.\New-ServiceBus.ps1 -Location "West Europe" -ResourceGroupName arm-rg-01 -NamespaceName svcbusns01 -QueueName q1,q2,q3

.EXAMPLE
.\New-ServiceBus.ps1 -Location "West Europe" -ResourceGroupName arm-rg-01 -NamespaceName svcbusns01 -TopicDefinition C:\AzureTopicDefinitionStructure.Json
#>

[CmdletBinding(DefaultParameterSetName="Standard")]
Param (
    [Parameter(Mandatory = $false, ParameterSetName = "Standard")]
    [Parameter(Mandatory = $false, ParameterSetName = "Queue")]
    [Parameter(Mandatory = $false, ParameterSetName = "Topic")]
    [ValidateSet("West Europe", "North Europe")]
    [String]$Location = $ENV:Location,
    [Parameter(Mandatory = $false, ParameterSetName = "Standard")]
    [Parameter(Mandatory = $false, ParameterSetName = "Queue")]
    [Parameter(Mandatory = $false, ParameterSetName = "Topic")]
    [ValidateNotNullOrEmpty()]
    [String]$ResourceGroupName = $ENV:ResourceGroup,
    [Parameter(Mandatory = $true, ParameterSetName = "Standard")]
    [Parameter(Mandatory = $true, ParameterSetName = "Queue")]
    [Parameter(Mandatory = $true, ParameterSetName = "Topic")]
    [String]$NamespaceName,
    [Parameter(Mandatory = $false, ParameterSetName = "Standard")]
    [Parameter(Mandatory = $false, ParameterSetName = "Queue")]
    [Parameter(Mandatory = $false, ParameterSetName = "Topic")]
    [String]$Sku = "Standard",
    [Parameter(Mandatory = $true, ParameterSetName = "Queue")]
    [String[]]$QueueName,
    [Parameter(Mandatory = $true, ParameterSetName = "Topic")]
    [String]$TopicDefinition
)

# --- Import Azure Helpers
Import-Module (Resolve-Path -Path $PSScriptRoot\..\Modules\Azure.psm1).Path
Import-Module (Resolve-Path -Path $PSScriptRoot\..\Modules\Helpers.psm1).Path

# --- Check for existing namespace, if it doesn't exist create it
Write-Log -LogLevel Information -Message "Checking for existing Service Bus Namespace: $NamespaceName"
$ServiceBus = Get-AzureRmServiceBusNamespace  -Name $NamespaceName -ResourceGroup $ResourceGroupName -ErrorAction SilentlyContinue

$GloballyResolvable = Resolve-AzureRMResource -PublicResourceFqdn "$($NamespaceName.ToLower()).servicebus.windows.net"

if (!$ServiceBus) {
    try {
        # --- If the Service Bus Namespace doesn't exist in the Resource Group but is globally resolvable, throw an error
        if ($GloballyResolvable) {
            throw "The Service Bus Namespace $NamespaceName is globally resolvable. It's possible that this name has already been taken."
        }
        Write-Log -LogLevel Information -Message "Creating Service Bus Namespace: $NamespaceName"
        $ServiceBus = New-AzureRmServiceBusNamespace -name $NamespaceName -Location $Location -ResourceGroupName $ResourceGroupName -SkuName $Sku -ErrorAction Stop
    }
    catch {
        throw "Could not create Service Bus $($NamespaceName): $_"
    }
}

# --- If required, create queues OR topics
if ($PSCmdlet.ParameterSetName -eq "Queue" -and $ServiceBus) {
    foreach ($Queue in $QueueName) {
        $ExistingQueue = Get-AzureRmServiceBusQueue -ResourceGroup $ResourceGroupName -NamespaceName $NamespaceName -QueueName $Queue -ErrorAction SilentlyContinue
        if (!$ExistingQueue) {
            try {
                Write-Log -LogLevel Information -Message "Creating Queue: $Queue"
                $null = New-AzureRmServiceBusQueue -ResourceGroup $ResourceGroupName -NamespaceName $NamespaceName -QueueName $Queue -EnablePartitioning $true
            }
            catch {
                throw "Could not create Service Bus Queue $($Queue): $_"
            }
        }
    }
}
elseif ($PSCmdlet.ParameterSetName -eq "Topic" -and $ServiceBus) {

    $Definition = Get-Content -Path (Resolve-Path -Path $TopicDefinition).Path -Raw | ConvertFrom-Json
    foreach ($Topic in $Definition) {

        # --- If the topic doesn't exist in the namespace, create it
        Write-Log -LogLevel Information -Message "Checking for Topic: $($Topic.TopicName)"
        $ExistingTopic = Get-AzureRmServiceBusTopic -ResourceGroup $ResourceGroupName -NamespaceName $NamespaceName -TopicName $Topic.TopicName -ErrorAction SilentlyContinue
        if (!$ExistingTopic) {
            try {
                Write-Log -LogLevel Information -Message "Creating Topic: $($Topic.TopicName)"
                $null = New-AzureRmServiceBusTopic -ResourceGroup $ResourceGroupName -NamespaceName $NamespaceName -TopicName $Topic.TopicName -EnablePartitioning $False -ErrorAction SilentlyContinue
            }
            catch {
                throw "Could not create Service Bus Topic $($Topic.TopicName): $_"
            }
        }

        # --- If the subscription doesn't exist in the topic, create it
        foreach ($Subscription in $Topic.Subscription) {
            Write-Log -LogLevel Information -Message "Checking for Subscription $Subscription on Topic $($Topic.TopicName)"
            $ExistingSubscription = Get-AzureRmServiceBusSubscription -ResourceGroup $ResourceGroupName -NamespaceName $NamespaceName -TopicName $Topic.TopicName -SubscriptionName $Subscription -ErrorAction SilentlyContinue
            if (!$ExistingSubscription) {
                try {
                    Write-Log -LogLevel Information -Message "Creating Subscription: $($Subscription)"
                    $null = New-AzureRmServiceBusSubscription -ResourceGroup $ResourceGroupName -NamespaceName $NamespaceName -SubscriptionName $Subscription -TopicName $Topic.TopicName
                }
                catch {
                    throw "Cloud not create Subscription: $($Subscription)"
                }
            }
        }
    }
}

# ---- Create read write access policy
$RWAuthorizationRuleName = "ReadWrite"
if ((((Get-Module AzureRM -ListAvailable | Sort-Object { $_.Version.Major } -Descending).Version.Major))[0] -gt 5) {
    $RWAccessPolicy = Get-AzureRmServiceBusAuthorizationRule -ResourceGroupName $ResourceGroupName -Namespace $NamespaceName -AuthorizationRuleName $RWAuthorizationRuleName -ErrorAction SilentlyContinue
}
else {
    $RWAccessPolicy = Get-AzureRmServiceBusNamespaceAuthorizationRule -ResourceGroup $ResourceGroupName -NamespaceName $NamespaceName -AuthorizationRuleName $RWAuthorizationRuleName -ErrorAction SilentlyContinue
}
if (!$RWAccessPolicy) {
    try {
        Write-Log -LogLevel Information -Message "Creating Authorization Rule: $RWAuthorizationRuleName"

        if ((((Get-Module AzureRM -ListAvailable | Sort-Object { $_.Version.Major } -Descending).Version.Major))[0] -gt 5) {
            $RWAccessPolicyParameters = @{
                ResourceGroupName = $ResourceGroupName
                Namespace         = $NamespaceName
                Name              = $RWAuthorizationRuleName
                Rights            = "Send", "Listen"
            }
            $null = New-AzureRmServiceBusAuthorizationRule @RWAccessPolicyParameters
        }
        else {
            $RWAccessPolicyParameters = @{
                ResourceGroup         = $ResourceGroupName
                NamespaceName         = $NamespaceName
                AuthorizationRuleName = $RWAuthorizationRuleName
                Rights                = "Send", "Listen"
            }
            $null = New-AzureRmServiceBusNamespaceAuthorizationRule @RWAccessPolicyParameters
        }
    }
    catch {
        throw "Could not create Authorization Rule $($RWAuthorizationRuleName): $_"
    }
}

# ---- Create read only access policy
$RAuthorizationRuleName = "Read"
if ((((Get-Module AzureRM -ListAvailable | Sort-Object { $_.Version.Major } -Descending).Version.Major))[0] -gt 5) {
    $RAccessPolicy = Get-AzureRmServiceBusAuthorizationRule -ResourceGroupName $ResourceGroupName -Namespace $NamespaceName -AuthorizationRuleName $RAuthorizationRuleName -ErrorAction SilentlyContinue
}
else {
    $RAccessPolicy = Get-AzureRmServiceBusNamespaceAuthorizationRule -ResourceGroup $ResourceGroupName -NamespaceName $NamespaceName -AuthorizationRuleName $RAuthorizationRuleName -ErrorAction SilentlyContinue
}
if (!$RAccessPolicy) {
    try {
        Write-Log -LogLevel Information -Message "Creating Authorization Rule: $RAuthorizationRuleName"

        if ((((Get-Module AzureRM -ListAvailable | Sort-Object { $_.Version.Major } -Descending).Version.Major))[0] -gt 5) {
            $RAccessPolicyParameters = @{
                ResourceGroupName = $ResourceGroupName
                Namespace         = $NamespaceName
                Name              = $RAuthorizationRuleName
                Rights            = "Listen"
            }
            $null = New-AzureRmServiceBusAuthorizationRule @RAccessPolicyParameters
        }
        else {
            $RAccessPolicyParameters = @{
                ResourceGroup         = $ResourceGroupName
                NamespaceName         = $NamespaceName
                AuthorizationRuleName = $RAuthorizationRuleName
                Rights                = "Listen"
            }
            $null = New-AzureRmServiceBusNamespaceAuthorizationRule @RAccessPolicyParameters
        }
    }
    catch {
        throw "Could not create Authorization Rule $($RAuthorizationRuleName): $_"
    }
}
if ((((Get-Module AzureRM -ListAvailable | Sort-Object { $_.Version.Major } -Descending).Version.Major))[0] -gt 5) {
    $RWKeys = Get-AzureRmServiceBusKey -Namespace $NamespaceName -ResourceGroupName $ResourceGroupName -Name $RWAuthorizationRuleName
}
else {
    $RWKeys = Get-AzureRmServiceBusNamespaceKey -Name $NamespaceName -ResourceGroup $ResourceGroupName -AuthorizationRuleName $RWAuthorizationRuleName
}
Write-Output ("##vso[task.setvariable variable=ServiceBusEndpoint;]$($RWKeys.PrimaryConnectionString)")

if ((((Get-Module AzureRM -ListAvailable | Sort-Object { $_.Version.Major } -Descending).Version.Major))[0] -gt 5) {
    $RKeys = Get-AzureRmServiceBusKey -Namespace $NamespaceName -ResourceGroupName $ResourceGroupName -Name $RAuthorizationRuleName
}
else {
    $RKeys = Get-AzureRmServiceBusNamespaceKey -Name $NamespaceName -ResourceGroup $ResourceGroupName -AuthorizationRuleName $RAuthorizationRuleName
}
Write-Output ("##vso[task.setvariable variable=ServiceBusEndpointReadOnly;]$($RKeys.PrimaryConnectionString)")
