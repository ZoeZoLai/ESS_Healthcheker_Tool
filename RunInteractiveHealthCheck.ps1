<#
.SYNOPSIS
    Interactive launcher script for ESS Pre-Upgrade Health Checker
.DESCRIPTION
    This script launches the Interactive ESS Health Checker with enhanced user experience
    Supports both automated and user-guided health checks
.NOTES
    Author: Zoe Lai
    Date: 13/08/2025
    Version: 2.0
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

Write-Host "ESS Interactive Pre-Upgrade Health Checker" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "Enhanced version with user-guided health checks" -ForegroundColor Yellow
Write-Host ""

try {
    # Import the interactive main script
    Write-Host "Loading Interactive ESS Health Checker modules..." -ForegroundColor Yellow
    
    # Change to src directory for proper module loading
    $srcPath = Join-Path $scriptPath "src"
    if (Test-Path $srcPath) {
        Set-Location $srcPath
        . .\InteractiveMain.ps1
        
        Write-Host "Starting interactive health checks..." -ForegroundColor Yellow
        
        # Run the interactive health checks
        $reportPath = Start-InteractiveESSHealthChecks
    } else {
        throw "Source directory not found at: $srcPath"
    }
    
    Write-Host ""
    Write-Host "Interactive health check completed successfully!" -ForegroundColor Green
    if ($reportPath) {
        Write-Host "Report location: $reportPath" -ForegroundColor Cyan
    }
    
    # Pause to let user see results
    Write-Host ""
    Write-Host "Press any key to continue..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
catch {
    Write-Error "An error occurred running the interactive health check: $_"
    Write-Host ""
    Write-Host "Press any key to continue..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}
