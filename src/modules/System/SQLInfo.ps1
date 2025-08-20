<#
.SYNOPSIS
    SQL Server information collection module
.DESCRIPTION
    Collects detailed SQL Server information including instances, services, and versions
.NOTES
    Author: Zoe Lai
    Date: 04/08/2025
    Version: 1.0
#>

function Get-SQLServerInformation {
    <#
    .SYNOPSIS
        Get SQL Server installation information.
    .DESCRIPTION
        Detects SQL Server installations and running services.
    .RETURNS
        Object containing SQL Server information.
    #>
    
    try {
        $sqlInfo = @{
            IsInstalled = $false
            Instances = @()
            Services = @()
            Versions = @()
        }
        
        # Check for SQL Server services
        $sqlServices = Get-Service -Name "*SQL*" -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq "Running" }
        if ($sqlServices) {
            $sqlInfo.IsInstalled = $true
            $sqlInfo.Services = $sqlServices | ForEach-Object {
                @{
                    Name = $_.Name
                    DisplayName = $_.DisplayName
                    Status = $_.Status
                    StartType = $_.StartType
                }
            }
        }
        
        # Check for SQL Server instances via registry
        $sqlInstances = @()
        $sqlKeys = @(
            "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server",
            "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Microsoft SQL Server"
        )
        
        foreach ($key in $sqlKeys) {
            if (Test-Path $key) {
                try {
                    $installedInstancesPath = "$key\Instance Names\SQL"
                    if (Test-Path $installedInstancesPath) {
                        $instanceNames = Get-ItemProperty -Path $installedInstancesPath -ErrorAction SilentlyContinue
                        if ($instanceNames) {
                            foreach ($property in $instanceNames.PSObject.Properties) {
                                if ($property.Name -notlike "PS*") {
                                    $sqlInstances += $property.Name
                                }
                            }
                        }
                    }
                }
                catch {
                    Write-Verbose "Could not read SQL instances from registry: $_"
                }
            }
        }
        
        if ($sqlInstances.Count -gt 0) {
            $sqlInfo.IsInstalled = $true
            $sqlInfo.Instances = $sqlInstances
        }
        
        # Check for SQL Server versions with mapping
        $sqlVersions = @()
        $versionMapping = @{
            "160" = "SQL Server 2022"
            "150" = "SQL Server 2019"
            "140" = "SQL Server 2017"
            "130" = "SQL Server 2016"
            "120" = "SQL Server 2014"
            "110" = "SQL Server 2012"
            "100" = "SQL Server 2008/2008 R2"
            "90"  = "SQL Server 2005"
            "80"  = "SQL Server 2000"
        }
        
        $versionKeys = @(
            "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\*",
            "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Microsoft SQL Server\*"
        )
        
        foreach ($pattern in $versionKeys) {
            $keys = Get-ItemProperty -Path $pattern -ErrorAction SilentlyContinue
            foreach ($key in $keys) {
                if ($key.PSChildName -match "^\d+$") {
                    $versionNumber = $key.PSChildName
                    if ($versionMapping.ContainsKey($versionNumber)) {
                        $sqlVersions += $versionMapping[$versionNumber]
                    } else {
                        $sqlVersions += "SQL Server (Version $versionNumber)"
                    }
                }
            }
        }
        
        if ($sqlVersions.Count -gt 0) {
            $sqlInfo.Versions = $sqlVersions | Sort-Object -Unique
        }
        
        return $sqlInfo
    }
    catch {
        Write-Warning "Could not retrieve SQL Server information: $_"
        return @{
            IsInstalled = $false
            Instances = @()
            Services = @()
            Versions = @()
        }
    }
} 