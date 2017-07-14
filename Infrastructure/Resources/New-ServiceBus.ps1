<#

.SYNOPSIS
Create a Service Bus Namespace and optionally create associated queues

.DESCRIPTION
Create a Service Bus Namespace and optionally create associated queues

.PARAMETER Location
The location of the resource

.PARAMETER ResourceGroupName
The name of the destination Resource Group for the resource

.PARAMETER NamespaceName
The name of the Service Bus Namespace

.PARAMETER Sku
The Sku of the Service Bus Namespace

.PARAMETER QueueName
One or more queues to create in the Service Bus Namespace

.EXAMPLE
.\New-ServiceBus.ps1 -Location "West Europe" -ResourceGroupName arm-rg-01 -ServiceBusNamespaceName svcbusns01

.EXAMPLE
.\New-ServiceBus.ps1 -Location "West Europe" -ResourceGroupName arm-rg-01 -ServiceBusNamespaceName svcbusns01 -QueueName q1,q2,q3

#>

Param (
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [String]$Location = $ENV:Location,
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
	[String]$ResourceGroupName = $ENV:ResourceGroupName,
    [Parameter(Mandatory = $true)]
    [String]$NamespaceName,
	[Parameter(Mandatory = $false)]
    [String]$Sku = "Standard",
    [Parameter(Mandatory = $true)]
    [String[]]$QueueName
)

# --- Import Azure Helpers
Import-Module (Resolve-Path -Path $PSScriptRoot\..\Modules\Azure.psm1).Path

# --- Check for existing namespace, if it doesn't exist create it
Write-Host "Checking for existing Service Bus Namespace: $NamespaceName"			 
$ServiceBus = Get-AzureRmServiceBusNamespace  -Name $NamespaceName -ResourceGroup $ResourceGroupName -ErrorAction SilentlyContinue

$GloballyResolvable = Resolve-AzureRMResource -PublicResourceFqdn "$($NamespaceName.ToLower()).servicebus.windows.net"

if (!$ServiceBus) {
	try {
		# --- If the Service Bus Namespace doesn't exist in the Resource Group but is globally resolvable, throw an error
		if ($GloballyResolvable){
			throw "The Service Bus Namespace $NamespaceName is globaly resolvable. It's possible that this name has already been taken."
		}		
		Write-Host "Creating Service Bus Namespace: $NamespaceName"
		$null = New-AzureRmServiceBusNamespace -name $NamespaceName -Location $Location -ResourceGroupName $ResourceGroupName -SkuName $Sku -ErrorAction Stop
	} catch {
		throw "Could not create Service Bus $($NamespaceName): $_"
	}
}

# --- If required, create queues
if ($PSBoundParameters.ContainsKey("QueueName") -and $ServiceBus) {
	foreach ($Queue in $QueueName) {
		$ExistingQueue = Get-AzureRmServiceBusQueue -ResourceGroup $ResourceGroupName -NamespaceName $NamespaceName -QueueName $Queue -ErrorAction SilentlyContinue
		if (!$ExistingQueue) {
			try{
				Write-Host "Creating Queue: $Queue"
            	$null = New-AzureRmServiceBusQueue -ResourceGroup $ResourceGroupName -NamespaceName $NamespaceName -QueueName $Queue -EnablePartitioning $true
			}catch{
				throw "Could not create Service Bus Queue $($Queue): $_"
			}
		}
	}
}

Write-Host "[Service Online: $NamespaceName]" -ForegroundColor Green

$Keys = Get-AzureRmServiceBusNamespaceKey -Name $NamespaceName -ResourceGroup $ResourceGroupName -AuthorizationRuleName RootManageSharedAccessKey
Write-Output ("##vso[task.setvariable variable=ServiceBusEndpoint;]$($Keys.PrimaryConnectionString)")