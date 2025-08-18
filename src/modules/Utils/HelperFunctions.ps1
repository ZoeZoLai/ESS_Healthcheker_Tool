<#
.SYNOPSIS
    Helper functions and utilities module
.DESCRIPTION
    Contains utility functions used across the ESS Health Checker application
.NOTES
    Author: Zoe Lai
    Date: 07/08/2025
    Version: 1.0
#>

function Get-FormattedSiteIdentifier {
    <#
    .SYNOPSIS
        Formats site name with application alias for consistent display
    .DESCRIPTION
        Creates a consistent site identifier format for use in reports and health check messages
    .PARAMETER SiteName
        The IIS site name
    .PARAMETER ApplicationPath
        The application path/alias
    .RETURNS
        Formatted site identifier string
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SiteName,
        
        [Parameter(Mandatory = $false)]
        [string]$ApplicationPath = $null
    )
    
    if ($ApplicationPath -and $ApplicationPath -ne "/") {
        return "$SiteName - $($ApplicationPath.TrimStart('/'))"
    } else {
        return $SiteName
    }
}

function Get-AppPoolIdentity {
    <#
    .SYNOPSIS
        Get application pool identity information.
    .DESCRIPTION
        Retrieves the identity type and username for a specific application pool.
    .PARAMETER AppPoolName
        Name of the application pool to get identity information for.
    .RETURNS
        String containing the identity information.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$AppPoolName
    )
    
    if (-not (Test-SystemInfoAvailability)) {
        return "Unknown"
    }
    
    if ($global:SystemInfo.IIS.ApplicationPools) {
        $appPool = $global:SystemInfo.IIS.ApplicationPools | Where-Object { $_.Name -eq $AppPoolName }
        if ($appPool) {
            $identityType = $appPool.ProcessModel.IdentityType
            $userName = $appPool.ProcessModel.UserName
            
            if ($identityType -eq "SpecificUser" -and $userName) {
                return "$identityType ($userName)"
            } else {
                return $identityType
            }
        }
    }
    return "Unknown"
}

function Test-SystemInfoAvailability {
    <#
    .SYNOPSIS
        Test if system information is available.
    .DESCRIPTION
        Checks if the global SystemInfo variable is populated.
    .RETURNS
        Boolean indicating availability of system information.
    #>
    [CmdletBinding()]
    param ()

    if ($null -eq $global:SystemInfo) {
        Write-Warning "System information is not available. Please run Get-SystemInformation first."
        return $false
    }

    return $true
}

function Get-InstanceAlias {
    <#
    .SYNOPSIS
        Gets the IIS application alias from the application path
    .DESCRIPTION
        Extracts the IIS application alias from the application path
    .PARAMETER SiteName
        IIS site name
    .PARAMETER ApplicationPath
        Application path
    .PARAMETER Type
        Instance type (ESS or WFE) - not used, kept for compatibility
    .RETURNS
        IIS application alias
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SiteName,
        
        [Parameter(Mandatory = $true)]
        [string]$ApplicationPath,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet("ESS", "WFE")]
        [string]$Type
    )

    try {
        # Extract the last part of the application path (the actual IIS application alias)
        $appPathParts = $ApplicationPath -split "/" | Where-Object { $_ -ne "" }
        $instanceName = $appPathParts[-1]  # Get the last part
        
        # If no meaningful instance name, use a default
        if (-not $instanceName -or $instanceName -eq "Self-Service") {
            $instanceName = "Default"
        }
        
        # Simply return the IIS application alias
        return $instanceName
    }
    catch {
        return "Unknown"
    }
} 