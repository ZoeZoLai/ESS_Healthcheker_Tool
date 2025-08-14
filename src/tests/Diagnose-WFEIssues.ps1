<#
.SYNOPSIS
    Diagnostic script for WFE detection and API health check issues
.DESCRIPTION
    Helps identify why WFE detection might fail on Windows Server 2019
    and why API health checks might return no results
.NOTES
    Author: Zoe Lai
    Date: 15/08/2025
    Version: 1.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$FixIssues
)

# Import required modules
$modulePaths = @(
    "src\modules\Detection\WFEDetection.ps1",
    "src\modules\Detection\ESSDetection.ps1",
    "src\modules\Detection\ESSHealthCheckAPI.ps1"
)

foreach ($modulePath in $modulePaths) {
    $fullPath = Join-Path $PSScriptRoot "..\$modulePath"
    if (Test-Path $fullPath) {
        . $fullPath
        Write-Host "Loaded module: $modulePath" -ForegroundColor Green
    } else {
        Write-Warning "Module not found: $fullPath"
    }
}

Write-Host "=== WFE Detection and API Health Check Diagnostics ===" -ForegroundColor Yellow
Write-Host "Date: $(Get-Date)" -ForegroundColor Gray
Write-Host "Computer: $env:COMPUTERNAME" -ForegroundColor Gray
Write-Host "OS: $((Get-WmiObject -Class Win32_OperatingSystem).Caption)" -ForegroundColor Gray
Write-Host ""

# Test 1: IIS Installation Check
Write-Host "=== Test 1: IIS Installation Check ===" -ForegroundColor Cyan
try {
    $iisInstalled = $false
    
    # Method 1: Windows Feature
    try {
        if (Get-Command "Get-WindowsFeature" -ErrorAction SilentlyContinue) {
            $webServerFeature = Get-WindowsFeature -Name "Web-Server" -ErrorAction SilentlyContinue
            $iisInstalled = $webServerFeature -and $webServerFeature.InstallState -eq "Installed"
            Write-Host "Windows Feature Check: $($webServerFeature.InstallState)" -ForegroundColor $(if($iisInstalled){"Green"}else{"Red"})
        } else {
            Write-Host "Windows Feature Check: Get-WindowsFeature not available" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "Windows Feature Check: Error - $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Method 2: Registry
    try {
        $iisRegKey = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\InetStp" -ErrorAction SilentlyContinue
        $iisInstalled = $iisInstalled -or ($null -ne $iisRegKey)
        Write-Host "Registry Check: $($(if($iisRegKey){"Found"}else{"Not Found"}))" -ForegroundColor $(if($iisRegKey){"Green"}else{"Red"})
    }
    catch {
        Write-Host "Registry Check: Error - $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Method 3: Service
    try {
        $w3svcService = Get-Service -Name "W3SVC" -ErrorAction SilentlyContinue
        $iisInstalled = $iisInstalled -or ($w3svcService -and $w3svcService.Status -eq "Running")
        Write-Host "Service Check: $($w3svcService.Status)" -ForegroundColor $(if($w3svcService -and $w3svcService.Status -eq "Running"){"Green"}else{"Red"})
    }
    catch {
        Write-Host "Service Check: Error - $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host "IIS Installation Status: $($(if($iisInstalled){"Installed"}else{"Not Installed"}))" -ForegroundColor $(if($iisInstalled){"Green"}else{"Red"})
}
catch {
    Write-Host "IIS Check Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test 2: IIS Module Availability
Write-Host "=== Test 2: IIS Module Availability ===" -ForegroundColor Cyan
try {
    $modules = @("WebAdministration", "IISAdministration")
    foreach ($module in $modules) {
        try {
            Import-Module $module -ErrorAction Stop
            Write-Host "${module}: Available" -ForegroundColor Green
        }
        catch {
            Write-Host "${module}: Not Available - $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}
catch {
    Write-Host "Module Check Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test 3: IIS Sites Discovery
Write-Host "=== Test 3: IIS Sites Discovery ===" -ForegroundColor Cyan
try {
    $sites = @()
    
    # Try Get-IISSite
    try {
        if (Get-Command "Get-IISSite" -ErrorAction SilentlyContinue) {
            $sites = Get-IISSite -ErrorAction SilentlyContinue
            Write-Host "Get-IISSite: Found $($sites.Count) sites" -ForegroundColor Green
        } else {
            Write-Host "Get-IISSite: Command not available" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "Get-IISSite: Error - $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Try Get-Website as fallback
    if ($sites.Count -eq 0) {
        try {
            if (Get-Command "Get-Website" -ErrorAction SilentlyContinue) {
                $sites = Get-Website -ErrorAction SilentlyContinue
                Write-Host "Get-Website: Found $($sites.Count) sites" -ForegroundColor Green
            } else {
                Write-Host "Get-Website: Command not available" -ForegroundColor Yellow
            }
        }
        catch {
            Write-Host "Get-Website: Error - $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    # Display site details
    if ($sites.Count -gt 0) {
        Write-Host "`nSite Details:" -ForegroundColor Gray
        foreach ($site in $sites) {
            Write-Host "  Site: $($site.Name)" -ForegroundColor White
            Write-Host "    Physical Path: $($site.PhysicalPath)" -ForegroundColor Gray
            Write-Host "    Application Pool: $($site.ApplicationPool)" -ForegroundColor Gray
            Write-Host "    State: $($site.State)" -ForegroundColor Gray
            Write-Host ""
        }
    } else {
        Write-Host "No IIS sites found" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "Sites Discovery Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test 4: WFE Detection
Write-Host "=== Test 4: WFE Detection ===" -ForegroundColor Cyan
try {
    $wfeResult = Test-WFEInstallation
    Write-Host "WFE Installation Check:" -ForegroundColor White
    Write-Host "  Installed: $($wfeResult.Installed)" -ForegroundColor $(if($wfeResult.Installed){"Green"}else{"Red"})
    Write-Host "  Install Path: $($wfeResult.InstallPath)" -ForegroundColor Gray
    Write-Host "  Site Name: $($wfeResult.SiteName)" -ForegroundColor Gray
    Write-Host "  Application Path: $($wfeResult.ApplicationPath)" -ForegroundColor Gray
    
    if ($wfeResult.Installed) {
        Write-Host "  Database Server: $($wfeResult.DatabaseServer)" -ForegroundColor Gray
        Write-Host "  Database Name: $($wfeResult.DatabaseName)" -ForegroundColor Gray
        Write-Host "  Tenant ID: $($wfeResult.TenantId)" -ForegroundColor Gray
    }
}
catch {
    Write-Host "WFE Detection Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test 5: WFE Instances Discovery
Write-Host "=== Test 5: WFE Instances Discovery ===" -ForegroundColor Cyan
try {
    $wfeInstances = Find-WFEInstances
    Write-Host "WFE Instances Found: $($wfeInstances.Count)" -ForegroundColor $(if($wfeInstances.Count -gt 0){"Green"}else{"Yellow"})
    
    foreach ($instance in $wfeInstances) {
        Write-Host "  Instance: $($instance.SiteName)$($instance.ApplicationPath)" -ForegroundColor White
        Write-Host "    Physical Path: $($instance.PhysicalPath)" -ForegroundColor Gray
        Write-Host "    Database: $($instance.DatabaseServer)/$($instance.DatabaseName)" -ForegroundColor Gray
        Write-Host "    Tenant ID: $($instance.TenantID)" -ForegroundColor Gray
        Write-Host ""
    }
}
catch {
    Write-Host "WFE Instances Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test 6: ESS Detection
Write-Host "=== Test 6: ESS Detection ===" -ForegroundColor Cyan
try {
    $essInstances = Find-ESSInstances
    Write-Host "ESS Instances Found: $($essInstances.Count)" -ForegroundColor $(if($essInstances.Count -gt 0){"Green"}else{"Yellow"})
    
    foreach ($instance in $essInstances) {
        Write-Host "  Instance: $($instance.SiteName)$($instance.ApplicationPath)" -ForegroundColor White
        Write-Host "    Physical Path: $($instance.PhysicalPath)" -ForegroundColor Gray
        Write-Host "    Database: $($instance.DatabaseServer)/$($instance.DatabaseName)" -ForegroundColor Gray
        Write-Host "    Tenant ID: $($instance.TenantID)" -ForegroundColor Gray
        Write-Host ""
    }
}
catch {
    Write-Host "ESS Detection Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test 7: API Health Check
Write-Host "=== Test 7: API Health Check ===" -ForegroundColor Cyan
try {
    if ($essInstances.Count -gt 0) {
        $firstInstance = $essInstances[0]
        Write-Host "Testing API health check for: $($firstInstance.SiteName)$($firstInstance.ApplicationPath)" -ForegroundColor White
        
        $healthCheck = Get-ESSHealthCheckViaAPI -SiteName $firstInstance.SiteName -ApplicationPath $firstInstance.ApplicationPath
        
        Write-Host "API Health Check Results:" -ForegroundColor White
        Write-Host "  URI: $($healthCheck.Uri)" -ForegroundColor Gray
        Write-Host "  Status Code: $($healthCheck.StatusCode)" -ForegroundColor Gray
        Write-Host "  Success: $($healthCheck.Success)" -ForegroundColor $(if($healthCheck.Success){"Green"}else{"Red"})
        Write-Host "  Overall Status: $($healthCheck.OverallStatus)" -ForegroundColor Gray
        Write-Host "  Components: $($healthCheck.Summary.TotalComponents) total, $($healthCheck.Summary.HealthyComponents) healthy" -ForegroundColor Gray
        
        if ($healthCheck.Error) {
            Write-Host "  Error: $($healthCheck.Error)" -ForegroundColor Red
        }
        
        if ($healthCheck.Components.Count -gt 0) {
            Write-Host "  Component Details:" -ForegroundColor Gray
            foreach ($component in $healthCheck.Components) {
                $statusColor = if ($component.Status -eq "Healthy") { "Green" } else { "Red" }
                Write-Host "    $($component.Name): $($component.Status) (v$($component.Version))" -ForegroundColor $statusColor
            }
        }
    } else {
        Write-Host "No ESS instances found for API health check" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "API Health Check Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test 8: File System Access
Write-Host "=== Test 8: File System Access ===" -ForegroundColor Cyan
try {
    $testPaths = @(
        "C:\inetpub\wwwroot",
        "C:\Program Files\Common Files\Microsoft Shared\Web Server Extensions",
        "C:\Windows\System32\inetsrv"
    )
    
    foreach ($path in $testPaths) {
        if (Test-Path $path) {
            Write-Host "${path}: Accessible" -ForegroundColor Green
        } else {
            Write-Host "${path}: Not accessible" -ForegroundColor Red
        }
    }
}
catch {
    Write-Host "File System Access Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test 9: Permissions Check
Write-Host "=== Test 9: Permissions Check ===" -ForegroundColor Cyan
try {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    Write-Host "Running as Administrator: $isAdmin" -ForegroundColor $(if($isAdmin){"Green"}else{"Red"})
    
    # Test IIS configuration access
    try {
        $iisConfig = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\InetStp" -ErrorAction Stop
        Write-Host "IIS Configuration Access: Granted" -ForegroundColor Green
    }
    catch {
        Write-Host "IIS Configuration Access: Denied - $($_.Exception.Message)" -ForegroundColor Red
    }
}
catch {
    Write-Host "Permissions Check Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Summary and Recommendations
Write-Host "=== Summary and Recommendations ===" -ForegroundColor Yellow

$issues = @()

# Check for common issues
if (-not $iisInstalled) {
    $issues += "IIS is not installed or not properly detected"
}

if ($essInstances.Count -eq 0) {
    $issues += "No ESS instances found - check IIS configuration and file paths"
}

if ($wfeInstances.Count -eq 0) {
    $issues += "No WFE instances found - check for tenants.config files"
}

if (-not $isAdmin) {
    $issues += "Script is not running with administrator privileges"
}

if ($issues.Count -gt 0) {
    Write-Host "Issues Found:" -ForegroundColor Red
    foreach ($issue in $issues) {
        Write-Host "  - $issue" -ForegroundColor Red
    }
    
    Write-Host "`nRecommendations:" -ForegroundColor Cyan
    foreach ($issue in $issues) {
        switch -Wildcard ($issue) {
            "*IIS*" {
                Write-Host "  - Install IIS using: Install-WindowsFeature -Name Web-Server" -ForegroundColor White
            }
            "*ESS*" {
                Write-Host "  - Verify ESS installation paths and web.config files" -ForegroundColor White
                Write-Host "  - Check IIS application pool status" -ForegroundColor White
            }
            "*WFE*" {
                Write-Host "  - Verify WFE installation and tenants.config files" -ForegroundColor White
                Write-Host "  - Check IIS site and application configuration" -ForegroundColor White
            }
            "*Administrator*" {
                Write-Host "  - Run PowerShell as Administrator" -ForegroundColor White
            }
        }
    }
} else {
    Write-Host "No major issues detected" -ForegroundColor Green
}

Write-Host "`nDiagnostic completed at: $(Get-Date)" -ForegroundColor Gray
