<#
.SYNOPSIS
    Validation orchestrator module
.DESCRIPTION
    Coordinates all validation checks including system requirements, infrastructure, and ESS-specific validations
.NOTES
    Author: Zoe Lai
    Date: 04/08/2025
    Version: 1.0
#>

function Start-SystemValidation {
    <#
    .SYNOPSIS
        Performs comprehensive system validation checks
    .DESCRIPTION
        Runs all validation checks and populates the global HealthCheckResults array
    .RETURNS
        Array of validation results
    #>
    [CmdletBinding()]
    param()

    try {
        Write-Host "Starting system validation checks..." -ForegroundColor Yellow
        
        # Clear previous results
        $global:HealthCheckResults = @()
        
        # Run all validation checks
        Test-SystemRequirements
        Test-ESSWFEDetection
        Test-IISConfiguration
        Test-DatabaseConnectivity
        Test-NetworkConnectivity
        Test-SecurityPermissions
        Test-WebConfigEncryptionValidation
        Test-ESSVersionValidation
        Test-ESSHTTPSValidation
        
        # Run ESS API health check validation (using the dedicated API module)
        Test-ESSAPIHealthCheckValidation
        
        # Debug: Check final state of global results before summary calculation
        Write-Verbose "Final check - Total results in global array: $($global:HealthCheckResults.Count)"
        $finalFailResults = $global:HealthCheckResults | Where-Object { $_.Status -eq "FAIL" }
        Write-Verbose "Final FAIL results count: $($finalFailResults.Count)"
        foreach ($fail in $finalFailResults) {
            Write-Verbose "Final FAIL result: $($fail.Category) - $($fail.Check) - $($fail.Message)"
        }
        
        # Get summary statistics
        $summary = Get-HealthCheckSummary
        $totalChecks = $summary.Total
        $passChecks = $summary.Pass
        $failChecks = $summary.Fail
        $warningChecks = $summary.Warning
        $infoChecks = $summary.Info
        

        

        
        # Ensure all counts are properly initialized (handle null/empty values)
        $totalChecks = if ($totalChecks) { $totalChecks } else { 0 }
        $passChecks = if ($passChecks) { $passChecks } else { 0 }
        $failChecks = if ($failChecks) { $failChecks } else { 0 }
        $warningChecks = if ($warningChecks) { $warningChecks } else { 0 }
        $infoChecks = if ($infoChecks) { $infoChecks } else { 0 }
        
        Write-Host "`nSystem validation completed." -ForegroundColor Green
        Write-Host "Summary: $passChecks/$totalChecks passed, $failChecks failed, $warningChecks warnings, $infoChecks info items" -ForegroundColor Cyan
        return $global:HealthCheckResults
    }
    catch {
        Write-Error "Error during system validation: $_"
        throw
    }
}

function Test-ESSAPIHealthCheckValidation {
    <#
    .SYNOPSIS
        Validates ESS components using the health check API
    .DESCRIPTION
        Uses the dedicated ESSHealthCheckAPI module to perform API health checks
        and add results to the global health check results.
    #>
    [CmdletBinding()]
    param()

    try {
        Write-Verbose "Testing ESS API health check validation..."
        
        # Import the API health check functions
        $apiModulePath = Join-Path $PSScriptRoot "..\Detection\ESSHealthCheckAPI.ps1"
        if (Test-Path $apiModulePath) {
            . $apiModulePath
        } else {
            Add-HealthCheckResult -Category "ESS API Health Check" -Check "Module Loading" -Status "FAIL" -Message "ESSHealthCheckAPI.ps1 module not found at: $apiModulePath"
            return
        }
        
        # Get detection results
        $detectionResults = $null
        if ($global:ESSConfig -and $global:ESSConfig.DetectionResults) {
            $detectionResults = $global:ESSConfig.DetectionResults
        } elseif ($global:DetectionResults) {
            $detectionResults = $global:DetectionResults
        }
        
        if (-not $detectionResults -or -not $detectionResults.ESSInstances) {
            Add-HealthCheckResult -Category "ESS API Health Check" -Check "ESS Detection" -Status "WARNING" -Message "No ESS instances detected for API health check validation"
            return
        }
        
        # Get health check for all instances and add results
        try {
            # Get timeout settings from configuration
            $timeoutSeconds = if ($global:ESSConfig.APIHealthCheck.DefaultTimeoutSeconds) { $global:ESSConfig.APIHealthCheck.DefaultTimeoutSeconds } else { 90 }
            $maxRetries = if ($global:ESSConfig.APIHealthCheck.MaxRetries) { $global:ESSConfig.APIHealthCheck.MaxRetries } else { 2 }
            $retryDelay = if ($global:ESSConfig.APIHealthCheck.RetryDelaySeconds) { $global:ESSConfig.APIHealthCheck.RetryDelaySeconds } else { 5 }
            
            Write-Verbose "Using API health check settings: Timeout=$timeoutSeconds seconds, MaxRetries=$maxRetries, RetryDelay=$retryDelay seconds"
            
            $healthChecks = Get-ESSHealthCheckForAllInstances -UseGlobalDetection $true -TimeoutSeconds $timeoutSeconds -MaxRetries $maxRetries -RetryDelaySeconds $retryDelay
            
            # Handle PowerShell's behavior where single objects aren't arrays
            if ($healthChecks -is [array]) {
                $healthCheckCount = $healthChecks.Count
            } else {
                $healthCheckCount = if ($null -ne $healthChecks) { 1 } else { 0 }
            }
            
            if ($healthCheckCount -gt 0) {
                # Add API health check results to global results
                Add-APIHealthCheckResults -HealthChecks $healthChecks
                Write-Verbose "Successfully added $healthCheckCount ESS API health check results"
                
                # Debug: Check if FAIL results were added
                $failResults = $global:HealthCheckResults | Where-Object { $_.Status -eq "FAIL" }
                Write-Verbose "Total results after API health check: $($global:HealthCheckResults.Count)"
                Write-Verbose "FAIL results found: $($failResults.Count)"
                foreach ($fail in $failResults) {
                    Write-Verbose "FAIL result: $($fail.Category) - $($fail.Check)"
                }
            } else {
                Add-HealthCheckResult -Category "ESS API Health Check" -Check "API Health Check" -Status "WARNING" -Message "No health check results returned from API"
            }
        }
        catch {
            Add-HealthCheckResult -Category "ESS API Health Check" -Check "API Health Check" -Status "FAIL" -Message "Error during API health check validation: $($_.Exception.Message)"
        }
    }
    catch {
        Write-Error "Error during ESS API health check validation: $_"
        Add-HealthCheckResult -Category "ESS API Health Check" -Check "Validation Process" -Status "FAIL" -Message "Error during validation process: $($_.Exception.Message)"
    }
} 