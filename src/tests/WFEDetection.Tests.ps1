#Requires -Version 5.1
#Requires -Modules Pester

<#
.SYNOPSIS
    Pester tests for WFEDetection.ps1 module
.DESCRIPTION
    Comprehensive tests for WFE detection functionality including:
    - Test-WFEInstallation function
    - Find-WFEInstances function  
    - Get-TenantsConfigInfo function
    - Edge cases and error handling
    - Real-world scenarios based on actual deployments
.NOTES
    Author: Zoe Lai
    Date: 15/08/2025
    Version: 1.0
#>

# Import the module to test
$modulePath = Join-Path $PSScriptRoot "..\modules\Detection\WFEDetection.ps1"
. $modulePath

Describe "WFEDetection Module" {
    BeforeAll {
        # Create test data based on actual findings
        $testTenantsConfig = @"
<?xml version="1.0" encoding="utf-8"?>
<tenants>
    <tenant id="ba81e050-ec65-11df-98cf-0800200c9a66">
        <workflowDatabaseConnection>Data Source=SERVER2019\SQL2019;Initial Catalog=PG_NZ;Integrated Security=True</workflowDatabaseConnection>
        <workflowDatabaseName>PG_NZ</workflowDatabaseName>
        <workflowDatabaseServer>SERVER2019\SQL2019</workflowDatabaseServer>
        <workflowEnginePath>/WFE_PGNZ</workflowEnginePath>
        <workflowEnginePhysicalPath>C:\inetpub\wwwroot\WorkflowEngine</workflowEnginePhysicalPath>
    </tenant>
</tenants>
"@

        # Mock IIS site data based on actual findings
        $mockIISSite = [PSCustomObject]@{
            Name = "Default Web Site"
            PhysicalPath = "C:\inetpub\wwwroot"
            ApplicationPool = "DefaultAppPool"
            State = "Started"
        }

        # Mock WFE application data
        $mockWFEApp = [PSCustomObject]@{
            Path = "/WFE_PGNZ"
            PhysicalPath = "C:\inetpub\wwwroot\WorkflowEngine"
            ApplicationPool = "DefaultAppPool"
        }
    }

    Context "Test-WFEInstallation Function" {
        BeforeEach {
            # Reset mocks for each test
            Mock Get-IISSite { return @($mockIISSite) }
            # Only mock Get-IISApplication if the command exists
            if (Get-Command "Get-IISApplication" -ErrorAction SilentlyContinue) {
                Mock Get-IISApplication { return @($mockWFEApp) }
            } else {
                Mock Get-IISApplication { return @() }
            }
            Mock Test-Path { return $true }
            Mock Get-Content { return $testTenantsConfig }
        }

        It "Should detect WFE installation when properly configured" {
            $result = Test-WFEInstallation

            $result.Installed | Should -Be $true
            $result.InstallPath | Should -Be "C:\inetpub\wwwroot\WorkflowEngine"
            $result.SiteName | Should -Be "Default Web Site"
            $result.ApplicationPath | Should -Be "/WFE_PGNZ"
            $result.DatabaseServer | Should -Be "SERVER2019\SQL2019"
            $result.DatabaseName | Should -Be "PG_NZ"
            $result.TenantId | Should -Be "ba81e050-ec65-11df-98cf-0800200c9a66"
        }

        It "Should return false when IIS is not available" {
            Mock Get-IISSite { throw "IIS not available" }

            $result = Test-WFEInstallation

            $result.Installed | Should -Be $false
            $result.Error | Should -Not -BeNullOrEmpty
        }

        It "Should return false when no WFE applications found" {
            Mock Get-IISApplication { return @() }

            $result = Test-WFEInstallation

            $result.Installed | Should -Be $false
            $result.Error | Should -Contain "No WFE applications found"
        }

        It "Should handle missing tenants.config file" {
            Mock Test-Path { return $false }

            $result = Test-WFEInstallation

            $result.Installed | Should -Be $false
            $result.Error | Should -Contain "tenants.config not found"
        }

        It "Should handle malformed tenants.config XML" {
            Mock Get-Content { return "Invalid XML content" }

            $result = Test-WFEInstallation

            $result.Installed | Should -Be $false
            $result.Error | Should -Contain "Error parsing tenants.config"
        }

        It "Should handle multiple WFE applications" {
            $mockMultipleApps = @(
                [PSCustomObject]@{
                    Path = "/WFE_PGNZ"
                    PhysicalPath = "C:\inetpub\wwwroot\WorkflowEngine"
                    ApplicationPool = "DefaultAppPool"
                },
                [PSCustomObject]@{
                    Path = "/WFE_DEV"
                    PhysicalPath = "C:\inetpub\wwwroot\WorkflowEngine_Dev"
                    ApplicationPool = "DevAppPool"
                }
            )
            Mock Get-IISApplication { return $mockMultipleApps }

            $result = Test-WFEInstallation

            $result.Installed | Should -Be $true
            $result.ApplicationPath | Should -Be "/WFE_PGNZ"  # Should return first found
        }
    }

    Context "Find-WFEInstances Function" {
        BeforeEach {
            Mock Get-IISSite { return @($mockIISSite) }
            # Only mock Get-IISApplication if the command exists
            if (Get-Command "Get-IISApplication" -ErrorAction SilentlyContinue) {
                Mock Get-IISApplication { return @($mockWFEApp) }
            } else {
                Mock Get-IISApplication { return @() }
            }
            Mock Test-Path { return $true }
            Mock Get-Content { return $testTenantsConfig }
        }

        It "Should find WFE instances when properly configured" {
            $instances = Find-WFEInstances

            $instances.Count | Should -Be 1
            $instances[0].SiteName | Should -Be "Default Web Site"
            $instances[0].ApplicationPath | Should -Be "/WFE_PGNZ"
            $instances[0].PhysicalPath | Should -Be "C:\inetpub\wwwroot\WorkflowEngine"
            $instances[0].DatabaseServer | Should -Be "SERVER2019\SQL2019"
            $instances[0].DatabaseName | Should -Be "PG_NZ"
            $instances[0].TenantID | Should -Be "ba81e050-ec65-11df-98cf-0800200c9a66"
        }

        It "Should return empty array when no WFE instances found" {
            Mock Get-IISApplication { return @() }

            $instances = Find-WFEInstances

            $instances.Count | Should -Be 0
        }

        It "Should handle IIS access errors gracefully" {
            Mock Get-IISSite { throw "Access denied" }

            $instances = Find-WFEInstances

            $instances.Count | Should -Be 0
        }

        It "Should handle multiple WFE instances" {
            $mockMultipleApps = @(
                [PSCustomObject]@{
                    Path = "/WFE_PGNZ"
                    PhysicalPath = "C:\inetpub\wwwroot\WorkflowEngine"
                    ApplicationPool = "DefaultAppPool"
                },
                [PSCustomObject]@{
                    Path = "/WFE_DEV"
                    PhysicalPath = "C:\inetpub\wwwroot\WorkflowEngine_Dev"
                    ApplicationPool = "DevAppPool"
                }
            )
            Mock Get-IISApplication { return $mockMultipleApps }

            $instances = Find-WFEInstances

            $instances.Count | Should -Be 2
            $instances[0].ApplicationPath | Should -Be "/WFE_PGNZ"
            $instances[1].ApplicationPath | Should -Be "/WFE_DEV"
        }
    }

    Context "Get-TenantsConfigInfo Function" {
        BeforeEach {
            Mock Test-Path { return $true }
        }

        It "Should parse valid tenants.config XML" {
            Mock Get-Content { return $testTenantsConfig }
            
            # Create a temporary config file for testing
            $tempConfigPath = Join-Path $TestDrive "tenants.config"
            $testTenantsConfig | Out-File -FilePath $tempConfigPath -Encoding UTF8

            $result = Get-TenantsConfigInfo -ConfigPath $tempConfigPath

            $result.Count | Should -Be 1
            $result[0].TenantId | Should -Be "ba81e050-ec65-11df-98cf-0800200c9a66"
            $result[0].DatabaseServer | Should -Be "SERVER2019\SQL2019"
            $result[0].DatabaseName | Should -Be "PG_NZ"
            $result[0].WorkflowEnginePath | Should -Be "/WFE_PGNZ"
            $result[0].WorkflowEnginePhysicalPath | Should -Be "C:\inetpub\wwwroot\WorkflowEngine"
        }

        It "Should handle missing tenants.config file" {
            Mock Test-Path { return $false }

            $result = Get-TenantsConfigInfo -ConfigPath "C:\nonexistent\tenants.config"

            $result.Count | Should -Be 0
        }

        It "Should handle malformed XML gracefully" {
            Mock Get-Content { return "Invalid XML content" }
            
            # Create a temporary config file with invalid XML
            $tempConfigPath = Join-Path $TestDrive "invalid-tenants.config"
            "Invalid XML content" | Out-File -FilePath $tempConfigPath -Encoding UTF8

            $result = Get-TenantsConfigInfo -ConfigPath $tempConfigPath

            $result.Count | Should -Be 0
        }

        It "Should handle multiple tenants" {
            $multiTenantConfig = @"
<?xml version="1.0" encoding="utf-8"?>
<tenants>
    <tenant id="tenant1">
        <workflowDatabaseConnection>Data Source=server1;Initial Catalog=db1;Integrated Security=True</workflowDatabaseConnection>
        <workflowDatabaseName>db1</workflowDatabaseName>
        <workflowDatabaseServer>server1</workflowDatabaseServer>
        <workflowEnginePath>/WFE1</workflowEnginePath>
        <workflowEnginePhysicalPath>C:\path1</workflowEnginePhysicalPath>
    </tenant>
    <tenant id="tenant2">
        <workflowDatabaseConnection>Data Source=server2;Initial Catalog=db2;Integrated Security=True</workflowDatabaseConnection>
        <workflowDatabaseName>db2</workflowDatabaseName>
        <workflowDatabaseServer>server2</workflowDatabaseServer>
        <workflowEnginePath>/WFE2</workflowEnginePath>
        <workflowEnginePhysicalPath>C:\path2</workflowEnginePhysicalPath>
    </tenant>
</tenants>
"@
            Mock Get-Content { return $multiTenantConfig }
            
            # Create a temporary config file for testing
            $tempConfigPath = Join-Path $TestDrive "multi-tenant.config"
            $multiTenantConfig | Out-File -FilePath $tempConfigPath -Encoding UTF8

            $result = Get-TenantsConfigInfo -ConfigPath $tempConfigPath

            $result.Count | Should -Be 2
            $result[0].TenantId | Should -Be "tenant1"
            $result[1].TenantId | Should -Be "tenant2"
        }
    }

    Context "Integration Tests" {
        BeforeEach {
            Mock Get-IISSite { return @($mockIISSite) }
            # Only mock Get-IISApplication if the command exists
            if (Get-Command "Get-IISApplication" -ErrorAction SilentlyContinue) {
                Mock Get-IISApplication { return @($mockWFEApp) }
            } else {
                Mock Get-IISApplication { return @() }
            }
            Mock Test-Path { return $true }
            Mock Get-Content { return $testTenantsConfig }
        }

        It "Should provide consistent results between Test-WFEInstallation and Find-WFEInstances" {
            $testResult = Test-WFEInstallation
            $instances = Find-WFEInstances

            $testResult.Installed | Should -Be ($instances.Count -gt 0)
            
            if ($testResult.Installed) {
                $testResult.InstallPath | Should -Be $instances[0].PhysicalPath
                $testResult.SiteName | Should -Be $instances[0].SiteName
                $testResult.ApplicationPath | Should -Be $instances[0].ApplicationPath
                $testResult.DatabaseServer | Should -Be $instances[0].DatabaseServer
                $testResult.DatabaseName | Should -Be $instances[0].DatabaseName
                $testResult.TenantId | Should -Be $instances[0].TenantID
            }
        }

        It "Should handle real-world deployment scenario" {
            # Simulate the actual deployment found in diagnostic
            $result = Test-WFEInstallation

            $result.Installed | Should -Be $true
            $result.InstallPath | Should -Be "C:\inetpub\wwwroot\WorkflowEngine"
            $result.SiteName | Should -Be "Default Web Site"
            $result.ApplicationPath | Should -Be "/WFE_PGNZ"
            $result.DatabaseServer | Should -Be "SERVER2019\SQL2019"
            $result.DatabaseName | Should -Be "PG_NZ"
            $result.TenantId | Should -Be "ba81e050-ec65-11df-98cf-0800200c9a66"
        }
    }

    Context "Error Handling and Edge Cases" {
        It "Should handle null or empty IIS site data" {
            Mock Get-IISSite { return $null }

            $result = Test-WFEInstallation

            $result.Installed | Should -Be $false
            $result.Error | Should -Not -BeNullOrEmpty
        }

        It "Should handle missing physical path in IIS application" {
            Mock Get-IISApplication { 
                return @([PSCustomObject]@{
                    Path = "/WFE_PGNZ"
                    PhysicalPath = $null
                    ApplicationPool = "DefaultAppPool"
                })
            }

            $result = Test-WFEInstallation

            $result.Installed | Should -Be $false
            $result.Error | Should -Contain "Physical path not found"
        }

        It "Should handle database connection string parsing errors" {
            $invalidConfig = @"
<?xml version="1.0" encoding="utf-8"?>
<tenants>
    <tenant id="test">
        <workflowDatabaseConnection>Invalid Connection String</workflowDatabaseConnection>
        <workflowDatabaseName></workflowDatabaseName>
        <workflowDatabaseServer></workflowDatabaseServer>
        <workflowEnginePath>/WFE</workflowEnginePath>
        <workflowEnginePhysicalPath>C:\path</workflowEnginePhysicalPath>
    </tenant>
</tenants>
"@
            Mock Get-Content { return $invalidConfig }

            $result = Test-WFEInstallation

            $result.Installed | Should -Be $false
            $result.Error | Should -Contain "Error parsing database connection"
        }
    }

    Context "Performance Tests" {
        It "Should complete detection within reasonable time" {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            
            $result = Test-WFEInstallation
            
            $stopwatch.Stop()
            $executionTime = $stopwatch.ElapsedMilliseconds

            $executionTime | Should -BeLessThan 5000  # Should complete within 5 seconds
        }
    }
}
