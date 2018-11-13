<#
.SYNOPSIS
Remove resource group deployments that are older than the specified retention period

.DESCRIPTION
Remove resource group deployments that are older than the specified retention period+

.PARAMETER ResourceGroupNamePattern
The resource group name. This can be a fully qualified name or a wildcard

.EXAMPLE
Remove-ArmTemplateDeployment.ps1 -ResourceGroupNamePattern das-test-pfbe*

.EXAMPLE
Remove-ArmTemplateDeployment.ps1 -ResourceGroupNamePattern das-test-pfbe-rg -RetentionPeriod 10

#>

Param(
    [Parameter(Mandatory = $true)]
    [String]$ResourceGroupNamePattern,
    [Parameter(Mandatory = $false)]
    [Int]$RetentionPeriod = 5
)

try {
    # --- Start the removal of each deployment within the retention period
    $ResourceGroupList = Get-AzureRmResourceGroup -Name $ResourceGroupNamePattern
    foreach ($ResourceGroup in $ResourceGroupList) {
        $ResourceGroupName = $ResourceGroup.ResourceGroupName
        Write-Host "Processing resource group: $ResourceGroupName"
        $MaxRetentionDate = [DateTime]::UtcNow.AddDays( - $RetentionPeriod)
        $ResourceGroupDeploymentsToRemove = Get-AzureRmResourceGroupDeployment -ResourceGroupName $ResourceGroupName | Where-Object {$_.Timestamp -lt $MaxRetentionDate}
        Write-Host "    -> Removing $($ResourceGroupDeploymentsToRemove.Count) deployments older than $RetentionPeriod day(s).."

        foreach ($Deployment in $ResourceGroupDeploymentsToRemove) {
            $DeploymentName = $Deployment.DeploymentName
            $null = Start-Job -ScriptBlock {
                Remove-AzureRmResourceGroupDeployment -ResourceGroupName $Using:ResourceGroupName -Name $Using:DeploymentName
            }
        }
    }

    # --- Wait for job completion
    Write-Host "Waiting for jobs to complete.."
    while ($true) {
        $CompletedList = (Get-Job) | Where-Object {$_.State -eq "Running"}
        $FailedList = (Get-Job) | Where-Object {$_.State -eq "Failed"}

        if ($CompletedList.Count -eq 0) {
            Write-Host "Jobs finished, ending."
            break
        }
    }

    # --- Publish failed jobs
    $FailedList | Receive-Job

    # --- Remove jobs for this session
    Get-Job | Receive-Job

}
catch {
    throw "$_"
}
