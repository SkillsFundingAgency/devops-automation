$variables = (Get-Content -Raw TestConfig.json | ConvertFrom-Json).Variables

foreach($variable in $variables){
    Write-Host "Setting $($variable.Name) to $($variable.Value)" -ForegroundColor DarkGreen
    Write-Host "##vso[task.setvariable variable=CONFIG_$($variable.Name)]$($variable.Value)"
}