<#
.SYNOPSIS
    System information collection orchestrator
.DESCRIPTION
    Coordinates collection of all system information including OS, hardware, IIS, SQL Server, and registry
.NOTES
    Author: Zoe Lai
    Date: 04/08/2025
    Version: 1.0
#>

# Global variable to store system information
$global:SystemInfo = $null

function Get-SystemInformation {
    <#
    .SYNOPSIS
        Gathers system information for the ESS Health Checker.
    .DESCRIPTION
        Collects detailed system information including OS version, hardware, IIS, database connections,
        and more for use in configuration and health checks.
    .RETURNS
        PSCustomObject containing system information.
    #>
    
    [CmdletBinding()]
    param ()

    # Retrieve system information
    try {
        Write-Verbose "Gathering system information..."

        $systemInfo = @{
            
            # Basic system information
            ComputerName = $env:COMPUTERNAME
            Domain = $env:USERDOMAIN
            UserName = $env:USERNAME
            IsElevated = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
            
            # Get OS information
            OS = Get-OSInformation

            # Get hardware information
            Hardware = Get-HardwareInformation

            # Get network information
            Network = Get-NetworkInformation

            # Get IIS information
            IIS = Get-IISInformation

            # Get registry information for .NET versions
            Registry = Get-RegistryInformation

            # Get SQL Server information
            SQLServer = Get-SQLServerInformation

            # Remove ESS and WFE from initial system info structure
            DeploymentStructure = $null  # Will be populated later when detection results are available

            # Timestamp
            CollectedAt = Get-Date

        }

        # ESS and WFE information will be populated later after detection results are available
        $systemInfo.ESS = @{ Installed = $false }
        $systemInfo.WFE = @{ Installed = $false }

        $global:SystemInfo = [PSCustomObject]$systemInfo
        return $global:SystemInfo
    }
    catch {
        Write-Error "Failed to gather system information: $_"
        throw
    }
}


function Get-SystemInfoValue {
    <#
    .SYNOPSIS
        Get a specific value from the system information.
    .PARAMETER path
        Dot notation path to the value (e.g., "OS.Version", "Hardware.TotalPhysicalMemory").
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    if (-not (Test-SystemInfoAvailability)) {
        return $null
    }

    try {
        $value = $global:SystemInfo
        $pathParts = $Path.Split('.')

        foreach ($part in $pathParts) {
            $value = $value.$part
            if ($null -eq $value) {
                Write-Warning "Value not found for path '$Path'."
                return $null
            }
        }
        return $value
    }
    catch {
        Write-Warning "Could not retrieve system info value for path '$Path': $_"
        return $null
    }
} 