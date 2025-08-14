<#
.SYNOPSIS
    ESS-specific validation module
.DESCRIPTION
    Validates ESS-specific components including detection, web.config encryption, and configuration
.NOTES
    Author: Zoe Lai
    Date: 04/08/2025
    Version: 1.0
#>

function Test-ESSWFEDetection {
    <#
    .SYNOPSIS
        Performs ESS/WFE detection validation
    .DESCRIPTION
        Uses the ESS/WFE detection logic to validate ESS and WFE installations
    .RETURNS
        Array of validation results
    #>
    [CmdletBinding()]
    param()

    try {
        Write-Host "Starting ESS/WFE detection validation..." -ForegroundColor Yellow
        
        # Use global detection results (already populated during initialization)
        $detectionResults = $null
        if ($global:DetectionResults) {
            $detectionResults = $global:DetectionResults
        } elseif ($global:ESSConfig -and $global:ESSConfig.DetectionResults) {
            $detectionResults = $global:ESSConfig.DetectionResults
        }
        
        if (-not $detectionResults) {
            Add-HealthCheckResult -Category "ESS/WFE Detection" -Check "Detection Results" -Status "FAIL" -Message "No detection results available"
            return
        }
        
        # Add ESS installation checks
        if ($detectionResults.ESSInstances.Count -gt 0) {
            Add-HealthCheckResult -Category "ESS/WFE Detection" -Check "ESS Installation" -Status "PASS" -Message "Found $($detectionResults.ESSInstances.Count) ESS installation(s)"
        } else {
            Add-HealthCheckResult -Category "ESS/WFE Detection" -Check "ESS Installation" -Status "INFO" -Message "No ESS installations found on this machine"
        }
        
        # Add WFE installation checks
        if ($detectionResults.WFEInstances.Count -gt 0) {
            Add-HealthCheckResult -Category "ESS/WFE Detection" -Check "WFE Installation" -Status "PASS" -Message "Found $($detectionResults.WFEInstances.Count) WFE installation(s)"
        } else {
            Add-HealthCheckResult -Category "ESS/WFE Detection" -Check "WFE Installation" -Status "INFO" -Message "No WFE installations found on this machine"
        }
        
        # Add deployment type check
        Add-HealthCheckResult -Category "ESS/WFE Detection" -Check "Deployment Type" -Status "INFO" -Message "Deployment Type: $($detectionResults.DeploymentType)"
        
        Write-Host "ESS/WFE detection validation completed." -ForegroundColor Green
    }
    catch {
        Write-Error "Error during ESS/WFE detection validation: $_"
        Add-HealthCheckResult -Category "ESS/WFE Detection" -Check "Detection Process" -Status "FAIL" -Message "Error during detection: $($_.Exception.Message)"
    }
}

function Test-WebConfigEncryptionValidation {
    <#
    .SYNOPSIS
        Validates web.config encryption for SingleSignOn authentication mode
    .DESCRIPTION
        Checks if web.config is properly encrypted when SingleSignOn authentication is used.
        Provides warnings for upgrade scenarios where decryption is needed.
    #>
    [CmdletBinding()]
    param()

    Write-Verbose "Testing web.config encryption validation..."
    
    # Get detection results
    $detectionResults = $null
    if ($global:ESSConfig -and $global:ESSConfig.DetectionResults) {
        $detectionResults = $global:ESSConfig.DetectionResults
    } elseif ($global:DetectionResults) {
        $detectionResults = $global:DetectionResults
    }
    
    if (-not $detectionResults -or -not $detectionResults.ESSInstances) {
        Add-HealthCheckResult -Category "Web.Config Encryption" -Check "ESS Detection" -Status "WARNING" -Message "No ESS instances detected for encryption validation"
        return
    }
    
    foreach ($ess in $detectionResults.ESSInstances) {
        $siteName = $ess.SiteName
        $applicationPath = $ess.ApplicationPath
        $authMode = $ess.AuthenticationMode
        $isEncrypted = $ess.WebConfigEncrypted
        
        # Create site identifier with application alias if available
        $siteIdentifier = Get-FormattedSiteIdentifier -SiteName $siteName -ApplicationPath $applicationPath
        
        if ($authMode -eq "SingleSignOn") {
            if ($isEncrypted) {
                Add-HealthCheckResult -Category "Web.Config Encryption" -Check "SingleSignOn Encryption" -Status "FAIL" -Message "ESS site '$siteIdentifier' uses SingleSignOn authentication and web.config is encrypted. Ensure decrypt first before upgrade."
            } else {
                Add-HealthCheckResult -Category "Web.Config Encryption" -Check "SingleSignOn Encryption" -Status "PASS" -Message "ESS site '$siteIdentifier' uses SingleSignOn authentication and web.config is not encrypted - ready for upgrade"
            }
        } else {
            # For non-SingleSignOn authentication modes, encryption should be false
            if ($isEncrypted) {
                Add-HealthCheckResult -Category "Web.Config Encryption" -Check "Authentication Encryption" -Status "INFO" -Message "ESS site '$siteIdentifier' uses $authMode authentication and web.config is encrypted"
            } else {
                Add-HealthCheckResult -Category "Web.Config Encryption" -Check "Authentication Encryption" -Status "PASS" -Message "ESS site '$siteIdentifier' uses $authMode authentication and web.config is not encrypted"
            }
        }
    }
} 

function Test-ESSVersionValidation {
    <#
    .SYNOPSIS
        Validates ESS and PayGlobal versions for compatibility
    .DESCRIPTION
        Checks ESS version against minimum requirements and PayGlobal version compatibility
    #>
    [CmdletBinding()]
    param()

    Write-Verbose "Testing ESS version validation..."
    
    # Get detection results
    $detectionResults = $null
    if ($global:ESSConfig -and $global:ESSConfig.DetectionResults) {
        $detectionResults = $global:ESSConfig.DetectionResults
    } elseif ($global:DetectionResults) {
        $detectionResults = $global:DetectionResults
    }
    
    if (-not $detectionResults -or -not $detectionResults.ESSInstances) {
        Add-HealthCheckResult -Category "ESS Version Validation" -Check "ESS Detection" -Status "WARNING" -Message "No ESS instances detected for version validation"
        return
    }
    
    foreach ($ess in $detectionResults.ESSInstances) {
        $siteName = $ess.SiteName
        $applicationPath = $ess.ApplicationPath
        $essVersion = $ess.ESSVersion
        $payglobalVersion = $ess.PayGlobalVersion
        $compatibility = $ess.VersionCompatibility
        
        # Create site identifier
        $siteIdentifier = Get-FormattedSiteIdentifier -SiteName $siteName -ApplicationPath $applicationPath
        
        # Check ESS version
        if ($essVersion) {
            if ($compatibility.ESSVersionSupported) {
                Add-HealthCheckResult -Category "ESS Version Validation" -Check "ESS Version" -Status "PASS" -Message "ESS site '$siteIdentifier' version $essVersion is supported"
            } else {
                Add-HealthCheckResult -Category "ESS Version Validation" -Check "ESS Version" -Status "FAIL" -Message "ESS site '$siteIdentifier' version $essVersion is not supported. Minimum required version is 5.4.7.2"
            }
        } else {
            Add-HealthCheckResult -Category "ESS Version Validation" -Check "ESS Version" -Status "WARNING" -Message "ESS site '$siteIdentifier' version could not be determined"
        }
        
        # Check PayGlobal version compatibility
        if ($payglobalVersion) {
            if ($compatibility.PayGlobalVersionCompatible) {
                Add-HealthCheckResult -Category "ESS Version Validation" -Check "PayGlobal Version" -Status "PASS" -Message "ESS site '$siteIdentifier' PayGlobal version $payglobalVersion is compatible with ESS version $essVersion"
            } else {
                Add-HealthCheckResult -Category "ESS Version Validation" -Check "PayGlobal Version" -Status "FAIL" -Message "ESS site '$siteIdentifier' PayGlobal version $payglobalVersion is not compatible with ESS version $essVersion"
            }
        } else {
            Add-HealthCheckResult -Category "ESS Version Validation" -Check "PayGlobal Version" -Status "INFO" -Message "ESS site '$siteIdentifier' PayGlobal version could not be determined"
        }
        
        # Check overall compatibility
        if ($compatibility.OverallCompatibility) {
            Add-HealthCheckResult -Category "ESS Version Validation" -Check "Overall Compatibility" -Status "PASS" -Message "ESS site '$siteIdentifier' versions are compatible for upgrade"
        } else {
            $recommendations = $compatibility.Recommendations -join "; "
            Add-HealthCheckResult -Category "ESS Version Validation" -Check "Overall Compatibility" -Status "FAIL" -Message "ESS site '$siteIdentifier' versions are not compatible for upgrade. Recommendations: $recommendations"
        }
    }
} 

function Test-ESSHTTPSValidation {
    <#
    .SYNOPSIS
        Validates HTTPS usage and SSL certificate expiry for ESS sites
    .DESCRIPTION
        Checks if ESS sites use HTTPS and validates SSL certificate expiry dates
    #>
    [CmdletBinding()]
    param()

    Write-Verbose "Testing ESS HTTPS validation..."
    
    # Get detection results
    $detectionResults = $null
    if ($global:ESSConfig -and $global:ESSConfig.DetectionResults) {
        $detectionResults = $global:ESSConfig.DetectionResults
    } elseif ($global:DetectionResults) {
        $detectionResults = $global:DetectionResults
    }
    
    if (-not $detectionResults -or -not $detectionResults.ESSInstances) {
        Add-HealthCheckResult -Category "ESS HTTPS Validation" -Check "ESS Detection" -Status "WARNING" -Message "No ESS instances detected for HTTPS validation"
        return
    }
    
    foreach ($ess in $detectionResults.ESSInstances) {
        $siteName = $ess.SiteName
        $applicationPath = $ess.ApplicationPath
        $bindingsInfo = $ess.BindingsInfo
        $sslInfo = $ess.SSLInfo
        
        # Create site identifier
        $siteIdentifier = Get-FormattedSiteIdentifier -SiteName $siteName -ApplicationPath $applicationPath
        
        # Check if HTTPS is used
        if ($bindingsInfo.UsesHTTPS) {
            Add-HealthCheckResult -Category "ESS HTTPS Validation" -Check "HTTPS Usage" -Status "PASS" -Message "ESS site '$siteIdentifier' uses HTTPS protocol"
            
            # Check SSL certificate expiry
            if ($sslInfo -and $sslInfo.Count -gt 0) {
                foreach ($ssl in $sslInfo) {
                    if ($ssl.HasValidCertificate) {
                        if ($ssl.Status -eq "VALID") {
                            Add-HealthCheckResult -Category "ESS HTTPS Validation" -Check "SSL Certificate" -Status "PASS" -Message "ESS site '$siteIdentifier' SSL certificate is valid (expires in $($ssl.DaysUntilExpiry) days)"
                        } elseif ($ssl.Status -eq "WARNING") {
                            Add-HealthCheckResult -Category "ESS HTTPS Validation" -Check "SSL Certificate" -Status "WARNING" -Message "ESS site '$siteIdentifier' SSL certificate expires soon (expires in $($ssl.DaysUntilExpiry) days)"
                        } elseif ($ssl.Status -eq "EXPIRED") {
                            Add-HealthCheckResult -Category "ESS HTTPS Validation" -Check "SSL Certificate" -Status "FAIL" -Message "ESS site '$siteIdentifier' SSL certificate has expired ($($ssl.DaysUntilExpiry) days ago)"
                        }
                    } else {
                        Add-HealthCheckResult -Category "ESS HTTPS Validation" -Check "SSL Certificate" -Status "FAIL" -Message "ESS site '$siteIdentifier' SSL certificate is invalid or not found: $($ssl.Error)"
                    }
                }
            } else {
                Add-HealthCheckResult -Category "ESS HTTPS Validation" -Check "SSL Certificate" -Status "WARNING" -Message "ESS site '$siteIdentifier' uses HTTPS but SSL certificate information could not be retrieved"
            }
        } else {
            Add-HealthCheckResult -Category "ESS HTTPS Validation" -Check "HTTPS Usage" -Status "INFO" -Message "ESS site '$siteIdentifier' uses HTTP protocol (not HTTPS)"
        }
    }
}

 