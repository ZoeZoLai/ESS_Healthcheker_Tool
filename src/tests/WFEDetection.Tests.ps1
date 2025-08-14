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
        # Create test data and mock objects
        $testTenantsConfig = @"
<?xml version="1.0" encoding="utf-8"?>
<tenants>
    <tenant id="TEST001">
        <workflowDatabaseConnection>data source=SERVER2019\SQL2019;initial catalog=WorkflowDB;integrated security=true</workflowDatabaseConnection>
        <clientUrl>http://localhost/WorkflowEngine</clientUrl>
        <from-email-address>workflow@testcompany.com</from-email-address>
    </tenant>
</tenants>
"@

        $testTenantsConfigPath = Join-Path $TestDrive "tenants.config"
        $testTenantsConfig | Out-File -FilePath $testTenantsConfigPath -Encoding UTF8

        # Mock IIS site data
        $mockIISSite = @{
            Name = "Default Web Site"
            PhysicalPath = "C:\inetpub\wwwroot"
            ApplicationPool = "DefaultAppPool"
        }

        $mockIISApplication = @{
            Path = "/WorkflowEngine"
            PhysicalPath = "C:\inetpub\wwwroot\WorkflowEngine"
            ApplicationPool = "WorkflowAppPool"
        }
    }

    Describe "Test-WFEInstallation" {
        Context "When IIS is not installed" {
            BeforeAll {
                Mock Get-WindowsFeature { return $null }
                Mock Get-ItemProperty { return $null }
                Mock Get-Service { return $null }
            }

            It "Should return WFE not installed when IIS is not available" {
                $result = Test-WFEInstallation
                
                $result.Installed | Should -Be $false
                $result.InstallPath | Should -Be $null
                $result.SiteName | Should -Be $null
            }
        }

        Context "When IIS is installed but no WFE found" {
            BeforeAll {
                Mock Get-WindowsFeature { 
                    return @{ InstallState = "Installed" }
                }
                Mock Get-IISSite { return @($mockIISSite) }
                Mock Get-IISApplication { return @() }
                Mock Test-Path { return $false }
            }

            It "Should return WFE not installed when no tenants.config found" {
                $result = Test-WFEInstallation
                
                $result.Installed | Should -Be $false
                $result.InstallPath | Should -Be $null
            }
        }

        Context "When WFE is installed" {
            BeforeAll {
                Mock Get-WindowsFeature { 
                    return @{ InstallState = "Installed" }
                }
                Mock Get-IISSite { return @($mockIISSite) }
                Mock Get-IISApplication { return @($mockIISApplication) }
                Mock Test-Path { 
                    param($Path)
                    if ($Path -like "*tenants.config") { return $true }
                    return $false
                }
            }

            It "Should detect WFE installation when tenants.config exists" {
                $result = Test-WFEInstallation
                
                $result.Installed | Should -Be $true
                $result.InstallPath | Should -Be "C:\inetpub\wwwroot\WorkflowEngine"
                $result.SiteName | Should -Be "Default Web Site"
                $result.ApplicationPath | Should -Be "/WorkflowEngine"
            }
        }

        Context "Error handling" {
            BeforeAll {
                Mock Get-WindowsFeature { throw "Access denied" }
                Mock Get-ItemProperty { throw "Registry access failed" }
                Mock Get-Service { throw "Service access failed" }
            }

            It "Should handle errors gracefully and return WFE not installed" {
                $result = Test-WFEInstallation
                
                $result.Installed | Should -Be $false
                $result.InstallPath | Should -Be $null
            }
        }
    }

    Describe "Find-WFEInstances" {
        Context "When no WFE instances found" {
            BeforeAll {
                Mock Get-IISSite { return @() }
            }

            It "Should return empty array when no IIS sites exist" {
                $result = Find-WFEInstances
                
                $result | Should -Be @()
            }
        }

        Context "When WFE instances found" {
            BeforeAll {
                Mock Get-IISSite { return @($mockIISSite) }
                Mock Get-IISApplication { return @($mockIISApplication) }
                Mock Test-Path { 
                    param($Path)
                    if ($Path -like "*tenants.config") { return $true }
                    return $false
                }
            }

            It "Should return array of WFE instances" {
                $result = Find-WFEInstances
                
                $result.Count | Should -Be 1
                $result[0].SiteName | Should -Be "Default Web Site"
                $result[0].PhysicalPath | Should -Be "C:\inetpub\wwwroot\WorkflowEngine"
                $result[0].ApplicationPath | Should -Be "/WorkflowEngine"
            }
        }

        Context "When IIS modules are not available" {
            BeforeAll {
                Mock Import-Module { throw "Module not found" }
            }

            It "Should handle missing IIS modules gracefully" {
                $result = Find-WFEInstances
                
                $result | Should -Be @()
            }
        }
    }

    Describe "Get-TenantsConfigInfo" {
        Context "When tenants.config file exists" {
            It "Should parse tenants.config correctly" {
                $result = Get-TenantsConfigInfo -ConfigPath $testTenantsConfigPath
                
                $result.DatabaseServer | Should -Be "SERVER2019\SQL2019"
                $result.DatabaseName | Should -Be "WorkflowDB"
                $result.ClientUrl | Should -Be "http://localhost/WorkflowEngine"
                $result.TenantId | Should -Be "TEST001"
                $result.FromEmailAddress | Should -Be "workflow@testcompany.com"
            }
        }

        Context "When tenants.config file does not exist" {
            It "Should return empty hashtable when file not found" {
                $result = Get-TenantsConfigInfo -ConfigPath "C:\nonexistent\tenants.config"
                
                $result.Count | Should -Be 0
            }
        }

        Context "When tenants.config has missing elements" {
            BeforeAll {
                $incompleteConfig = @"
<?xml version="1.0" encoding="utf-8"?>
<tenants>
    <tenant id="TEST002">
        <workflowDatabaseConnection>data source=SERVER2019\SQL2019;initial catalog=WorkflowDB</workflowDatabaseConnection>
    </tenant>
</tenants>
"@
                $incompleteConfigPath = Join-Path $TestDrive "incomplete-tenants.config"
                $incompleteConfig | Out-File -FilePath $incompleteConfigPath -Encoding UTF8
            }

            It "Should handle missing optional elements gracefully" {
                $result = Get-TenantsConfigInfo -ConfigPath $incompleteConfigPath
                
                $result.DatabaseServer | Should -Be "SERVER2019\SQL2019"
                $result.DatabaseName | Should -Be "WorkflowDB"
                $result.ClientUrl | Should -Be $null
                $result.TenantId | Should -Be "TEST002"
                $result.FromEmailAddress | Should -Be $null
            }
        }

        Context "When tenants.config has malformed connection string" {
            BeforeAll {
                $malformedConfig = @"
<?xml version="1.0" encoding="utf-8"?>
<tenants>
    <tenant id="TEST003">
        <workflowDatabaseConnection>invalid connection string</workflowDatabaseConnection>
    </tenant>
</tenants>
"@
                $malformedConfigPath = Join-Path $TestDrive "malformed-tenants.config"
                $malformedConfig | Out-File -FilePath $malformedConfigPath -Encoding UTF8
            }

            It "Should handle malformed connection string gracefully" {
                $result = Get-TenantsConfigInfo -ConfigPath $malformedConfigPath
                
                $result.DatabaseServer | Should -Be $null
                $result.DatabaseName | Should -Be $null
                $result.TenantId | Should -Be "TEST003"
            }
        }
    }

    Describe "Integration Tests" {
        Context "End-to-end WFE detection" {
            BeforeAll {
                # Mock successful IIS and WFE detection
                Mock Get-WindowsFeature { 
                    return @{ InstallState = "Installed" }
                }
                Mock Get-IISSite { return @($mockIISSite) }
                Mock Get-IISApplication { return @($mockIISApplication) }
                Mock Test-Path { 
                    param($Path)
                    if ($Path -like "*tenants.config") { return $true }
                    return $false
                }
            }

            It "Should perform complete WFE detection workflow" {
                # Test individual function
                $wfeInstallation = Test-WFEInstallation
                $wfeInstallation.Installed | Should -Be $true

                # Test instance discovery
                $wfeInstances = Find-WFEInstances
                $wfeInstances.Count | Should -Be 1

                # Test config parsing
                $configInfo = Get-TenantsConfigInfo -ConfigPath $testTenantsConfigPath
                $configInfo.DatabaseServer | Should -Not -BeNullOrEmpty
            }
        }
    }

    Describe "Edge Cases" {
        Context "Multiple WFE installations" {
            BeforeAll {
                $mockSite1 = @{
                    Name = "Default Web Site"
                    PhysicalPath = "C:\inetpub\wwwroot"
                    ApplicationPool = "DefaultAppPool"
                }
                $mockSite2 = @{
                    Name = "Workflow Site"
                    PhysicalPath = "C:\workflow"
                    ApplicationPool = "WorkflowPool"
                }
                $mockApp1 = @{
                    Path = "/WorkflowEngine1"
                    PhysicalPath = "C:\inetpub\wwwroot\WorkflowEngine1"
                    ApplicationPool = "WorkflowAppPool1"
                }
                $mockApp2 = @{
                    Path = "/WorkflowEngine2"
                    PhysicalPath = "C:\workflow\WorkflowEngine2"
                    ApplicationPool = "WorkflowAppPool2"
                }

                Mock Get-WindowsFeature { 
                    return @{ InstallState = "Installed" }
                }
                Mock Get-IISSite { return @($mockSite1, $mockSite2) }
                Mock Get-IISApplication { 
                    param($Site)
                    if ($Site.Name -eq "Default Web Site") {
                        return @($mockApp1)
                    } else {
                        return @($mockApp2)
                    }
                }
                Mock Test-Path { 
                    param($Path)
                    if ($Path -like "*tenants.config") { return $true }
                    return $false
                }
            }

            It "Should detect multiple WFE installations" {
                $result = Find-WFEInstances
                
                $result.Count | Should -Be 2
                $result[0].SiteName | Should -Be "Default Web Site"
                $result[1].SiteName | Should -Be "Workflow Site"
            }
        }

        Context "WFE in site root vs application" {
            BeforeAll {
                $mockSite = @{
                    Name = "WFE Site"
                    PhysicalPath = "C:\wfe-root"
                    ApplicationPool = "WFEAppPool"
                }
                $mockApp = @{
                    Path = "/WFEApp"
                    PhysicalPath = "C:\wfe-app"
                    ApplicationPool = "WFEAppPool"
                }

                Mock Get-WindowsFeature { 
                    return @{ InstallState = "Installed" }
                }
                Mock Get-IISSite { return @($mockSite) }
                Mock Get-IISApplication { return @($mockApp) }
                Mock Test-Path { 
                    param($Path)
                    # Only return true for app path, not root
                    if ($Path -like "*wfe-app*tenants.config") { return $true }
                    return $false
                }
            }

            It "Should detect WFE in application path, not site root" {
                $result = Find-WFEInstances
                
                $result.Count | Should -Be 1
                $result[0].PhysicalPath | Should -Be "C:\wfe-app"
                $result[0].ApplicationPath | Should -Be "/WFEApp"
                $result[0].IsRootApplication | Should -Be $false
            }
        }
    }

    Describe "Performance Tests" {
        Context "Large number of IIS sites" {
            BeforeAll {
                $largeSiteList = 1..100 | ForEach-Object {
                    @{
                        Name = "Site$_"
                        PhysicalPath = "C:\sites\site$_"
                        ApplicationPool = "AppPool$_"
                    }
                }

                Mock Get-WindowsFeature { 
                    return @{ InstallState = "Installed" }
                }
                Mock Get-IISSite { return $largeSiteList }
                Mock Get-IISApplication { return @() }
                Mock Test-Path { return $false }
            }

            It "Should handle large number of sites efficiently" {
                $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
                $result = Find-WFEInstances
                $stopwatch.Stop()

                $stopwatch.ElapsedMilliseconds | Should -BeLessThan 5000  # Should complete within 5 seconds
                $result.Count | Should -Be 0  # No WFE found in this test
            }
        }
    }
}
