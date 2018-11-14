Push-Location -Path $PSScriptRoot\..\Infrastructure\Resources\


Describe "ConvertTo-AzureDevOpsVariables unit tests" -Tag "Unit" {

    It "Should return a string correctly" {
        $armout = '{"foo":{"type":"String","value":"bar"}}'
        $expected = @('Creating VSTS variable foo',
            '##vso[task.setvariable variable=foo]bar')

        $output = .\ConvertTo-AzureDevOpsVariables -ARMOutput $armout
        $output | Should be $expected
    }

    It "Should return a securestring correctly" {
        $armout = '{"foo":{"type":"SecureString","value":"bar"}}'
        $expected = @('Creating VSTS variable foo',
            '##vso[task.setvariable variable=foo;issecret=true]bar')

        $output = .\ConvertTo-AzureDevOpsVariables -ARMOutput $armout
        $output | Should be $expected
    }
}
