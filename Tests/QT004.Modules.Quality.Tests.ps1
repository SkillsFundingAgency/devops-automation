Describe "Code quality tests" -Tag "Quality" {

    $Modules = Get-ChildItem -Path $PSScriptRoot\..\Infrastructure\Modules\*.psm1 -File -Recurse

    $Rules = Get-ScriptAnalyzerRule
    $ExcludeRules = @(
        "PSAvoidUsingWriteHost",
        "PSAvoidUsingEmptyCatchBlock",
        "PSAvoidUsingPlainTextForPassword"
    )
 
    foreach ($Module in $Modules) {
        Context $Module.Name {
            forEach ($Rule in $Rules) {
                It "Should pass Script Analyzer rule $Rule" {
                    $Result = Invoke-ScriptAnalyzer -Path $Module.FullName -IncludeRule $Rule -ExcludeRule $ExcludeRules
                    $Result.Count | Should Be 0
                }
            }
        }
    }
}