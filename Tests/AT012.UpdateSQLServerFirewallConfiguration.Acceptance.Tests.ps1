Push-Location -Path $PSScriptRoot\..\Tools\

Describe "Remove-SqlDatabaseFirewallRules" {

    It "Should delete firewall rules and return nothing if the SQL syntax is correct" {

        # Mock getting $DatabaseFirewallRules
        Mock Invoke-SqlCmd
            {return @(
                @{
                    id=1
                    name="Test01_Home"
                    start_ip_address = "10.100.10.101"
                    end_ip_address = "10.100.10.101"
                    create_date = "21/02/2018 01:01:01"
                    modify_date = "21/02/2018 01:01:01"
                },
                @{
                    id=1
                    name="Test02_Home"
                    start_ip_address = "10.100.10.102"
                    end_ip_address = "10.100.10.102"
                    create_date = "22/02/2018 02:02:02"
                    modify_date = "22/02/2018 02:02:02"
                }
            )}
            -ParameterFilter {
                $Query -eq "SELECT * FROM sys.database_firewall_rules" -and
                $ServerInstance -ne $null -and
                $Database -ne $null -and
                $Username -ne $null
                $Password -ne $null -and
                $Password.GetType().FullName -ne "System.String"
            }

        # Mock removing a database firewall rule
        Mock Invoke-SqlCmd {return $null}
        -ParameterFilter {
            $Query -like "EXECUTE sp_delete_database_firewall_rule N'*" -and
            $ServerInstance -ne $null -and
            $Database -ne $null -and
            $Username -ne $null
            $Password -ne $null -and
            $Password.GetType().FullName -eq "System.String"
        }

        # If Invoke-SqlCmd is called with parameters other than those defined above throw an error
        Mock Invoke-SqlCmd {throw "Error, Invoke-SqlCmd params invalid"}

        # Import resources
        Import-Module (Resolve-Path -Path $PSScriptRoot\..\Infrastructure\Modules\Helpers.psm1).Path
        Install-Module SqlServer -Scope CurrentUser
        Import-Module SqlServer
        . Update-SQLServerFirewallConfiguration.ps1

        # Set variables
        $ResourceGroupName = "das-at-shared-rg"
        $ServerNamePattern = "das-at-shared-sql"
        $SqlServer = Find-AzureRmResource -ResourceNameContains $ServerNamePattern -ResourceType "Microsoft.Sql/Servers" -ExpandProperties

        $SqlAdministratorPassword = New-Object Microsoft.Azure.Commands.KeyVault.Models.PSKeyVaultSecret
        $SqlAdministratorPassword.SecretValue = ("abc123efg456hij789" | ConvertTo-SecureString -AsPlainText -Force)

        $param = @{
            ResourceGroupName = $ResourceGroupName
            SqlServer = $SqlServer
            SqlAdministratorPassword = $SqlAdministratorPassword
        }

        $result = Remove-SqlDatabaseFirewallRules @param -Verbose
        $result | Should -Be $null
    }


}
