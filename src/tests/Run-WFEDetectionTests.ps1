<#
.SYNOPSIS
    Test runner for WFEDetection.ps1 module
.DESCRIPTION
    Executes Pester tests for the WFE detection module and provides detailed reporting
.NOTES
    Author: Zoe Lai
    Date: 15/08/2025
    Version: 1.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$TestPath = "WFEDetection.Tests.ps1",
    
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "TestResults",
    
    [Parameter(Mandatory = $false)]
    [switch]$Verbose,
    
    [Parameter(Mandatory = $false)]
    [switch]$CodeCoverage
)

# Ensure Pester is available
if (-not (Get-Module -ListAvailable -Name Pester)) {
    Write-Error "Pester module is not installed. Please install it using: Install-Module -Name Pester -Force"
    exit 1
}

# Import Pester
Import-Module Pester

# Set up test configuration
$testConfig = @{
    Path = Join-Path $PSScriptRoot $TestPath
    Output = "Detailed"
    PassThru = $true
}

if ($Verbose) {
    $testConfig.Output = "Verbose"
}

if ($CodeCoverage) {
    $testConfig.CodeCoverage = @(
        Join-Path $PSScriptRoot "..\modules\Detection\WFEDetection.ps1"
    )
    $testConfig.CodeCoverageOutputFile = Join-Path $PSScriptRoot "..\..\CodeCoverage.xml"
    $testConfig.CodeCoverageOutputFileFormat = "JaCoCo"
}

# Create output directory if it doesn't exist
$outputDir = Join-Path $PSScriptRoot "..\..\$OutputPath"
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

# Run the tests
Write-Host "Running WFE Detection Tests..." -ForegroundColor Yellow
Write-Host "Test Path: $($testConfig.Path)" -ForegroundColor Gray
Write-Host "Output Directory: $outputDir" -ForegroundColor Gray

try {
    $testResults = Invoke-Pester @testConfig
    
    # Generate test report
    $reportPath = Join-Path $outputDir "WFEDetection-TestResults-$(Get-Date -Format 'yyyyMMdd-HHmmss').xml"
    $testResults | Export-Clixml -Path $reportPath
    
    # Display summary
    Write-Host "`n=== Test Results Summary ===" -ForegroundColor Cyan
    Write-Host "Total Tests: $($testResults.TotalCount)" -ForegroundColor White
    Write-Host "Passed: $($testResults.PassedCount)" -ForegroundColor Green
    Write-Host "Failed: $($testResults.FailedCount)" -ForegroundColor Red
    Write-Host "Skipped: $($testResults.SkippedCount)" -ForegroundColor Yellow
    
    if ($testResults.FailedCount -gt 0) {
        Write-Host "`n=== Failed Tests ===" -ForegroundColor Red
        foreach ($test in $testResults.TestResult | Where-Object { $_.Result -eq "Failed" }) {
            Write-Host "Test: $($test.Name)" -ForegroundColor Red
            Write-Host "Error: $($test.FailureMessage)" -ForegroundColor Red
            Write-Host "---" -ForegroundColor Gray
        }
    }
    
    # Display code coverage if enabled
    if ($CodeCoverage -and $testResults.CodeCoverage) {
        Write-Host "`n=== Code Coverage ===" -ForegroundColor Cyan
        $coverage = $testResults.CodeCoverage.NumberOfCommandsExecuted / $testResults.CodeCoverage.NumberOfCommandsAnalyzed * 100
        Write-Host "Coverage: $([math]::Round($coverage, 2))%" -ForegroundColor White
    }
    
    Write-Host "`nTest Report saved to: $reportPath" -ForegroundColor Gray
    
    # Return exit code based on test results
    if ($testResults.FailedCount -gt 0) {
        exit 1
    } else {
        exit 0
    }
}
catch {
    Write-Error "Error running tests: $_"
    exit 1
}
