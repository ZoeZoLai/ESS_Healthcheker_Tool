<#
.SYNOPSIS
    ESS/WFE detection orchestrator
.DESCRIPTION
    Coordinates detection of ESS and WFE installations and determines deployment structure
.NOTES
    Author: Zoe Lai
    Date: 04/08/2025
    Version: 1.0
#>

function Get-ESSWFEDetection {
    <#
    .SYNOPSIS
        ESS/WFE detection of ESS web server and Workflow Engine installations
    .DESCRIPTION
        Performs checks for ESS and WFE installations following the specified logic:
        1. Check if IIS is installed
        2. If IIS installed, check for ESS installations
        3. If IIS installed, check for WFE installations
        4. Determine deployment type
        5. List all instances found
    .RETURNS
        PSCustomObject containing ESS/WFE detection results
    #>
    [CmdletBinding()]
    param()

    try {
        Write-Host "Running ESS/WFE detection..." -ForegroundColor Yellow
        
        $results = @{
            IISInstalled = $false
            ESSInstances = @()
            WFEInstances = @()
            DeploymentType = "None"
            Summary = @()
        }

        # Step 1: Check if IIS is installed
        Write-Host "Step 1: Checking IIS installation..." -ForegroundColor Cyan
        $iisInstalled = Test-IISInstallation
        $results.IISInstalled = $iisInstalled
        
        if ($iisInstalled) {
            $results.Summary += "[PASS] IIS is installed on this machine"
            Write-Host "[PASS] IIS is installed" -ForegroundColor Green
        } else {
            $results.Summary += "[FAIL] IIS is not installed - ESS and WFE require IIS"
            Write-Host "[FAIL] IIS is not installed - ESS and WFE require IIS" -ForegroundColor Red
            $results.DeploymentType = "None"
            return [PSCustomObject]$results
        }

        # Step 2: Check for ESS installations
        Write-Host "Step 2: Checking for ESS installations..." -ForegroundColor Cyan
        $essInstances = Find-ESSInstances
        $results.ESSInstances = $essInstances
        
        if ($essInstances.Count -gt 0) {
            Write-Host "[PASS] Found $($essInstances.Count) ESS installation(s)" -ForegroundColor Green
            foreach ($ess in $essInstances) {
                $results.Summary += "[PASS] ESS installed: $($ess.SiteName) - Pool: $($ess.ApplicationPool) - DB: $($ess.DatabaseServer)/$($ess.DatabaseName)"
            }
        } else {
            Write-Host "[INFO] No ESS installations found" -ForegroundColor Yellow
            $results.Summary += "[INFO] No ESS installations found"
        }

        # Step 3: Check for WFE installations
        Write-Host "Step 3: Checking for WFE installations..." -ForegroundColor Cyan
        $wfeInstances = Find-WFEInstances
        $results.WFEInstances = $wfeInstances
        
        # Handle PowerShell's behavior where single objects aren't arrays
        if ($wfeInstances -is [array]) {
            $wfeInstanceCount = $wfeInstances.Count
        } else {
            $wfeInstanceCount = if ($null -ne $wfeInstances) { 1 } else { 0 }
        }
        
        if ($wfeInstanceCount -gt 0) {
            Write-Host "[PASS] Found $wfeInstanceCount WFE installation(s)" -ForegroundColor Green
            
            # Handle single object vs array for iteration
            if ($wfeInstances -is [array]) {
                $wfeInstancesToProcess = $wfeInstances
            } else {
                $wfeInstancesToProcess = @($wfeInstances)
            }
            
            foreach ($wfe in $wfeInstancesToProcess) {
                $results.Summary += "[PASS] WFE installed: $($wfe.SiteName) - Pool: $($wfe.ApplicationPool) - DB: $($wfe.DatabaseServer)/$($wfe.DatabaseName)"
            }
        } else {
            Write-Host "[INFO] No WFE installations found" -ForegroundColor Yellow
            $results.Summary += "[INFO] No WFE installations found"
        }

        # Step 4: Determine deployment type
        Write-Host "Step 4: Determining deployment type..." -ForegroundColor Cyan
        
        # Get ESS instance count
        $essInstanceCount = if ($essInstances -is [array]) { $essInstances.Count } else { if ($null -ne $essInstances) { 1 } else { 0 } }
        
        if ($essInstanceCount -gt 0 -and $wfeInstanceCount -gt 0) {
            $results.DeploymentType = "Combined"
            Write-Host "[PASS] Deployment Type: Combined (ESS + WFE)" -ForegroundColor Green
        } elseif ($essInstanceCount -gt 0) {
            $results.DeploymentType = "ESS Only"
            Write-Host "[PASS] Deployment Type: ESS Only" -ForegroundColor Green
        } elseif ($wfeInstanceCount -gt 0) {
            $results.DeploymentType = "WFE Only"
            Write-Host "[PASS] Deployment Type: WFE Only" -ForegroundColor Green
        } else {
            $results.DeploymentType = "None"
            Write-Host "[INFO] Deployment Type: None" -ForegroundColor Yellow
        }

        $results.Summary += "Deployment Type: $($results.DeploymentType)"
        
        Write-Host "ESS/WFE detection completed!" -ForegroundColor Green
        return [PSCustomObject]$results
    }
    catch {
        Write-Error "Error during ESS/WFE detection: $_"
        throw
    }
}

function Test-IISInstallation {
    <#
    .SYNOPSIS
        Simple check if IIS is installed
    #>
    [CmdletBinding()]
    param()

    try {
        # Method 1: Check Windows Server features
        if (Get-Command "Get-WindowsFeature" -ErrorAction SilentlyContinue) {
            $webServerFeature = Get-WindowsFeature -Name "Web-Server" -ErrorAction SilentlyContinue
            if ($webServerFeature -and $webServerFeature.InstallState -eq "Installed") {
                return $true
            }
        }

        # Method 2: Check registry
        $iisRegKey = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\InetStp" -ErrorAction SilentlyContinue
        if ($iisRegKey) {
            return $true
        }

        # Method 3: Check service
        $w3svcService = Get-Service -Name "W3SVC" -ErrorAction SilentlyContinue
        if ($w3svcService -and $w3svcService.Status -eq "Running") {
            return $true
        }

        return $false
    }
    catch {
        Write-Warning "Error checking IIS installation: $_"
        return $false
    }
} 