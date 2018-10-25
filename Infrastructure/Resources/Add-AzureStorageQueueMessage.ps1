<#
.SYNOPSIS
Add the specified content to an Azure Storage Queue

.DESCRIPTION
Add the specified content to an Azure Storage Queue

.PARAMETER ResourceGroupName
Resource group of the storage account

.PARAMETER StorageAccountName
Storage account name

.PARAMETER StorageQueueName
Storage queue where the message should be added

.PARAMETER MessageContent
Any message content that should be added to the queue. Can be blank.

VSTS Variable with the Value '{"Release Definition":"$(Release.DefinitionName)","Release Name":"$(Release.ReleaseName)"}' produces a JSON formatted message
with information about the release definition and name that the script was run from.

.EXAMPLE

.\Add-AzureStorageQueueMessage.ps1 -ResourceGroupName resourcegroupname `
                                   -StorageAccountName storageaccountname `
                                   -StorageQueueName storagequeuename `
                                   -MessageContent "{"Release Definition":"$(Release.DefinitionName)","Release Name":"$(Release.ReleaseName)"}"

#>
[CmdletBinding()]
Param(
    [Parameter(Mandatory = $true)]
    [String]$ResourceGroupName,
    [Parameter(Mandatory = $true)]
    [String]$StorageAccountName,
    [Parameter(Mandatory = $true)]
    [String]$StorageQueueName,
    [Parameter(Mandatory = $false)]
    [String]$MessageContent
)
try {

    # Get the Storage account key
    $StorageAccountKey = (Get-AzureRmStorageAccountKey -ResourceGroupName $($ResourceGroupName) -Name $($StorageAccountName)).Value[0]

    # Set the Storage context
    $Context = New-AzureStorageContext -StorageAccountName $($StorageAccountName) -StorageAccountKey $StorageAccountKey

    # Check whether the queue exists
    $Queue = Get-AzureStorageQueue -Name $($StorageQueueName) -Context $Context

    if (!$Queue) {
        Write-Host "Specified storage queue $($StorageQueueName) doesn't exist in storage account $($StorageAccountName)"
    }
    else {
        if ($PSBoundParameters.ContainsKey('MessageContent')) {
            Write-Host "Supplied message content: $($MessageContent)"
        }
        else {
            Write-Host "Setting empty MessageContent"
            $MessageContent = ""
        }
        Write-Host "Adding message to queue"
        $Queue.CloudQueue.AddMessage($MessageContent)
    }
}
catch {
    throw "$_"
}
