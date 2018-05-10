. .\SwapWithPreview.UTHelper.ps1 # appDetails function
Push-Location -Path $PSScriptRoot\..\Infrastructure\Resources\

Describe "Start-SwapWithPreview Tests" -Tag "Unit" {
    # mock Azure calls
    Mock Get-AzureRmWebAppSlot { return appDetails }
    Mock Switch-AzureRmWebAppSlot

    .\Start-SwapWithPreview.ps1 -AppName mock -ResourceGroupName mock

    It "Start-SwapWithPreview should call Switch-AzureRmWebAppSlot with ApplySlotConfig" {
        Assert-MockCalled Switch-AzureRmWebAppSlot -Exactly 1 -ParameterFilter { $SwapWithPreviewAction -eq 'ApplySlotConfig' }
    }
}

Pop-Location
