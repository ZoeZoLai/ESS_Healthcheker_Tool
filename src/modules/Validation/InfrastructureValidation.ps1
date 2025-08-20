<#
.SYNOPSIS
    Infrastructure validation module
.DESCRIPTION
    Validates infrastructure components including IIS, database connectivity, and network
.NOTES
    Author: Zoe Lai
    Date: 04/08/2025
    Version: 1.0
#>

function Test-IISConfiguration {
    <#
    .SYNOPSIS
        Tests IIS configuration
    #>
    [CmdletBinding()]
    param()

    Write-Verbose "Testing IIS configuration..."
    
    $sysInfo = $global:SystemInfo
    
    # IIS installation is already checked in System Requirements
    # Only proceed with configuration checks if IIS is installed
    if ($sysInfo.IIS.IsInstalled) {
        # Test IIS sites
        if ($sysInfo.IIS.Sites -and $sysInfo.IIS.Sites.Count -gt 0) {
            Add-HealthCheckResult -Category "IIS Configuration" -Check "IIS Sites" -Status "PASS" -Message "Found $($sysInfo.IIS.Sites.Count) IIS sites"
        } else {
            Add-HealthCheckResult -Category "IIS Configuration" -Check "IIS Sites" -Status "WARNING" -Message "No IIS sites found"
        }
        
        # Test IIS application pools
        if ($sysInfo.IIS.ApplicationPools -and $sysInfo.IIS.ApplicationPools.Count -gt 0) {
            Add-HealthCheckResult -Category "IIS Configuration" -Check "IIS Application Pools" -Status "PASS" -Message "Found $($sysInfo.IIS.ApplicationPools.Count) IIS application pools"
        } else {
            Add-HealthCheckResult -Category "IIS Configuration" -Check "IIS Application Pools" -Status "WARNING" -Message "No IIS application pools found"
        }
    }
}

function Test-DatabaseConnectivity {
    <#
    .SYNOPSIS
        Tests database connectivity
    #>
    [CmdletBinding()]
    param()

    Write-Verbose "Testing database connectivity..."
    
    

    # Test ESS database connectivity for all instances
    if ($global:DetectionResults -and $global:DetectionResults.ESSInstances.Count -gt 0) {
        foreach ($essInstance in $global:DetectionResults.ESSInstances) {
            if ($essInstance.DatabaseServer) {
                try {
                    $connectionString = "Server=$($essInstance.DatabaseServer);Database=$($essInstance.DatabaseName);Integrated Security=true;Connection Timeout=30"
                    $connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
                    $connection.Open()
                    $connection.Close()
                    Add-HealthCheckResult -Category "Database Connectivity" -Check "ESS - PG Database Connection" -Status "PASS" -Message "Successfully connected to PG database: $($essInstance.DatabaseServer) - $($essInstance.DatabaseName)"
                }
                catch {
                    Add-HealthCheckResult -Category "Database Connectivity" -Check "ESS - PG Database Connection" -Status "FAIL" -Message "Failed to connect to PG database: $($essInstance.DatabaseServer) - $($essInstance.DatabaseName). Error: $($_.Exception.Message)"
                }
            }
        }
    }
    
    # Test WFE database connectivity for all instances
    if ($global:DetectionResults -and $global:DetectionResults.WFEInstances.Count -gt 0) {
        foreach ($wfeInstance in $global:DetectionResults.WFEInstances) {
            if ($wfeInstance.DatabaseServer) {
                try {
                    $connectionString = "Server=$($wfeInstance.DatabaseServer);Database=$($wfeInstance.DatabaseName);Integrated Security=true;Connection Timeout=30"
                    $connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
                    $connection.Open()
                    $connection.Close()
                    Add-HealthCheckResult -Category "Database Connectivity" -Check "WFE - PG Database Connection" -Status "PASS" -Message "Successfully connected to PG database: $($wfeInstance.DatabaseServer) - $($wfeInstance.DatabaseName)"
                }
                catch {
                    Add-HealthCheckResult -Category "Database Connectivity" -Check "WFE - PG Database Connection" -Status "FAIL" -Message "Failed to connect to PG database: $($wfeInstance.DatabaseServer) - $($wfeInstance.DatabaseName). Error: $($_.Exception.Message)"
                }
            }
        }
    }
}

function Test-NetworkConnectivity {
    <#
    .SYNOPSIS
        Tests network connectivity
    #>
    [CmdletBinding()]
    param()

    Write-Verbose "Testing network connectivity..."
    
    $sysInfo = $global:SystemInfo
    
    # Test basic network connectivity
    try {
        $pingResult = Test-Connection -ComputerName "8.8.8.8" -Count 1 -Quiet
        if ($pingResult) {
            Add-HealthCheckResult -Category "Network Connectivity" -Check "Internet Connectivity" -Status "PASS" -Message "Internet connectivity confirmed"
        } else {
            Add-HealthCheckResult -Category "Network Connectivity" -Check "Internet Connectivity" -Status "FAIL" -Message "No internet connectivity detected"
        }
    }
    catch {
        Add-HealthCheckResult -Category "Network Connectivity" -Check "Internet Connectivity" -Status "WARNING" -Message "Could not test internet connectivity"
    }
    
    # Test network adapters
    if ($sysInfo.Network.NetworkAdapters -and $sysInfo.Network.NetworkAdapters.Count -gt 0) {
        $activeAdapters = $sysInfo.Network.NetworkAdapters | Where-Object { $_.Status -eq 'Up' }
        if ($activeAdapters.Count -gt 0) {
            Add-HealthCheckResult -Category "Network Connectivity" -Check "Network Adapters" -Status "PASS" -Message "Found $($activeAdapters.Count) active network adapters"
        } else {
            Add-HealthCheckResult -Category "Network Connectivity" -Check "Network Adapters" -Status "FAIL" -Message "No active network adapters found"
        }
    } else {
        Add-HealthCheckResult -Category "Network Connectivity" -Check "Network Adapters" -Status "WARNING" -Message "Could not retrieve network adapter information"
    }
}

function Test-SecurityPermissions {
    <#
    .SYNOPSIS
        Tests security permissions
    #>
    [CmdletBinding()]
    param()

    Write-Verbose "Testing security permissions..."
    
    $sysInfo = $global:SystemInfo
    
    # Test if running as administrator
    if ($sysInfo.IsElevated) {
        Add-HealthCheckResult -Category "Security Permissions" -Check "Administrator Rights" -Status "PASS" -Message "Script is running with administrator privileges"
    } else {
        Add-HealthCheckResult -Category "Security Permissions" -Check "Administrator Rights" -Status "WARNING" -Message "Script is not running with administrator privileges. Some checks may fail."
    }
    
    # Test file system permissions
    $testPath = $env:TEMP
    try {
        $testFile = Join-Path $testPath "ESSHealthCheckTest.tmp"
        "Test" | Out-File -FilePath $testFile -ErrorAction Stop
        Remove-Item $testFile -ErrorAction SilentlyContinue
        Add-HealthCheckResult -Category "Security Permissions" -Check "File System Access" -Status "PASS" -Message "File system access confirmed"
    }
    catch {
        Add-HealthCheckResult -Category "Security Permissions" -Check "File System Access" -Status "FAIL" -Message "File system access denied"
    }
} 