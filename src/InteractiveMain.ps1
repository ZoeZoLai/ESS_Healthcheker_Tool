<#
.SYNOPSIS
    Interactive ESS Pre-Upgrade Health Checker
.DESCRIPTION
    Enhanced health checker that supports both automated and user-guided health checks
    Allows users to choose between dynamic detection and manual instance selection
.NOTES
    Author: Zoe Lai
    Date: 13/08/2025
    Version: 2.0
#>

# Import Core Health Check Module FIRST (infrastructure)
. .\HealthCheckCore.ps1

# Import System modules first (dependencies)
. .\modules\System\HardwareInfo.ps1
. .\modules\System\OSInfo.ps1
. .\modules\System\IISInfo.ps1
. .\modules\System\SQLInfo.ps1
. .\modules\System\SystemInfoOrchestrator.ps1

# Import Detection modules
. .\modules\Detection\ESSDetection.ps1
. .\modules\Detection\WFEDetection.ps1
. .\modules\Detection\DetectionOrchestrator.ps1

# Import Interactive modules
. .\modules\Interactive\InteractiveDetection.ps1
. .\modules\Interactive\InteractiveValidation.ps1

# Import Utils modules
. .\modules\Utils\HelperFunctions.ps1

# Import Validation modules
. .\modules\Validation\SystemRequirements.ps1
. .\modules\Validation\InfrastructureValidation.ps1
. .\modules\Validation\ESSValidation.ps1
. .\modules\Validation\ValidationOrchestrator.ps1

# Import Configuration (uses dynamic system information)
. .\Config.ps1

# Import Report Generator
. .\ReportGenerator.ps1

# Import Interactive Report Generator
. .\InteractiveReportGenerator.ps1

# Initialize configuration after all modules are loaded
Initialize-ESSHealthCheckerConfiguration

function Start-InteractiveESSHealthChecks {
    <#
    .SYNOPSIS
        Starts the interactive ESS Health Check process
    .DESCRIPTION
        Provides user with options for automated or manual health checks
    #>
    [CmdletBinding()]
    param ()

    try {
        Write-Host "Starting Interactive ESS Pre-Upgrade Health Checks..." -ForegroundColor Cyan
        Write-Host "=====================================================" -ForegroundColor Cyan
        Write-Host ""

        # Get system information from configuration
        $global:SystemInfo = $global:ESSConfig.SystemInfo

        # Display system information summary
        Show-SystemInfoSummary

        # Check IIS installation first
        $iisInstalled = Test-IISInstallation
        
        if (-not $iisInstalled) {
                    Write-Host ""
        Write-Host "[FAIL] IIS is not installed on this machine." -ForegroundColor Red
        Write-Host "   This indicates no ESS/WFE installations are present." -ForegroundColor Yellow
        Write-Host "   Please check other servers or machines for ESS/WFE installations." -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Press any key to exit..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            return
        }

        Write-Host ""
        Write-Host "[OK] IIS is installed on this machine." -ForegroundColor Green
        Write-Host "   ESS/WFE installations may be present." -ForegroundColor Cyan
        Write-Host ""

        # Ask user for health check approach
        $checkApproach = Get-HealthCheckApproach
        
        switch ($checkApproach) {
            "Auto" {
                Write-Host ""
                Write-Host "[AUTO] Running automated health checks..." -ForegroundColor Cyan
                Start-AutomatedHealthChecks
            }
            "Manual" {
                Write-Host ""
                Write-Host "[MANUAL] Running manual health checks..." -ForegroundColor Cyan
                Start-ManualHealthChecks
            }
            "Exit" {
                Write-Host ""
                Write-Host "[EXIT] Exiting health checker..." -ForegroundColor Yellow
                return
            }
        }

        Write-Host ""
        Write-Host "[OK] Health Checks completed successfully!" -ForegroundColor Green
        Write-Host "Press any key to continue..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    } 
    catch {
        Write-Error "An error occurred during the ESS Health Check: $_"
        Write-Host ""
        Write-Host "Press any key to continue..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        throw
    }
}

function Get-HealthCheckApproach {
    <#
    .SYNOPSIS
        Gets user input for health check approach
    .DESCRIPTION
        Presents user with options for automated or manual health checks
    .RETURNS
        String indicating the chosen approach
    #>
    [CmdletBinding()]
    param()

    Write-Host "Please choose your health check approach:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "1. Auto - Dynamic detection and validation of all ESS/WFE instances" -ForegroundColor Cyan
    Write-Host "2. Manual - Select specific instances and provide custom URLs" -ForegroundColor Cyan
    Write-Host "3. Exit - Cancel health check" -ForegroundColor Gray
    Write-Host ""

    do {
        $choice = Read-Host "Enter your choice (1-3)"
        
        switch ($choice) {
            "1" { return "Auto" }
            "2" { return "Manual" }
            "3" { return "Exit" }
            default {
                Write-Host "Invalid choice. Please enter 1, 2, or 3." -ForegroundColor Red
            }
        }
    } while ($true)
}

function Start-AutomatedHealthChecks {
    <#
    .SYNOPSIS
        Runs automated health checks using existing logic
    .DESCRIPTION
        Uses the existing automated detection and validation approach
    #>
    [CmdletBinding()]
    param()

    try {
        # Run system validation checks
        Start-SystemValidation
        
        # Generate report based on results
        Write-Host "Generating ESS Pre-Upgrade Health Check Report..." -ForegroundColor Green
        $reportPath = New-HealthCheckReport -Results $global:HealthCheckResults

        Write-Host "Report generated at: $reportPath" -ForegroundColor Cyan
        return $reportPath
    }
    catch {
        Write-Error "An error occurred during automated health checks: $_"
        throw
    }
}

function Start-ManualHealthChecks {
    <#
    .SYNOPSIS
        Runs manual health checks based on user input
    .DESCRIPTION
        Collects user input for specific instances and runs targeted health checks
    #>
    [CmdletBinding()]
    param()

    try {
        # Get user input for instance selection
        $selectedInstances = Get-UserInstanceSelection
        
        if (-not $selectedInstances -or $selectedInstances.Count -eq 0) {
            Write-Host "No instances selected. Exiting..." -ForegroundColor Yellow
            return
        }

        # Run targeted health checks for selected instances
        Start-TargetedHealthChecks -Instances $selectedInstances
        
        # Generate report based on results
        Write-Host "Generating ESS Pre-Upgrade Health Check Report..." -ForegroundColor Green
        $reportPath = New-InteractiveHealthCheckReport -Results $global:HealthCheckResults -Instances $selectedInstances

        Write-Host "Report generated at: $reportPath" -ForegroundColor Cyan
        return $reportPath
    }
    catch {
        Write-Error "An error occurred during manual health checks: $_"
        throw
    }
}

function Show-SystemInfoSummary {
    <#
    .SYNOPSIS
        Displays a concise summary of gathered system information
    #>
    [CmdletBinding()]
    param ()

    Write-Host "=== System Information Summary ===" -ForegroundColor Magenta

    $sysInfo = $global:SystemInfo
    
    Write-Host "Computer Name: $($sysInfo.ComputerName)" -ForegroundColor White
    Write-Host "Operating System: $($sysInfo.OS.Caption) $(if ($sysInfo.OS.IsServer) { '(Server)' } else { '(Client)' })" -ForegroundColor White
    Write-Host "Total Memory: $($sysInfo.Hardware.TotalPhysicalMemory) GB" -ForegroundColor White
    Write-Host "CPU Cores: $($sysInfo.Hardware.TotalCores)" -ForegroundColor White
    Write-Host "IIS Installed: $(if ($sysInfo.IIS.IsInstalled) { 'Yes (v' + $sysInfo.IIS.Version + ')' } else { 'No' })" -ForegroundColor White
    
    # Show disk space for C: drive
    $cDrive = $sysInfo.Hardware.LogicalDisks | Where-Object { $_.DeviceID -eq 'C:' } | Select-Object -First 1
    if ($cDrive) {
        Write-Host "Available Disk Space (C:): $($cDrive.FreeSpace) GB" -ForegroundColor White
    }
    
    Write-Host ""
}
