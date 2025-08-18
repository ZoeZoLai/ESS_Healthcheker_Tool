# Test script for improved timeout settings
# This script tests the enhanced timeout functionality

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$SiteName = "Default Web Site",
    
    [Parameter(Mandatory = $false)]
    [string]$ApplicationPath = "/Self-Service/ESS",
    
    [Parameter(Mandatory = $false)]
    [int]$TimeoutSeconds = 90
)

Write-Host "=== Testing Improved ESS API Timeout Settings ===" -ForegroundColor Yellow
Write-Host "Date: $(Get-Date)" -ForegroundColor Gray
Write-Host "Timeout Setting: $TimeoutSeconds seconds" -ForegroundColor Green
Write-Host ""

# Import the ESSHealthCheckAPI module
$modulePath = ".\src\modules\Detection\ESSHealthCheckAPI.ps1"
if (Test-Path $modulePath) {
    . $modulePath
    Write-Host "✅ Loaded ESSHealthCheckAPI module" -ForegroundColor Green
} else {
    Write-Host "❌ Could not find ESSHealthCheckAPI module at: $modulePath" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "=== Testing ESS Health Check with Custom Timeout ===" -ForegroundColor Cyan

try {
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    
    Write-Host "Testing: $SiteName$ApplicationPath with $TimeoutSeconds second timeout" -ForegroundColor White
    
    $healthCheck = Get-ESSHealthCheckViaAPI -SiteName $SiteName -ApplicationPath $ApplicationPath -TimeoutSeconds $TimeoutSeconds -Verbose
    
    $stopwatch.Stop()
    $executionTime = [math]::Round($stopwatch.ElapsedMilliseconds / 1000, 2)
    
    Write-Host ""
    Write-Host "=== Results ===" -ForegroundColor Cyan
    Write-Host "Execution Time: $executionTime seconds" -ForegroundColor $(if($executionTime -lt $TimeoutSeconds){"Green"}else{"Yellow"})
    Write-Host "URI: $($healthCheck.Uri)" -ForegroundColor Gray
    Write-Host "Status Code: $($healthCheck.StatusCode)" -ForegroundColor $(if($healthCheck.StatusCode -eq 200){"Green"}else{"Red"})
    Write-Host "Overall Status: $($healthCheck.OverallStatus)" -ForegroundColor $(if($healthCheck.OverallStatus -eq "Healthy"){"Green"}else{"Red"})
    
    if ($healthCheck.Error) {
        Write-Host "Error: $($healthCheck.Error)" -ForegroundColor Red
    }
    
    if ($healthCheck.Components) {
        Write-Host "Components: $($healthCheck.Summary.TotalComponents) total, $($healthCheck.Summary.HealthyComponents) healthy" -ForegroundColor Gray
    }
    
    Write-Host ""
    if ($executionTime -lt $TimeoutSeconds) {
        Write-Host "✅ SUCCESS: Request completed within timeout period ($executionTime < $TimeoutSeconds seconds)" -ForegroundColor Green
    } else {
        Write-Host "⚠️  WARNING: Request took longer than expected but did not timeout" -ForegroundColor Yellow
    }
}
catch {
    $stopwatch.Stop()
    $executionTime = [math]::Round($stopwatch.ElapsedMilliseconds / 1000, 2)
    
    Write-Host ""
    Write-Host "=== Error Results ===" -ForegroundColor Red
    Write-Host "Execution Time: $executionTime seconds" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    
    if ($_.Exception.Message -like "*timeout*") {
        Write-Host ""
        Write-Host "❌ TIMEOUT ISSUE: The request still timed out after $TimeoutSeconds seconds" -ForegroundColor Red
        Write-Host "💡 Recommendations:" -ForegroundColor Yellow
        Write-Host "   - Try increasing the timeout further (e.g., 120 or 180 seconds)" -ForegroundColor White
        Write-Host "   - Check if the ESS application is running and responsive" -ForegroundColor White
        Write-Host "   - Verify the application path is correct" -ForegroundColor White
        Write-Host "   - Check IIS application pool status" -ForegroundColor White
    } else {
        Write-Host ""
        Write-Host "❌ OTHER ERROR: Non-timeout related issue" -ForegroundColor Red
        Write-Host "💡 Check the error message above for specific issues" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "=== Test Summary ===" -ForegroundColor Yellow
Write-Host "The timeout has been improved from 30 seconds to $TimeoutSeconds seconds" -ForegroundColor Green
Write-Host "You can now customize the timeout using the -TimeoutSeconds parameter" -ForegroundColor Green
Write-Host ""
Write-Host "Usage examples:" -ForegroundColor White
Write-Host "  Get-ESSHealthCheckViaAPI -SiteName 'Default Web Site' -ApplicationPath '/ESS' -TimeoutSeconds 120" -ForegroundColor Gray
Write-Host "  Get-ESSHealthCheckForAllInstances -TimeoutSeconds 90" -ForegroundColor Gray
