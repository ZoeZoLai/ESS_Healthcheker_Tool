<#
.SYNOPSIS
    Test and troubleshoot ESS API health check functionality
.DESCRIPTION
    Tests the ESS health check API and provides troubleshooting information
    for timeout and connectivity issues
.NOTES
    Author: Zoe Lai
    Date: 15/08/2025
    Version: 1.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$SiteName = "Default Web Site",
    
    [Parameter(Mandatory = $false)]
    [string]$ApplicationPath = "/ESS_PGNZ",
    
    [Parameter(Mandatory = $false)]
    [int]$TimeoutSeconds = 30
)

# Import required modules
$modulePaths = @(
    "..\modules\Detection\ESSDetection.ps1",
    "..\modules\Detection\ESSHealthCheckAPI.ps1"
)

foreach ($modulePath in $modulePaths) {
    $fullPath = Join-Path $PSScriptRoot $modulePath
    if (Test-Path $fullPath) {
        . $fullPath
        Write-Host "Loaded module: $modulePath" -ForegroundColor Green
    } else {
        Write-Warning "Module not found: $fullPath"
    }
}

Write-Host "=== ESS API Health Check Test ===" -ForegroundColor Yellow
Write-Host "Date: $(Get-Date)" -ForegroundColor Gray
Write-Host "Computer: $env:COMPUTERNAME" -ForegroundColor Gray
Write-Host "Site: $SiteName" -ForegroundColor Gray
Write-Host "Application: $ApplicationPath" -ForegroundColor Gray
Write-Host ""

# Test 1: Check if functions are available
Write-Host "=== Function Availability ===" -ForegroundColor Cyan
$functions = @("Get-ESSHealthCheckViaAPI", "Find-ESSInstances")
foreach ($function in $functions) {
    if (Get-Command $function -ErrorAction SilentlyContinue) {
        Write-Host "[PASS] $function function exists" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] $function function not found" -ForegroundColor Red
    }
}

Write-Host ""

# Test 2: Find ESS Instances
Write-Host "=== ESS Instance Discovery ===" -ForegroundColor Cyan
try {
    $essInstances = Find-ESSInstances
    Write-Host "ESS Instances Found: $($essInstances.Count)" -ForegroundColor $(if($essInstances.Count -gt 0){"Green"}else{"Yellow"})
    
    if ($essInstances.Count -gt 0) {
        foreach ($instance in $essInstances) {
            Write-Host "  Instance: $($instance.SiteName)$($instance.ApplicationPath)" -ForegroundColor White
            Write-Host "    Physical Path: $($instance.PhysicalPath)" -ForegroundColor Gray
            Write-Host "    Database: $($instance.DatabaseServer)/$($instance.DatabaseName)" -ForegroundColor Gray
            Write-Host "    Tenant ID: $($instance.TenantID)" -ForegroundColor Gray
            Write-Host ""
        }
    } else {
        Write-Host "No ESS instances found - cannot test API health check" -ForegroundColor Red
        exit 1
    }
}
catch {
    Write-Host "[ERROR] Failed to find ESS instances: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Test 3: Test API Health Check with different timeouts
Write-Host "=== API Health Check Tests ===" -ForegroundColor Cyan

$testTimeouts = @(5, 10, 30, 60)
$firstInstance = $essInstances[0]

foreach ($timeout in $testTimeouts) {
    Write-Host "Testing with $timeout second timeout..." -ForegroundColor White
    
    try {
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        
        # Test the API health check
        $healthCheck = Get-ESSHealthCheckViaAPI -SiteName $firstInstance.SiteName -ApplicationPath $firstInstance.ApplicationPath
        
        $stopwatch.Stop()
        $executionTime = $stopwatch.ElapsedMilliseconds
        
        Write-Host "  Execution Time: $executionTime ms" -ForegroundColor Gray
        Write-Host "  URI: $($healthCheck.Uri)" -ForegroundColor Gray
        Write-Host "  Status Code: $($healthCheck.StatusCode)" -ForegroundColor Gray
        Write-Host "  Success: $($healthCheck.Success)" -ForegroundColor $(if($healthCheck.Success){"Green"}else{"Red"})
        Write-Host "  Overall Status: $($healthCheck.OverallStatus)" -ForegroundColor Gray
        
        if ($healthCheck.Error) {
            Write-Host "  Error: $($healthCheck.Error)" -ForegroundColor Red
        }
        
        if ($healthCheck.Success) {
            Write-Host "  Components: $($healthCheck.Summary.TotalComponents) total, $($healthCheck.Summary.HealthyComponents) healthy" -ForegroundColor Gray
            
            if ($healthCheck.Components.Count -gt 0) {
                Write-Host "  Component Details:" -ForegroundColor Gray
                foreach ($component in $healthCheck.Components) {
                    $statusColor = if ($component.Status -eq "Healthy") { "Green" } else { "Red" }
                    Write-Host "    $($component.Name): $($component.Status) (v$($component.Version))" -ForegroundColor $statusColor
                }
            }
            
            Write-Host "  [SUCCESS] API health check completed successfully" -ForegroundColor Green
            break  # Exit loop if successful
        } else {
            Write-Host "  [FAILED] API health check failed" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "  [ERROR] Exception: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host ""
}

Write-Host ""

# Test 4: Network Connectivity Tests
Write-Host "=== Network Connectivity Tests ===" -ForegroundColor Cyan

$testUrls = @(
    "http://localhost",
    "http://localhost$($firstInstance.ApplicationPath)",
    "http://localhost$($firstInstance.ApplicationPath)/api/v1/healthcheck"
)

foreach ($url in $testUrls) {
    Write-Host "Testing connectivity to: $url" -ForegroundColor White
    
    try {
        $response = Invoke-WebRequest -Uri $url -TimeoutSec 10 -ErrorAction Stop
        Write-Host "  Status Code: $($response.StatusCode)" -ForegroundColor Green
        Write-Host "  Response Time: $($response.BaseResponse.ResponseTime) ms" -ForegroundColor Gray
    }
    catch {
        Write-Host "  [FAILED] $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""

# Test 5: IIS Application Pool Status
Write-Host "=== IIS Application Pool Status ===" -ForegroundColor Cyan

try {
    Import-Module WebAdministration -ErrorAction Stop
    
    $appPoolName = $firstInstance.ApplicationPool
    if ($appPoolName) {
        $appPool = Get-IISAppPool -Name $appPoolName -ErrorAction SilentlyContinue
        if ($appPool) {
            Write-Host "Application Pool: $appPoolName" -ForegroundColor White
            Write-Host "  Status: $($appPool.State)" -ForegroundColor $(if($appPool.State -eq "Started"){"Green"}else{"Red"})
            Write-Host "  .NET CLR Version: $($appPool.ManagedRuntimeVersion)" -ForegroundColor Gray
            Write-Host "  Managed Pipeline Mode: $($appPool.ManagedPipelineMode)" -ForegroundColor Gray
        } else {
            Write-Host "Application Pool '$appPoolName' not found" -ForegroundColor Red
        }
    } else {
        Write-Host "No application pool name available" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "Failed to check IIS application pool: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test 6: Troubleshooting Recommendations
Write-Host "=== Troubleshooting Recommendations ===" -ForegroundColor Yellow

$recommendations = @()

if ($essInstances.Count -eq 0) {
    $recommendations += "No ESS instances found - verify ESS installation and IIS configuration"
}

if ($healthCheck -and -not $healthCheck.Success) {
    $recommendations += "API health check failed - check application pool status and web.config"
    $recommendations += "Verify the ESS application is running and accessible"
    $recommendations += "Check firewall settings and network connectivity"
}

if ($recommendations.Count -gt 0) {
    Write-Host "Issues detected. Recommendations:" -ForegroundColor Red
    foreach ($rec in $recommendations) {
        Write-Host "  - $rec" -ForegroundColor White
    }
} else {
    Write-Host "No major issues detected" -ForegroundColor Green
}

Write-Host "`nTest completed at: $(Get-Date)" -ForegroundColor Gray
