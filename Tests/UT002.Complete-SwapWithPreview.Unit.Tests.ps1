. .\SwapWithPreview.UTHelper.ps1 # appDetails function
Push-Location -Path $PSScriptRoot\..\Infrastructure\Resources\

Describe "Complete-SwapWithPreview when swap has not been started" -Tag "Unit" {
    # mock Azure calls
    Mock Get-AzureRmWebApp { return appDetails }
    Mock Get-AzureRmWebAppSlot { return appDetails }
    Mock Switch-AzureRmWebAppSlot

    .\Complete-SwapWithPreview.ps1 -AppName mock -ResourceGroupName mock

    It "Complete-SwapWithPreview should NOT call Switch-AzureRmWebAppSlot" {
        Assert-MockCalled Switch-AzureRmWebAppSlot -Exactly 0
    }
}

Describe "Complete-SwapWithPreview when swap in progress" -Tag "Unit" {
    # mock Azure calls
    Mock Get-AzureRmWebApp { return appDetails -swapinprogress staging }
    Mock Get-AzureRmWebAppSlot { return appDetails }
    Mock Switch-AzureRmWebAppSlot

    .\Complete-SwapWithPreview.ps1 -AppName mock -ResourceGroupName mock

    It "Complete-SwapWithPreview should call Switch-AzureRmWebAppSlot with CompleteSlotSwap" {
        Assert-MockCalled Switch-AzureRmWebAppSlot -Exactly 1 -ParameterFilter { $SwapWithPreviewAction -eq 'CompleteSlotSwap' }
    }
}

Pop-Location
