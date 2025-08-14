<#
.SYNOPSIS
    IIS information collection module
.DESCRIPTION
    Collects detailed IIS information including sites, application pools, and configuration
.NOTES
    Author: Zoe Lai
    Date: 04/08/2025
    Version: 1.0
#>

function Get-IISInformation {
    <#
    .SYNOPSIS
        Get IIS information of the system.
    #>

    try {
        # Check if IIS is installed - Compatible with both Windows Server and Client
        $iisInstalled = $false
        $iisVersion = $null
        
        # Try Windows Server method first
        try {
            if (Get-Command "Get-WindowsFeature" -ErrorAction SilentlyContinue) {
                $webServerFeature = Get-WindowsFeature -Name "Web-Server" -ErrorAction SilentlyContinue
                $iisInstalled = $webServerFeature -and $webServerFeature.InstallState -eq "Installed"
            }
        }
        catch {
            # Windows Server method failed, continue to registry method
        }
        
        # If Windows Server method didn't work, try registry method (Windows Client/Server)
        if (-not $iisInstalled) {
            $iisRegKey = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\InetStp" -ErrorAction SilentlyContinue
            $iisInstalled = $null -ne $iisRegKey
        }
        
        # Additional check for IIS installation via service
        if (-not $iisInstalled) {
            try {
                $w3svcService = Get-Service -Name "W3SVC" -ErrorAction SilentlyContinue
                $iisInstalled = $w3svcService -and $w3svcService.Status -eq "Running"
            }
            catch {
                # Service check failed, continue
            }
        }
        
        # Get IIS version from registry
        if ($iisInstalled) {
            $versionInfo = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\InetStp" -ErrorAction SilentlyContinue
            if ($versionInfo) {
                $iisVersion = "$($versionInfo.MajorVersion).$($versionInfo.MinorVersion)"
            }
        }

        if ($iisInstalled) {
            # Import IIS modules if available
            try {
                Import-Module WebAdministration -ErrorAction SilentlyContinue
                Import-Module IISAdministration -ErrorAction SilentlyContinue
            }
            catch {
                Write-Verbose "Could not import IIS modules, trying alternative methods"
            }
            
            # Get sites using multiple methods
            $sites = @()
            try {
                # Try IISAdministration module first
                if (Get-Command "Get-IISSite" -ErrorAction SilentlyContinue) {
                    $sites = Get-IISSite -ErrorAction SilentlyContinue
                    Write-Verbose "Found $($sites.Count) sites using Get-IISSite"
                }
                # Fallback to WebAdministration module
                elseif (Get-Command "Get-Website" -ErrorAction SilentlyContinue) {
                    $sites = Get-Website -ErrorAction SilentlyContinue
                    Write-Verbose "Found $($sites.Count) sites using Get-Website"
                }
            }
            catch {
                if ($_.Exception.Message -like "*insufficient permissions*" -or $_.Exception.Message -like "*redirection.config*") {
                    Write-Warning "Could not retrieve IIS sites due to insufficient permissions. Run as Administrator to access IIS configuration."
                } else {
                    Write-Warning "Could not retrieve IIS sites: $_"
                }
            }
            
            # Get application pools
            $appPools = @()
            try {
                # Try IISAdministration module first (new method)
                if (Get-Command "Get-IISAppPool" -ErrorAction SilentlyContinue) {
                    $appPools = Get-IISAppPool -ErrorAction SilentlyContinue
                }
                # Fallback try older method via WebAdministration module
                elseif (Get-Command "Get-ChildItem" -ErrorAction SilentlyContinue) {
                    # Use IIS provider to get application pools
                    $appPools = Get-ChildItem IIS:\AppPools -ErrorAction SilentlyContinue
                }
            }
            catch {
                if ($_.Exception.Message -like "*insufficient permissions*" -or $_.Exception.Message -like "*redirection.config*") {
                    Write-Warning "Could not retrieve IIS application pools due to insufficient permissions. Run as Administrator to access IIS configuration."
                } else {
                    Write-Warning "Could not retrieve IIS application pools: $_"
                }
            }
            
            # Process sites and their applications
            $processedSites = @()
            foreach ($site in $sites) {
                Write-Verbose "Processing site: $($site.Name)"
                
                # Get applications for this site
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
                
                # Process applications with detailed information
                $processedApplications = @()
                foreach ($app in $siteApplications) {
                    Write-Verbose "Processing application: $($app.Path) in site: $($site.Name)"
                    
                    # Get virtual directories for this application
                    $virtualDirectories = @()
                    try {
                        if (Get-Command "Get-IISVirtualDirectory" -ErrorAction SilentlyContinue) {
                            $virtualDirectories = Get-IISSite -Name $site.Name | Get-IISApplication -Path $app.Path | Get-IISVirtualDirectory -ErrorAction SilentlyContinue
                        }
                        elseif (Get-Command "Get-WebVirtualDirectory" -ErrorAction SilentlyContinue) {
                            $virtualDirectories = Get-WebVirtualDirectory -Site $site.Name -Application $app.Path -ErrorAction SilentlyContinue
                        }
                    }
                    catch {
                        Write-Verbose "Could not get virtual directories for application $($app.Path): $_"
                    }
                    
                    $appInfo = @{
                        Name = $app.Path.TrimStart('/')
                        Path = $app.Path
                        PhysicalPath = if ($virtualDirectories.Count -gt 0) { $virtualDirectories[0].PhysicalPath } else { $app.PhysicalPath }
                        ApplicationPool = $app.ApplicationPool
                        Protocols = $app.EnabledProtocols
                        State = $app.State
                        VirtualDirectories = $virtualDirectories | ForEach-Object {
                            @{
                                Path = $_.Path
                                PhysicalPath = $_.PhysicalPath
                            }
                        }
                    }
                    
                    $processedApplications += $appInfo
                }
                
                # Add site information
                $siteInfo = @{
                    Name = $site.Name
                    ID = $site.ID
                    State = $site.State
                    PhysicalPath = $site.PhysicalPath
                    Bindings = $site.Bindings
                    Applications = $processedApplications
                }
                
                $processedSites += $siteInfo
            }
            
            # Process application pools with detailed information
            $processedAppPools = $appPools | ForEach-Object {
                @{
                    Name = $_.Name
                    State = $_.State
                    ManagedRuntimeVersion = $_.ManagedRuntimeVersion
                    ManagedPipelineMode = $_.ManagedPipelineMode
                    StartMode = $_.StartMode
                    ProcessModel = @{
                        IdentityType = $_.ProcessModel.IdentityType
                        UserName = $_.ProcessModel.UserName
                    }
                    Recycling = @{
                        PeriodicRestart = $_.Recycling.PeriodicRestart
                        Time = $_.Recycling.Time
                    }
                }
            }

            return @{
                IsInstalled = $true
                Version = $iisVersion
                Sites = $processedSites
                ApplicationPools = $processedAppPools
                TotalSites = $sites.Count
                TotalApplications = ($processedSites | ForEach-Object { $_.Applications.Count } | Measure-Object -Sum).Sum
                TotalAppPools = $appPools.Count
            }
        } else {
            return @{ IsInstalled = $false }
        }
        
    }
    catch {
        Write-Warning "Could not retrieve IIS information: $_"
        return @{ IsInstalled = $false }
    }
} 