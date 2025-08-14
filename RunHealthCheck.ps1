<#
.SYNOPSIS
    Simple launcher script for ESS Pre-Upgrade Health Checker
.DESCRIPTION
    This script launches the ESS Health Checker with proper error handling
.NOTES
    Author: Zoe Lai
    Date: 30/07/2025
    Version: 1.0
#>

[CmdletBinding()]
param()

# Set execution policy for this session if needed
try {
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force
}
catch {
    Write-Warning "Could not set execution policy: $_"
}

# Change to script directory
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptPath

Write-Host "ESS Pre-Upgrade Health Checker" -ForegroundColor Cyan
Write-Host "===============================" -ForegroundColor Cyan
Write-Host ""

try {
    # Import the main script
    Write-Host "Loading ESS Health Checker modules..." -ForegroundColor Yellow
    
    # Change to src directory for proper module loading
    $srcPath = Join-Path $scriptPath "src"
    if (Test-Path $srcPath) {
        Set-Location $srcPath
        . .\Main.ps1
        
        Write-Host "Starting health checks..." -ForegroundColor Yellow
        
        # Run the health checks
        $reportPath = Start-ESSHealthChecks
    } else {
        throw "Source directory not found at: $srcPath"
    }
    
    Write-Host ""
    Write-Host "Health check completed successfully!" -ForegroundColor Green
    Write-Host "Report location: $reportPath" -ForegroundColor Cyan
    
    # Pause to let user see results
    Write-Host ""
    Write-Host "Press any key to continue..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
catch {
    Write-Error "An error occurred running the health check: $_"
    Write-Host ""
    Write-Host "Press any key to continue..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}
