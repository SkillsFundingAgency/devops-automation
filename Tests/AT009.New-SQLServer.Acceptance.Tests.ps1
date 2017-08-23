$Config = Get-Content $PSScriptRoot\..\Tests\Acceptance.Config.json -Raw | ConvertFrom-Json
Push-Location -Path $PSScriptRoot\..\Infrastructure\Resources\

Describe "New-SQLServer Tests" -Tag "Acceptance-ARM" {

    # --- Define global properties for this test block
    $FirewallRuleConfigurationPath = "TestDrive:\sql.firewall.rules.json"
    $null = $Config.SQLServerFirewallRules | ConvertTo-Json | Set-Content -Path $FirewallRuleConfigurationPath

    $NewSQLServerParameters = @{
        Location = $Config.Location
        ResourceGroupName = $Config.ResourceGroupName
        KeyVaultName = $Config.SQLServerKeyVaultName
        KeyVaultSecretName = $Config.SQLServerName
        ServerName = $Config.SQLServerName
        ServerAdminUsername = $Config.SQLServerAdminUsername
        FirewallRuleConfiguration = $FirewallRuleConfigurationPath
        AuditingStorageAccountName = $Config.ClassicStorageAccountName
        ThreatDetectionNotificationRecipient = $Config.SQLServerNotificationRecipient
    }

    # --- Global Mocks
    $MockGetKeyVaultSecretParameters = @{
        CommandName = "Get-AzureKeyVaultSecret"
        MockWith = {                 
            return [PSCustomObject]@{
                SecretValueText = "ZQjSrcxJahlN?e-"
                SecretValue = "ZQjSrcxJahlN?e-" | ConvertTo-SecureString -AsPlainText -Force
            }
        }
    }
    Mock @MockGetKeyVaultSecretParameters

    $MockSetKeyVaultSecretParameters = @{
        CommandName = "Set-AzureKeyVaultSecret"
        MockWith = {return $null}

    }
    Mock @MockSetKeyVaultSecretParameters

    Context "Globally Resolvable Server Name" {
        It "Should fail if the SQL Servers name is globally resolvable" {

            $MockResolveAzureRmResourceParameters = @{
                CommandName = "Resolve-AzureRmResource"
                MockWith = {return $true}
            }
            Mock @MockResolveAzureRmResourceParameters

            $MockFindAzureRmResourceParameters = @{
                CommandName = "Find-AzureRmResource"
                MockWith = {return $null}
            }
            Mock @MockFindAzureRmResourceParameters

            {.\New-SQLServer.ps1 @NewSQLServerParameters} | Should Throw "The SQL Server name $($Config.SQLServerName) is globally resolvable. It's possible that this name has already been taken."
        }
    }

    Context "Existing SQL Server with missing Key Vault Secret" {
        It "Should fail if the SQL Server exists but does not have an associated key vault secret" {

            $MockGetKeyVaultSecretParameters = @{
                CommandName = "Get-AzureKeyVaultSecret"
                MockWith = {return $null}
            }
            Mock @MockGetKeyVaultSecretParameters

            $MockSetKeyVaultSecretParameters = @{
                CommandName = "Set-AzureKeyVaultSecret"
                MockWith = {return $null}

            }
            Mock @MockSetKeyVaultSecretParameters

            {.\New-SQLServer.ps1 @NewSQLServerParameters} | Should Throw "A secret entry for $($Config.SQLServerName) does not exist in the Key Vault"
        }
    }

    Context "New Unique SQL Server" {

        It "Should create a SQL Server and return two outputs" {
            $Result = .\New-SQLServer.ps1 @NewSQLServerParameters
            $Result.Count | Should Be 2
        }

        It "Should create a SQL Server in the correct location" {
            $Result = Get-AzureRmSqlServer -ResourceGroupName $Config.ResourceGroupName -ServerName $Config.SQLServerName
            $Result.Location | Should Be $Config.Location.Replace(" ","").ToLower()
        }

        It "Should create a SQL Server with the correct firewall rules" {

            foreach ($Rule in $Config.SQLServerFirewallRules) {
                {
                    $GetFirewallRuleParametres = @{
                        ResourceGroupName = $Config.ResourceGroupName
                        ServerName = $Config.SQLServerName
                        FirewallRuleName = $Rule.FirewallRuleName
                    }
                    Get-AzureRmSqlServerFirewallRule @GetFirewallRuleParametres  | Should Throw
                }
            }
        }

        It "Should remove a firewall rule that is no longer present in the config" {

            $FirewallConfig = $Config.sqlServerFirewallRules | Where-Object {$_.Name -ne $Config.SQLServerFirewallRuleToRemote}
            $FirewallConfig | ConvertTo-Json | Set-Content -Path $FirewallRuleConfigurationPath

            $null = .\New-SQLServer.ps1 @NewSQLServerParameters
            
            $GetFirewallRuleParametres = @{
                ResourceGroupName = $Config.ResourceGroupName
                ServerName = $Config.SQLServerName
                FirewallRuleName = $Config.SQLServerFirewallRuleToRemote
            }
            {Get-AzureRmSqlServerFirewallRule @GetFirewallRuleParametres -ErrorAction Stop} | Should Throw
        }

        It "Should create a SQL Server and enable auditing" {
            $AuditingPolicy = Get-AzureRmSqlServerAuditingPolicy -ResourceGroupName $Config.ResourceGroupName -ServerName $Config.SQLServerName
            $AuditingPolicy.AuditState | Should Be "Enabled"
        }

        It "Should create a SQL Server and enable threat detection" {
            $ThreatDetectionPolicy = Get-AzureRmSqlServerThreatDetectionPolicy -ResourceGroupName $Config.ResourceGroupName -ServerName $Config.SQLServerName
            $ThreatDetectionPolicy.ThreatDetectionState | Should be "Enabled"
        }
    }
}

Pop-Location