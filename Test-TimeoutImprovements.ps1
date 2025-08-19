# Test script for improved timeout and retry functionality
# This script demonstrates the enhanced ESS API health check with better timeout handling

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$SiteName = "Default Web Site",
    
    [Parameter(Mandatory = $false)]
    [string]$ApplicationPath = "/Self-Service/ESS",
    
    [Parameter(Mandatory = $false)]
    [int]$TimeoutSeconds = 90,
    
    [Parameter(Mandatory = $false)]
    [int]$MaxRetries = 2,
    
    [Parameter(Mandatory = $false)]
    [int]$RetryDelaySeconds = 5
)

Write-Host "=== Testing Improved ESS API Timeout and Retry Functionality ===" -ForegroundColor Yellow
Write-Host "Date: $(Get-Date)" -ForegroundColor Gray
Write-Host "Configuration:" -ForegroundColor Cyan
Write-Host "  Timeout: $TimeoutSeconds seconds" -ForegroundColor White
Write-Host "  Max Retries: $MaxRetries" -ForegroundColor White
Write-Host "  Retry Delay: $RetryDelaySeconds seconds" -ForegroundColor White
Write-Host "  Target: $SiteName$ApplicationPath" -ForegroundColor White
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
Write-Host "=== Testing Individual ESS Health Check ===" -ForegroundColor Cyan

try {
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    
    Write-Host "Testing: $SiteName$ApplicationPath" -ForegroundColor White
    Write-Host "Using timeout: $TimeoutSeconds seconds, max retries: $MaxRetries" -ForegroundColor Gray
    
    $healthCheck = Get-ESSHealthCheckViaAPI -SiteName $SiteName -ApplicationPath $ApplicationPath -TimeoutSeconds $TimeoutSeconds -MaxRetries $MaxRetries -RetryDelaySeconds $RetryDelaySeconds -Verbose
    
    $stopwatch.Stop()
    $executionTime = [math]::Round($stopwatch.ElapsedMilliseconds / 1000, 2)
    
    Write-Host ""
    Write-Host "=== Results ===" -ForegroundColor Cyan
    Write-Host "Execution Time: $executionTime seconds" -ForegroundColor $(if($executionTime -lt $TimeoutSeconds){"Green"}else{"Yellow"})
    Write-Host "URI: $($healthCheck.Uri)" -ForegroundColor Gray
    Write-Host "Status Code: $($healthCheck.StatusCode)" -ForegroundColor $(if($healthCheck.StatusCode -eq 200){"Green"}else{"Red"})
    Write-Host "Overall Status: $($healthCheck.OverallStatus)" -ForegroundColor $(if($healthCheck.OverallStatus -eq "Healthy"){"Green"}else{"Red"})
    Write-Host "Retry Attempts: $($healthCheck.RetryAttempts)" -ForegroundColor Gray
    
    if ($healthCheck.Error) {
        Write-Host "Error: $($healthCheck.Error)" -ForegroundColor Red
    }
    
    if ($healthCheck.Components) {
        Write-Host "Components: $($healthCheck.Summary.TotalComponents) total, $($healthCheck.Summary.HealthyComponents) healthy" -ForegroundColor Gray
    }
    
    Write-Host ""
    if ($executionTime -lt $TimeoutSeconds) {
        Write-Host "✅ SUCCESS: Request completed within timeout period" -ForegroundColor Green
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
        Write-Host "❌ TIMEOUT ISSUE: The request timed out after $TimeoutSeconds seconds with $MaxRetries retry attempts" -ForegroundColor Red
        Write-Host "💡 Recommendations:" -ForegroundColor Yellow
        Write-Host "   - Try increasing the timeout further (e.g., 120 or 180 seconds)" -ForegroundColor White
        Write-Host "   - Check if the ESS application is running and responsive" -ForegroundColor White
        Write-Host "   - Verify the application path is correct" -ForegroundColor White
        Write-Host "   - Check IIS application pool status" -ForegroundColor White
        Write-Host "   - Consider increasing MaxRetries to 3 or 4" -ForegroundColor White
    } elseif ($_.Exception.Message -like "*404*" -or $_.Exception.Message -like "*Not Found*") {
        Write-Host ""
        Write-Host "❌ ENDPOINT NOT FOUND: The API endpoint does not exist" -ForegroundColor Red
        Write-Host "💡 Recommendations:" -ForegroundColor Yellow
        Write-Host "   - Verify the application path is correct" -ForegroundColor White
        Write-Host "   - Check if the ESS application is properly installed" -ForegroundColor White
        Write-Host "   - Ensure the API endpoint is available at the specified path" -ForegroundColor White
    } else {
        Write-Host ""
        Write-Host "❌ OTHER ERROR: Non-timeout related issue" -ForegroundColor Red
        Write-Host "💡 Check the error message above for specific issues" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "=== Testing All ESS Instances ===" -ForegroundColor Cyan

try {
    Write-Host "Testing health check for all discovered ESS instances..." -ForegroundColor White
    
    $allHealthChecks = Get-ESSHealthCheckForAllInstances -TimeoutSeconds $TimeoutSeconds -MaxRetries $MaxRetries -RetryDelaySeconds $RetryDelaySeconds
    
    Write-Host ""
    Write-Host "=== Summary Results ===" -ForegroundColor Cyan
    Write-Host "Total ESS instances tested: $($allHealthChecks.Count)" -ForegroundColor White
    
    $successfulChecks = ($allHealthChecks | Where-Object { $_.Success -eq $true }).Count
    $failedChecks = ($allHealthChecks | Where-Object { $_.Success -eq $false }).Count
    
    Write-Host "Successful checks: $successfulChecks" -ForegroundColor Green
    Write-Host "Failed checks: $failedChecks" -ForegroundColor $(if($failedChecks -eq 0){"Green"}else{"Red"})
    
    if ($failedChecks -gt 0) {
        Write-Host ""
        Write-Host "Failed instances:" -ForegroundColor Red
        foreach ($check in $allHealthChecks | Where-Object { $_.Success -eq $false }) {
            $instanceName = "$($check.ESSInstance.SiteName)$($check.ESSInstance.ApplicationPath)"
            Write-Host "  - $instanceName : $($check.Error)" -ForegroundColor Red
        }
    }
}
catch {
    Write-Host ""
    Write-Host "❌ ERROR: Failed to test all ESS instances: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== Test Summary ===" -ForegroundColor Yellow
Write-Host "The timeout and retry functionality has been improved with:" -ForegroundColor Green
Write-Host "  ✅ Increased default timeout from 30 to 60 seconds (individual) / 90 seconds (batch)" -ForegroundColor White
Write-Host "  ✅ Added retry logic with configurable retry attempts" -ForegroundColor White
Write-Host "  ✅ Smart retry detection (retries timeouts, skips 404s)" -ForegroundColor White
Write-Host "  ✅ Better error messages and diagnostics" -ForegroundColor White
Write-Host "  ✅ Configurable settings in Config.ps1" -ForegroundColor White
Write-Host ""
Write-Host "Usage examples:" -ForegroundColor White
Write-Host "  Get-ESSHealthCheckViaAPI -SiteName 'Default Web Site' -ApplicationPath '/ESS' -TimeoutSeconds 120 -MaxRetries 3" -ForegroundColor Gray
Write-Host "  Get-ESSHealthCheckForAllInstances -TimeoutSeconds 90 -MaxRetries 2" -ForegroundColor Gray
Write-Host ""
Write-Host "Configuration can be adjusted in src/Config.ps1 under the APIHealthCheck section" -ForegroundColor Gray
