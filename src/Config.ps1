<#
.SYNOPSIS
    Configuration settings for the ESS Health Checker.
.DESCRIPTION
    Configuration that uses system information to determine appropriate settings for the ESS Health Checker based on current system.
.NOTES
    Author: Zoe Lai
    Date: 13/08/2025
    Version: 1.3
#>

# SystemInfo module is now loaded via ModuleLoader.ps1

# Initialize system information when needed
function Initialize-SystemInformation {
    if ($null -eq $global:SystemInfo) {
        $global:SystemInfo = Get-SystemInformation
    }
}

function Initialize-ESSHealthCheckerConfiguration {
    <#
    .SYNOPSIS
        Initializes ESS Health Checker configuration based on current system info
    .DESCRIPTION
        Determines configuration for both ESS and WFE components
    #>
    [CmdletBinding()]
    param ()

    try {
        Write-Verbose "Initializing Health Checker configuration based on system information..."

        # Initialize system information if not already done
        Initialize-SystemInformation
        
        # Get system information
        $sysInfo = $global:SystemInfo
        
        # Get ESS/WFE detection results
        $detectionResults = Get-ESSWFEDetection
        
        # Store detection results globally for other modules to use
        $global:DetectionResults = $detectionResults

        # Build ESS configuration - only includes system-level settings
        $global:ESSConfig = @{
            # System information for reference
            SystemInfo = $sysInfo
            
            # ESS/WFE Detection results for detailed reporting
            DetectionResults = $detectionResults

            # Minimum requirements - Based on MYOB PayGlobal Infrastructure Suggestions
            MinimumDiskSpaceGB = Get-MinimumDiskSpace
            MinimumMemoryGB = Get-MinimumMemory
            MinimumCores = Get-MinimumCores
            MinimumProcessorSpeedGHz = Get-MinimumProcessorSpeed
            RequiredOSVersions = @("Windows Server 2016", "Windows Server 2019", "Windows Server 2022")
            RequiredDotNetVersion = "4.8"
            RequiredIISVersion = "7.5"

            # ESS Version Requirements
            MinimumESSVersion = "5.4.7.2"
            ESSVersionCompatibility = @{
                "5.5.1.2" = @{
                    MinimumPayGlobalVersion = "4.66.0.0"
                    Description = "ESS 5.5.1.2 requires PayGlobal 4.66.0.0 or higher"
                }
                "5.6.0.0" = @{
                    MinimumPayGlobalVersion = "4.72.0.0"
                    Description = "ESS 5.6.0.0 requires PayGlobal 4.72.0.0 or higher"
                }
            }

            # Report settings
            ReportOutputPath = Get-ReportOutputPath -SystemInfo $sysInfo
            ReportNameFormat = "ESS_PreUpgrade_HealthCheck_{0:yyyyMMdd_HHmmss}.html"

            # API Health Check Settings
            APIHealthCheck = @{
                DefaultTimeoutSeconds = 90
                MaxRetries = 2
                RetryDelaySeconds = 5
                ConnectionTimeoutSeconds = 30
                ReadWriteTimeoutSeconds = 60
            }

            # Performance and Reliability Settings
            Performance = @{
                EnableRetryLogic = $true
                EnableConnectionPooling = $true
                MaxConcurrentRequests = 3
                RequestDelaySeconds = 1
            }
        }

        Write-Verbose "ESS Health Checker configuration initialized successfully."
        return $global:ESSConfig
    }
    catch {
        Write-Error "Error initializing ESS Health Checker configuration: $_"
        throw
    }
}

function Get-ReportOutputPath {
    <#
    .SYNOPSIS
        Determines report output path
    #>
    param($systemInfo)

    # Use temp path
    if ($env:TEMP) {
        return Join-Path $env:TEMP "ESSHealthCheckReports"
    }

    # Fallback to use user profile
    return "$env:USERPROFILE\ESSHealthCheckReports"
}


function Get-MinimumDiskSpace {
    <#
    .SYNOPSIS
        Returns MYOB PayGlobal ESS Web server or Workflow Engine Server recommended minimum disk space requirement
    #>
    param()

    return 10  # MYOB PayGlobal suggested minimum disk space to alert (GB) for PG Server ESS alert 10 GB
}

function Get-MinimumMemory {
    <#
    .SYNOPSIS
        Returns MYOB PayGlobal ESS Web server or Workflow Engine Server recommended minimum memory requirement
    #>
    param()

    return 32  # MYOB PayGlobal ESS recommended minimum RAM (GB)
}

function Get-MinimumCores {
    <#
    .SYNOPSIS
        Returns MYOB PayGlobal ESS Web server or Workflow Engine Server recommended minimum CPU cores requirement
    #>
    param()

    return 4  # MYOB PayGlobal ESS recommended minimum CPU cores (2 x Multi-Core Server Processor 2.0GHz+)
}

function Get-MinimumProcessorSpeed {
    <#
    .SYNOPSIS
        Returns MYOB PayGlobal ESS Web server or Workflow Engine Server recommended minimum processor speed requirement
    #>
    param()

    return 2.0  # MYOB PayGlobal ESS recommended minimum processor speed (GHz)
}

