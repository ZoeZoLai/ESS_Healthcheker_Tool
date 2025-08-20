# Test script for SQL Server information display
# This script tests the corrected SQL Server detection

Write-Host "=== Testing SQL Server Information Detection ===" -ForegroundColor Yellow
Write-Host "Date: $(Get-Date)" -ForegroundColor Gray
Write-Host ""

# Import the SQL Server information module
$modulePath = ".\src\modules\System\SQLInfo.ps1"
if (Test-Path $modulePath) {
    . $modulePath
    Write-Host "✅ Loaded SQLInfo module" -ForegroundColor Green
} else {
    Write-Host "❌ Could not find SQLInfo module at: $modulePath" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "=== Getting SQL Server Information ===" -ForegroundColor Cyan

try {
    $sqlInfo = Get-SQLServerInformation
    
    Write-Host ""
    Write-Host "=== SQL Server Detection Results ===" -ForegroundColor Cyan
    Write-Host "Is Installed: $($sqlInfo.IsInstalled)" -ForegroundColor $(if($sqlInfo.IsInstalled){"Green"}else{"Red"})
    Write-Host "Instance Count: $($sqlInfo.Instances.Count)" -ForegroundColor Gray
    
    if ($sqlInfo.Instances.Count -gt 0) {
        Write-Host "Instances:" -ForegroundColor White
        foreach ($instance in $sqlInfo.Instances) {
            Write-Host "  - $instance" -ForegroundColor Gray
        }
    }
    
    Write-Host "Version Count: $($sqlInfo.Versions.Count)" -ForegroundColor Gray
    if ($sqlInfo.Versions.Count -gt 0) {
        Write-Host "Versions:" -ForegroundColor White
        foreach ($version in $sqlInfo.Versions) {
            Write-Host "  - $version" -ForegroundColor Gray
        }
    }
    
    Write-Host "Service Count: $($sqlInfo.Services.Count)" -ForegroundColor Gray
    if ($sqlInfo.Services.Count -gt 0) {
        Write-Host "Running Services:" -ForegroundColor White
        foreach ($service in $sqlInfo.Services) {
            Write-Host "  - $($service.DisplayName) ($($service.Status))" -ForegroundColor Gray
        }
    }
    
    Write-Host ""
    Write-Host "=== Report Format Test ===" -ForegroundColor Cyan
    $displayText = "$($sqlInfo.Instances.Count) instance$(if($sqlInfo.Instances.Count -ne 1){'s'}) - $($sqlInfo.Versions -join ', ')"
    Write-Host "Report Display: $displayText" -ForegroundColor Green
    
    Write-Host ""
    if ($sqlInfo.IsInstalled) {
        Write-Host "✅ SUCCESS: SQL Server information detected and formatted correctly" -ForegroundColor Green
    } else {
        Write-Host "ℹ️  INFO: No SQL Server installation detected" -ForegroundColor Yellow
    }
}
catch {
    Write-Host ""
    Write-Host "❌ ERROR: Failed to get SQL Server information" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== Expected Output Examples ===" -ForegroundColor Yellow
Write-Host "Before fix: '0 instances - 150, 160'" -ForegroundColor Red
Write-Host "After fix:  '1 instance - SQL Server 2019, SQL Server 2022'" -ForegroundColor Green
Write-Host "Or:         '2 instances - SQL Server 2019'" -ForegroundColor Green
