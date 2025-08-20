<#
.SYNOPSIS
    System requirements validation module
.DESCRIPTION
    Validates system requirements for ESS upgrade including hardware, OS, and software requirements
.NOTES
    Author: Zoe Lai
    Date: 04/08/2025
    Version: 1.0
#>

function Test-SystemRequirements {
    <#
    .SYNOPSIS
        Tests system requirements for ESS upgrade
    #>
    [CmdletBinding()]
    param()

    Write-Verbose "Testing system requirements..."
    
    $sysInfo = $global:SystemInfo
    $config = $global:ESSConfig
    
    # Test disk space
    $cDrive = $sysInfo.Hardware.LogicalDisks | Where-Object { $_.DeviceID -eq 'C:' } | Select-Object -First 1
    if ($cDrive) {
        $diskSpaceGB = $cDrive.Size
        $freeSpaceGB = $cDrive.FreeSpace
        $requiredDiskSpace = $config.MinimumDiskSpaceGB
        
        if ($freeSpaceGB -lt $requiredDiskSpace) {
            Add-HealthCheckResult -Category "System Requirements" -Check "Free Disk Space" -Status "FAIL" -Message "Insufficient disk space. Available: $freeSpaceGB (Total: $diskSpaceGB) GB - Required: $requiredDiskSpace GB"
        } else {
            Add-HealthCheckResult -Category "System Requirements" -Check "Free Disk Space" -Status "PASS" -Message "Sufficient disk space available. Available: $freeSpaceGB (Total: $diskSpaceGB) GB - meets requirement of $requiredDiskSpace GB"
        }
    } else {
        Add-HealthCheckResult -Category "System Requirements" -Check "Free Disk Space" -Status "WARNING" -Message "Could not determine disk space"
    }
    
    # Test memory
    $totalMemory = $sysInfo.Hardware.TotalPhysicalMemory
    $requiredMemory = $config.MinimumMemoryGB
    
    if ($totalMemory -lt $requiredMemory) {
        Add-HealthCheckResult -Category "System Requirements" -Check "Memory" -Status "FAIL" -Message "Insufficient memory. Available: $totalMemory GB - Required: $requiredMemory GB"
    } else {
        Add-HealthCheckResult -Category "System Requirements" -Check "Memory" -Status "PASS" -Message "Sufficient memory available. Available: $totalMemory GB - meets requirement of $requiredMemory GB"
    }
    
    # Test CPU cores
    $totalCores = $sysInfo.Hardware.TotalCores
    $requiredCores = $config.MinimumCores
    
    if ($totalCores -lt $requiredCores) {
        Add-HealthCheckResult -Category "System Requirements" -Check "CPU Cores" -Status "FAIL" -Message "Insufficient CPU cores. Available: $totalCores - Required: $requiredCores"
    } else {
        Add-HealthCheckResult -Category "System Requirements" -Check "CPU Cores" -Status "PASS" -Message "Sufficient CPU cores available. Available: $totalCores - meets requirement of $requiredCores"
    }
    
    # Test processor speed
    $averageProcessorSpeed = $sysInfo.Hardware.AverageProcessorSpeedGHz
    $requiredProcessorSpeed = $config.MinimumProcessorSpeedGHz
    
    if ($averageProcessorSpeed -lt $requiredProcessorSpeed) {
        Add-HealthCheckResult -Category "System Requirements" -Check "Processor Speed" -Status "FAIL" -Message "Insufficient processor speed. Available: $averageProcessorSpeed GHz - Required: $requiredProcessorSpeed GHz"
    } else {
        Add-HealthCheckResult -Category "System Requirements" -Check "Processor Speed" -Status "PASS" -Message "Sufficient processor speed available. Available: $averageProcessorSpeed GHz - meets requirement of $requiredProcessorSpeed GHz"
    }
    
    # Test IIS installation and version
    if ($sysInfo.IIS.IsInstalled) {
        $iisVersion = $sysInfo.IIS.Version
        $requiredIISVersion = $config.RequiredIISVersion
        
        # Parse version numbers for comparison
        $iisVersionParts = $iisVersion.Split('.')
        $requiredVersionParts = $requiredIISVersion.Split('.')
        
        $iisVersionNum = [double]"$($iisVersionParts[0]).$($iisVersionParts[1])"
        $requiredVersionNum = [double]"$($requiredVersionParts[0]).$($requiredVersionParts[1])"
        
        if ($iisVersionNum -ge $requiredVersionNum) {
            Add-HealthCheckResult -Category "System Requirements" -Check "IIS Installation" -Status "PASS" -Message "IIS is installed (Version: $iisVersion) - meets minimum requirement of $requiredIISVersion"
        } else {
            Add-HealthCheckResult -Category "System Requirements" -Check "IIS Installation" -Status "FAIL" -Message "IIS version $iisVersion is below minimum requirement of $requiredIISVersion"
        }
    } else {
        Add-HealthCheckResult -Category "System Requirements" -Check "IIS Installation" -Status "FAIL" -Message "IIS is not installed. Required for ESS deployment."
    }
    
    # Test .NET Framework version
    $dotNetVersions = $sysInfo.Registry.DotNetVersions
    $requiredDotNetVersion = $config.RequiredDotNetVersion
    
    if ($dotNetVersions -and $dotNetVersions.Count -gt 0) {
        $highestDotNetVersion = $dotNetVersions | Sort-Object -Descending | Select-Object -First 1
        
        # Parse version numbers for comparison
        $dotNetVersionParts = $highestDotNetVersion.Split('.')
        $requiredDotNetParts = $requiredDotNetVersion.Split('.')
        
        $dotNetVersionNum = [double]"$($dotNetVersionParts[0]).$($dotNetVersionParts[1])"
        $requiredDotNetNum = [double]"$($requiredDotNetParts[0]).$($requiredDotNetParts[1])"
        
        if ($dotNetVersionNum -ge $requiredDotNetNum) {
            Add-HealthCheckResult -Category "System Requirements" -Check ".NET Framework" -Status "PASS" -Message ".NET Framework $highestDotNetVersion installed - meets minimum requirement of $requiredDotNetVersion"
        } else {
            Add-HealthCheckResult -Category "System Requirements" -Check ".NET Framework" -Status "FAIL" -Message ".NET Framework $highestDotNetVersion is below minimum requirement of $requiredDotNetVersion"
        }
    } else {
        Add-HealthCheckResult -Category "System Requirements" -Check ".NET Framework" -Status "FAIL" -Message ".NET Framework is not installed. Required version: $requiredDotNetVersion"
    }
    
    # Test OS version and type
    $osCaption = $sysInfo.OS.Caption
    $isServer = $sysInfo.OS.IsServer
    $requiredOSVersions = $config.RequiredOSVersions
    
    if ($isServer) {
        # Check if server OS meets minimum requirements
        $osSupported = $false
        $serverVersion = $null
        
        foreach ($requiredOS in $requiredOSVersions) {
            if ($osCaption -like "*$requiredOS*") {
                $osSupported = $true
                $serverVersion = $requiredOS
                break
            }
        }
        
        if ($osSupported) {
            Add-HealthCheckResult -Category "System Requirements" -Check "Operating System" -Status "PASS" -Message "Server OS is supported: $osCaption (Detected: $serverVersion)"
        } else {
            Add-HealthCheckResult -Category "System Requirements" -Check "Operating System" -Status "FAIL" -Message "Server OS is too old: $osCaption. Minimum required: $($requiredOSVersions -join ', ')"
        }
    } else {
        # Client OS - show as INFO since ESS is designed for server deployment
        Add-HealthCheckResult -Category "System Requirements" -Check "Operating System" -Status "INFO" -Message "Client OS detected: $osCaption. ESS is designed for server deployment, but health check can still run on client systems."
    }
} 