. .\SwapWithPreview.UTHelper.ps1 # appDetails function
Push-Location -Path $PSScriptRoot\..\Infrastructure\Resources\

Describe "Cancel-SwapWithPreview when swap has not been started" -Tag "Unit" {
    # mock Azure calls
    Mock Get-AzureRmWebApp { return appDetails }
    Mock Switch-AzureRmWebAppSlot

    .\Cancel-SwapWithPreview.ps1 -AppName mock -ResourceGroupName mock

    It "Cancel-SwapWithPreview should NOT call Switch-AzureRmWebAppSlot" {
        Assert-MockCalled Switch-AzureRmWebAppSlot -Exactly 0
    }
}

Describe "Cancel-SwapWithPreview when swap in progress" -Tag "Unit" {
    # mock Azure calls
    Mock Get-AzureRmWebApp { return appDetails -swapinprogress staging }
    Mock Switch-AzureRmWebAppSlot

    .\Cancel-SwapWithPreview.ps1 -AppName mock -ResourceGroupName mock

    It "Cancel-SwapWithPreview should call Switch-AzureRmWebAppSlot with ResetSlotSwap" {
        Assert-MockCalled Switch-AzureRmWebAppSlot -Exactly 1 -ParameterFilter { $SwapWithPreviewAction -eq 'ResetSlotSwap' }
    }
}

Pop-Location
