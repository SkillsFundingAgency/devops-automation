Describe "Code quality tests" -Tag "Quality" {

    $Scripts = Get-ChildItem -Path $PSScriptRoot\..\Infrastructure\Resources\*.ps1 -File -Recurse

    $Rules = Get-ScriptAnalyzerRule
    $ExcludeRules = @(
        "PSAvoidUsingWriteHost",
        "PSAvoidUsingEmptyCatchBlock",
        "PSAvoidUsingPlainTextForPassword"
        "PSPossibleIncorrectComparisonWithNull"
    )
 
    foreach ($Script in $Scripts) {
        Context $Script.BaseName {
            forEach ($Rule in $Rules) {
                It "Should pass Script Analyzer rule $Rule" {
                    $Result = Invoke-ScriptAnalyzer -Path $Script.FullName -IncludeRule $Rule -ExcludeRule $ExcludeRules
                    $Result.Count | Should Be 0
                }
            }
        }
    }
}