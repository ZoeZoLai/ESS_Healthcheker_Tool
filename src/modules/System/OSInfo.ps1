<#
.SYNOPSIS
    Operating system information collection module
.DESCRIPTION
    Collects detailed OS information including version, type, and capabilities
.NOTES
    Author: Zoe Lai
    Date: 04/08/2025
    Version: 1.0
#>

function Get-OSInformation {
    <#
    .SYNOPSIS
        Get operating system information.
    #>
    
    try {
        $os = Get-CimInstance Win32_OperatingSystem
        $osVersion = [System.Environment]::OSVersion

        return @{
            Caption = $os.Caption
            Version = $os.Version
            BuildNumber = $os.BuildNumber
            ServicePack = $os.ServicePackMajorVersion
            TotalVisibleMemory = [Math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
            FreePhysicalMemory = [Math]::Round($os.FreePhysicalMemory / 1MB, 2)
            Platform = $osVersion.Platform
            MajorVersion = $osVersion.Version.Major
            MinorVersion = $osVersion.Version.Minor
            IsServer = $os.ProductType -eq 3
        }
    }
    catch {
        Write-Warning "Could not retrieve OS information: $_"
        return @{}
    }
}

function Get-RegistryInformation {
    <#
    .SYNOPSIS
        Get relevant registry information.
    #>
    
    try {
        $dotNetVersions = @()
        
        # Check for .NET Framework 4.x versions
        $dotNetKeys = @(
            "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full",
            "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Client"
        )
        
        foreach ($key in $dotNetKeys) {
            $version = Get-ItemProperty -Path $key -Name "Version" -ErrorAction SilentlyContinue
            if ($version) {
                $dotNetVersions += $version.Version
            }
        }
        
        # Also check for .NET Framework 3.x versions
        $dotNet3Keys = @(
            "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v3.5",
            "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v3.0"
        )
        
        foreach ($key in $dotNet3Keys) {
            $install = Get-ItemProperty -Path $key -Name "Install" -ErrorAction SilentlyContinue
            if ($install -and $install.Install -eq 1) {
                $version = Get-ItemProperty -Path $key -Name "Version" -ErrorAction SilentlyContinue
                if ($version) {
                    $dotNetVersions += $version.Version
                }
            }
        }
        
        # Check for .NET Framework 2.x
        $dotNet2Key = "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v2.0.50727"
        $install = Get-ItemProperty -Path $dotNet2Key -Name "Install" -ErrorAction SilentlyContinue
        if ($install -and $install.Install -eq 1) {
            $version = Get-ItemProperty -Path $dotNet2Key -Name "Version" -ErrorAction SilentlyContinue
            if ($version) {
                $dotNetVersions += $version.Version
            }
        }
        
        # Remove duplicates and sort
        $dotNetVersions = $dotNetVersions | Sort-Object -Unique

        return @{
            DotNetVersions = $dotNetVersions
        }
    }
    catch {
        Write-Warning "Could not retrieve registry information: $_"
        return @{}
    }
} 