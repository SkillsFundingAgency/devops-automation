<#

.SYNOPSIS
Facilitate running of scripts against a Cosmos DB in Azure using the Mongo API through the Mongo Client Shell

.DESCRIPTION
Requires Mongo Client to be installed and added to the System PATH

.PARAMETER CosmosDb
Use HOST:Port from the Azure Portal e.g.

.PARAMETER Username
Use Username from the Azure Portal

.PARAMETER Password
Use the Primary or Secondary Password from the Azure Portal

.PARAMETER MongoScript
Script (.js) with the commands to execute against the database

.EXAMPLE
Use .\Invoke-CosmosDbScript.ps1 -CosmosDb "mycosmosdb.documents.azure.com:10255" -Username "mycosmosdb" -Password "PASSWORD" -MongoScript "PathToScript\Script.js"

#>

Param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [String]$CosmosDb,
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
	[String]$Username,
    [Parameter(Mandatory = $true)]
    [SecureString]$Password,
	[Parameter(Mandatory = $false)]
    [String]$MongoScript
)

try{
    $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "Username", $Password
    $ReadablePassword = $Credential.GetNetworkCredential().Password
    . "mongo" --host $CosmosDb --username $Username --password $ReadablePassword --ssl $MongoScript
}
catch {
    throw $_
}
