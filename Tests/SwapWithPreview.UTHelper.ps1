# Mock return of Get-AzureRmWebApp & Get-AzureRmWebAppSlot
# Set swapinprogress param to simulate a swap started
function appDetails ($swapinprogress = '') {
    return @"
{ "SiteConfig": {
    "AppSettings": {
      "MockSetting": "MockValue"
    }
  },
  "TargetSwapSlot": "$swapinprogress"
}
"@ | ConvertFrom-Json
}
