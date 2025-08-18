<#
.SYNOPSIS
    Test script for Interactive Health Check functionality
.DESCRIPTION
    Tests the interactive health check modules and functions
.NOTES
    Author: Zoe Lai
    Date: 13/08/2025
    Version: 1.0
#>

[CmdletBinding()]
param()

# Import test dependencies
$testPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$srcPath = Split-Path -Parent $testPath
Set-Location $srcPath

# Import modules for testing
. .\HealthCheckCore.ps1
. .\modules\Interactive\InteractiveDetection.ps1
. .\modules\Interactive\InteractiveValidation.ps1

function Test-InteractiveDetectionFunctions {
    <#
    .SYNOPSIS
        Tests interactive detection functions
    #>
    [CmdletBinding()]
    param()

    Write-Host "Testing Interactive Detection Functions..." -ForegroundColor Cyan

    try {
        # Test Get-AvailableInstances
        Write-Host "Testing Get-AvailableInstances..." -ForegroundColor Yellow
        $instances = Get-AvailableInstances
        Write-Host "Found $($instances.Count) available instances" -ForegroundColor Green

        # Test Get-InstanceAlias
        Write-Host "Testing Get-InstanceAlias..." -ForegroundColor Yellow
        $alias = Get-InstanceAlias -SiteName "Default Web Site" -ApplicationPath "/ESS" -Type "ESS"
        Write-Host "Generated alias: $alias" -ForegroundColor Green

        # Test Get-SiteInstanceInfo (if IIS is available)
        if (Get-Command "Get-IISSite" -ErrorAction SilentlyContinue) {
            Write-Host "Testing Get-SiteInstanceInfo..." -ForegroundColor Yellow
            $sites = Get-IISSite -ErrorAction SilentlyContinue
            if ($sites -and $sites.Count -gt 0) {
                $siteInfo = Get-SiteInstanceInfo -Site $sites[0] -ApplicationPath "/"
                if ($siteInfo) {
                    Write-Host "Site info generated successfully" -ForegroundColor Green
                }
            }
        }

        Write-Host "✅ Interactive Detection Functions Test Passed" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "❌ Interactive Detection Functions Test Failed: $_" -ForegroundColor Red
        return $false
    }
}

function Test-InteractiveValidationFunctions {
    <#
    .SYNOPSIS
        Tests interactive validation functions
    #>
    [CmdletBinding()]
    param()

    Write-Host "Testing Interactive Validation Functions..." -ForegroundColor Cyan

    try {
        # Create test instance
        $testInstance = [PSCustomObject]@{
            SiteName = "Test Site"
            ApplicationPath = "/TestApp"
            ApplicationPool = "TestPool"
            PhysicalPath = "C:\Test\Path"
            InstanceType = "ESS"
            Alias = "Test_ESS"
            ESSSiteUrl = "https://test.example.com"
            UserSelected = $true
        }

        # Test instance validation functions
        Write-Host "Testing Test-PhysicalPath..." -ForegroundColor Yellow
        Test-PhysicalPath -Instance $testInstance

        Write-Host "Testing Test-ESSConfiguration..." -ForegroundColor Yellow
        # Create a temporary config file for testing
        $tempConfigPath = Join-Path $env:TEMP "test_payglobal.config"
        @"
<?xml version="1.0" encoding="utf-8"?>
<configuration>
    <connectionString>Server=testserver;Database=testdb;</connectionString>
    <version>5.5.1.2</version>
</configuration>
"@ | Out-File -FilePath $tempConfigPath -Encoding UTF8

        Test-ESSConfiguration -ConfigPath $tempConfigPath -InstanceId "TestSite/TestApp"
        
        # Clean up
        Remove-Item $tempConfigPath -ErrorAction SilentlyContinue

        Write-Host "✅ Interactive Validation Functions Test Passed" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "❌ Interactive Validation Functions Test Failed: $_" -ForegroundColor Red
        return $false
    }
}

function Test-HealthCheckResults {
    <#
    .SYNOPSIS
        Tests health check results functionality
    #>
    [CmdletBinding()]
    param()

    Write-Host "Testing Health Check Results..." -ForegroundColor Cyan

    try {
        # Clear any existing results
        Clear-HealthCheckResults

        # Add test results
        Add-HealthCheckResult -Category "Test Category" -Check "Test Check" -Status "PASS" -Message "Test passed successfully"
        Add-HealthCheckResult -Category "Test Category" -Check "Test Check 2" -Status "FAIL" -Message "Test failed"
        Add-HealthCheckResult -Category "Test Category" -Check "Test Check 3" -Status "WARNING" -Message "Test warning"
        Add-HealthCheckResult -Category "Test Category" -Check "Test Check 4" -Status "INFO" -Message "Test info"

        # Get results
        $results = Get-HealthCheckResults
        Write-Host "Added $($results.Count) test results" -ForegroundColor Green

        # Test summary
        $summary = Get-HealthCheckSummary
        Write-Host "Health check summary generated" -ForegroundColor Green

        Write-Host "✅ Health Check Results Test Passed" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "❌ Health Check Results Test Failed: $_" -ForegroundColor Red
        return $false
    }
}

# Run tests
Write-Host "Starting Interactive Health Check Tests..." -ForegroundColor Magenta
Write-Host "=============================================" -ForegroundColor Magenta
Write-Host ""

$testResults = @()

$testResults += Test-InteractiveDetectionFunctions
$testResults += Test-InteractiveValidationFunctions
$testResults += Test-HealthCheckResults

# Summary
Write-Host ""
Write-Host "Test Summary:" -ForegroundColor Magenta
Write-Host "=============" -ForegroundColor Magenta

$passedTests = ($testResults | Where-Object { $_ -eq $true }).Count
$totalTests = $testResults.Count

Write-Host "Passed: $passedTests/$totalTests" -ForegroundColor Green

if ($passedTests -eq $totalTests) {
    Write-Host "✅ All tests passed!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "❌ Some tests failed!" -ForegroundColor Red
    exit 1
}
