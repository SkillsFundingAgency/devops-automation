Describe "Module help tests" -Tag "Quality" {

    $Modules = Get-ChildItem -Path $PSScriptRoot\..\Infrastructure\Modules\*.psm1 -File -Recurse

    foreach ($Module in $Modules) {

        $null = Import-Module -Name $Module.FullName
        $Functions = Get-Command -Module $Module.BaseName -CommandType Function

        Context $Module.Name {

            foreach ($Function in $Functions) {

                $Help = Get-Help $Function.Name

                It "$($Function.Name) should have a synopsis" {
                    $Help.Synopsis | Should Not BeNullOrEmpty
                }

                It "$($Function.Name) should have a description" {
                    $Help.Description | Should Not BeNullOrEmpty
                }

                It "$($Function.Name) should have an example" {
                    $Help.Examples | Should Not BeNullOrEmpty
                }
                
                foreach ($Parameter in $Help.Parameters.Parameter) {
                    if ($Parameter -notmatch 'whatif|confirm') {
                        It "$($Function.Name) should have a Parameter description for $($Parameter.Name)" {
                            $Parameter.Description.Text | Should Not BeNullOrEmpty
                        }
                    }
                }
            }
        }
    }
}