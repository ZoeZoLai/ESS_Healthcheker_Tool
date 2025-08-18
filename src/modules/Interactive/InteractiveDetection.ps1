<#
.SYNOPSIS
    Interactive detection module for user-driven instance selection
.DESCRIPTION
    Handles user input for selecting specific ESS/WFE instances and providing custom URLs
.NOTES
    Author: Zoe Lai
    Date: 13/08/2025
    Version: 1.0
#>

function Get-UserInstanceSelection {
    <#
    .SYNOPSIS
        Gets user input for selecting specific instances to check
    .DESCRIPTION
        Presents available instances and allows user to select which ones to validate
    .RETURNS
        Array of selected instances with user-provided information
    #>
    [CmdletBinding()]
    param()

    try {
        Write-Host "=== Instance Selection ===" -ForegroundColor Magenta
        Write-Host ""

        # Get available instances from IIS
        $availableInstances = Get-AvailableInstances
        
        if (-not $availableInstances -or $availableInstances.Count -eq 0) {
            Write-Host "[FAIL] No IIS applications found that could be ESS/WFE instances." -ForegroundColor Red
            Write-Host "   Please ensure IIS is properly configured and applications are deployed." -ForegroundColor Yellow
            return @()
        }

        # Display available instances
        Write-Host "Available IIS Applications:" -ForegroundColor Cyan
        Write-Host ""
        
        for ($i = 0; $i -lt $availableInstances.Count; $i++) {
            $instance = $availableInstances[$i]
            $index = $i + 1
            Write-Host "$index. Site: $($instance.SiteName)" -ForegroundColor White
            Write-Host "   Application: $($instance.ApplicationPath)" -ForegroundColor Gray
            Write-Host "   Pool: $($instance.ApplicationPool)" -ForegroundColor Gray
            Write-Host "   Physical Path: $($instance.PhysicalPath)" -ForegroundColor Gray
            Write-Host ""
        }

        # Get user selection
        Write-Host "Select instances to check (comma-separated numbers, e.g., 1,3):" -ForegroundColor Yellow
        $selection = Read-Host "Enter selection"
        
        $selectedIndices = $selection -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^\d+$' }
        
        if (-not $selectedIndices -or $selectedIndices.Count -eq 0) {
            Write-Host "[FAIL] No valid selections made." -ForegroundColor Red
            return @()
        }

        $selectedInstances = @()
        
        foreach ($index in $selectedIndices) {
            $instanceIndex = [int]$index - 1
            if ($instanceIndex -ge 0 -and $instanceIndex -lt $availableInstances.Count) {
                $instance = $availableInstances[$instanceIndex]
                
                # Get additional user input for this instance
                $enhancedInstance = Get-InstanceDetails -Instance $instance
                $selectedInstances += $enhancedInstance
            }
        }

        Write-Host ""
        Write-Host "[OK] Selected $($selectedInstances.Count) instance(s) for health check." -ForegroundColor Green
        
        return $selectedInstances
    }
    catch {
        Write-Error "Error during instance selection: $_"
        return @()
    }
}

function Get-AvailableInstances {
    <#
    .SYNOPSIS
        Gets all available IIS applications that could be ESS/WFE instances
    .DESCRIPTION
        Scans IIS for applications and filters potential ESS/WFE instances
    .RETURNS
        Array of potential ESS/WFE instances
    #>
    [CmdletBinding()]
    param()

    try {
        $instances = @()
        
        # Import IIS modules if available
        try {
            Import-Module WebAdministration -ErrorAction SilentlyContinue
            Import-Module IISAdministration -ErrorAction SilentlyContinue
        }
        catch {
            Write-Verbose "Could not import IIS modules"
        }

        # Get all IIS sites
        $sites = @()
        try {
            if (Get-Command "Get-IISSite" -ErrorAction SilentlyContinue) {
                $sites = Get-IISSite -ErrorAction SilentlyContinue
            }
            elseif (Get-Command "Get-Website" -ErrorAction SilentlyContinue) {
                $sites = Get-Website -ErrorAction SilentlyContinue
            }
        }
        catch {
            Write-Warning "Could not retrieve IIS sites: $_"
            return @()
        }

        Write-Host "Found $($sites.Count) IIS site(s)" -ForegroundColor Gray

        foreach ($site in $sites) {
            Write-Host "Processing site: $($site.Name)" -ForegroundColor Gray
            
            # Get all applications in this site using multiple methods
            $siteApplications = @()
            try {
                if (Get-Command "Get-IISApplication" -ErrorAction SilentlyContinue) {
                    $siteApplications = Get-IISSite -Name $site.Name | Get-IISApplication -ErrorAction SilentlyContinue
                }
                elseif (Get-Command "Get-WebApplication" -ErrorAction SilentlyContinue) {
                    $siteApplications = Get-WebApplication -Site $site.Name -ErrorAction SilentlyContinue
                }
            }
            catch {
                Write-Verbose "Could not get applications for site $($site.Name): $_"
            }

            Write-Host "Found $($siteApplications.Count) application(s) in site $($site.Name)" -ForegroundColor Gray

            # Check both site root and applications within the site
            $allPathsToCheck = @()
            
            # Add site root path
            if ($site.PhysicalPath) {
                $allPathsToCheck += @{
                    Path = $site.PhysicalPath
                    ApplicationPath = "/"
                    ApplicationPool = $site.ApplicationPool
                    IsRoot = $true
                }
            }
            
            # Add application paths
            foreach ($app in $siteApplications) {
                if ($app.PhysicalPath) {
                    $allPathsToCheck += @{
                        Path = $app.PhysicalPath
                        ApplicationPath = $app.Path
                        ApplicationPool = $app.ApplicationPool
                        IsRoot = $false
                    }
                }
            }
            
            # Process each path
            foreach ($pathInfo in $allPathsToCheck) {
                $instance = @{
                    SiteName = $site.Name
                    ApplicationPath = $pathInfo.ApplicationPath
                    ApplicationPool = $pathInfo.ApplicationPool
                    PhysicalPath = $pathInfo.Path
                    InstanceType = "Unknown"
                    Alias = ""
                }

                # Try to determine instance type based on application path and physical path
                $appPath = $instance.ApplicationPath
                $physicalPath = $instance.PhysicalPath
                
                # More specific detection logic
                if ($appPath -like "*WFE*" -or $appPath -like "*Workflow*" -or $physicalPath -like "*WFE*" -or $physicalPath -like "*Workflow*") {
                    $instance.InstanceType = "WFE"
                    $instance.Alias = Get-InstanceAlias -SiteName $site.Name -ApplicationPath $instance.ApplicationPath -Type "WFE"
                }
                elseif ($appPath -like "*ESS*" -or $physicalPath -like "*ESS*") {
                    $instance.InstanceType = "ESS"
                    $instance.Alias = Get-InstanceAlias -SiteName $site.Name -ApplicationPath $instance.ApplicationPath -Type "ESS"
                }
                # If still unknown, check for Self-Service pattern (usually ESS)
                elseif ($appPath -like "*Self-Service*" -or $physicalPath -like "*Self-Service*") {
                    $instance.InstanceType = "ESS"
                    $instance.Alias = Get-InstanceAlias -SiteName $site.Name -ApplicationPath $instance.ApplicationPath -Type "ESS"
                }

                # Always add the instance, even if type is unknown
                $instances += [PSCustomObject]$instance
            }
        }

        Write-Host "Total instances found: $($instances.Count)" -ForegroundColor Gray
        return $instances
    }
    catch {
        Write-Error "Error getting available instances: $_"
        return @()
    }
}





function Get-InstanceDetails {
    <#
    .SYNOPSIS
        Gets additional details from user for a specific instance
    .DESCRIPTION
        Prompts user for ESS site URL and other instance-specific information
    .PARAMETER Instance
        Instance object to enhance with user input
    .RETURNS
        Enhanced instance object with user input
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Instance
    )

    try {
        Write-Host ""
        Write-Host "=== Instance Details: $($Instance.SiteName)$($Instance.ApplicationPath) ===" -ForegroundColor Cyan
        Write-Host "Type: $($Instance.InstanceType)" -ForegroundColor White
        Write-Host "Alias: $($Instance.Alias)" -ForegroundColor White
        Write-Host ""

        # Get ESS site URL only for ESS instances
        $essSiteUrl = ""
        if ($Instance.InstanceType -eq "ESS") {
            Write-Host "For ESS instances, please provide the ESS site URL for API health checks." -ForegroundColor Yellow
            Write-Host "Example: https://ess.company.com or http://localhost/Self-Service/NZ_ESS" -ForegroundColor Gray
            Write-Host ""
            
            do {
                $essSiteUrl = Read-Host "Enter ESS site URL (or press Enter to skip)"
                
                if ($essSiteUrl -eq "") {
                    Write-Host "[WARN] Skipping API health checks for this ESS instance." -ForegroundColor Yellow
                    break
                }
                
                # Basic URL validation
                if ($essSiteUrl -match '^https?://') {
                    break
                } else {
                    Write-Host "[FAIL] Invalid URL format. Please include http:// or https://" -ForegroundColor Red
                }
            } while ($true)
        }
        elseif ($Instance.InstanceType -eq "WFE") {
            Write-Host "WFE instances do not require API endpoint testing." -ForegroundColor Gray
        }
        elseif ($Instance.InstanceType -eq "Unknown") {
            Write-Host "Instance type could not be automatically determined." -ForegroundColor Yellow
            Write-Host "Based on the application path, this might be an ESS instance." -ForegroundColor Gray
            Write-Host ""
            
            $confirmESS = Read-Host "Is this an ESS instance? (y/n)"
            if ($confirmESS -match '^[Yy]') {
                $Instance.InstanceType = "ESS"
                $Instance.Alias = Get-InstanceAlias -SiteName $Instance.SiteName -ApplicationPath $Instance.ApplicationPath -Type "ESS"
                
                # Now ask for ESS site URL
                Write-Host "For ESS instances, please provide the ESS site URL for API health checks." -ForegroundColor Yellow
                Write-Host "Example: https://ess.company.com or http://localhost/Self-Service/NZ_ESS" -ForegroundColor Gray
                Write-Host ""
                
                do {
                    $essSiteUrl = Read-Host "Enter ESS site URL (or press Enter to skip)"
                    
                    if ($essSiteUrl -eq "") {
                        Write-Host "[WARN] Skipping API health checks for this ESS instance." -ForegroundColor Yellow
                        break
                    }
                    
                    # Basic URL validation
                    if ($essSiteUrl -match '^https?://') {
                        break
                    } else {
                        Write-Host "[FAIL] Invalid URL format. Please include http:// or https://" -ForegroundColor Red
                    }
                } while ($true)
            }
        }

        # Create enhanced instance object
        $enhancedInstance = [PSCustomObject]@{
            SiteName = $Instance.SiteName
            ApplicationPath = $Instance.ApplicationPath
            ApplicationPool = $Instance.ApplicationPool
            PhysicalPath = $Instance.PhysicalPath
            InstanceType = $Instance.InstanceType
            Alias = $Instance.Alias
            ESSSiteUrl = $essSiteUrl
            UserSelected = $true
        }

        return $enhancedInstance
    }
    catch {
        Write-Error "Error getting instance details: $_"
        return $Instance
    }
}
