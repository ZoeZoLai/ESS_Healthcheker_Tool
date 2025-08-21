<#
.SYNOPSIS
    ESS Pre-Upgrade Health Checker
.DESCRIPTION
    Performs comprehensive checks before upgrading ESS to ensure system readiness
    Automatically detects deployment structure and adapts health checks accordingly
.NOTES
    Author: Zoe Lai
    Date: 29/07/2025
    Version: 1.0
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

# Initialize configuration after all modules are loaded
Initialize-ESSHealthCheckerConfiguration

# Ensure detection results are globally available
if ($global:ESSConfig -and $global:ESSConfig.DetectionResults) {
    $global:DetectionResults = $global:ESSConfig.DetectionResults
}

function Start-ESSHealthChecks {
    <#
    .SYNOPSIS
        Starts the ESS Health Check process
    .DESCRIPTION
        Initializes configuration and runs all health checks
    #>
    [CmdletBinding()]
    param ()

    try {
        Write-Host "Starting ESS Pre-Upgrade Health Checks..." -ForegroundColor Cyan

        # Get system information from configuration
        $global:SystemInfo = $global:ESSConfig.SystemInfo

        # Display system information summary
        Show-SystemInfoSummary -ShowDeploymentInfo $true

        # Run system validation checks
        Start-SystemValidation
        
        # Run additional validation checks
       

        # Generate report based on results
        Write-Host "Generating ESS Pre-Upgrade Health Check Report..." -ForegroundColor Green
        $reportPath = New-HealthCheckReport -Results $global:HealthCheckResults

        Write-Host "`nHealth Checks completed successfully!" -ForegroundColor Green
        Write-Host "Report generated at: $reportPath" -ForegroundColor Cyan
        return $reportPath
    } 
    catch {
        Write-Error "An error occurred during the ESS Health Check: $_"
        throw
    }
}

