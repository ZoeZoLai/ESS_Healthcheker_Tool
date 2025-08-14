<#
.SYNOPSIS
    WFE detection and configuration parsing
.DESCRIPTION
    Handles detection of WFE installations and parsing of WFE configuration files
.NOTES
    Author: Zoe Lai
    Date: 04/08/2025
    Version: 1.0
#>

function Test-WFEInstallation {
    <#
    .SYNOPSIS
        Test if WFE is installed on current server via IIS discovery.
    .DESCRIPTION
        Discovers WFE installation by checking IIS sites and looking for tenants.config file.
    #>

    try {
        Write-Verbose "Starting WFE installation check..."
        
        # Check if IIS is installed first (direct check to avoid circular reference)
        $iisInstalled = $false
        try {
            if (Get-Command "Get-WindowsFeature" -ErrorAction SilentlyContinue) {
                $webServerFeature = Get-WindowsFeature -Name "Web-Server" -ErrorAction SilentlyContinue
                $iisInstalled = $webServerFeature -and $webServerFeature.InstallState -eq "Installed"
            }
        }
        catch {
            # Try registry method for IIS detection
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
        
        Write-Verbose "IIS installed: $iisInstalled"
        
        # Check for WFE sites in IIS
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
            
            foreach ($site in $sites) {
                Write-Verbose "Checking IIS site for Workflow Engine: $($site.Name)"

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
                
                # Check each path for WFE installation
                foreach ($pathInfo in $allPathsToCheck) {
                    $physicalPath = $pathInfo.Path
                    
                    if ($physicalPath -and (Test-Path $physicalPath)) {
                        # Look for tenants.config
                        $tenantsConfig = Join-Path $physicalPath "tenants.config"
                        
                        if (Test-Path $tenantsConfig) {
                            Write-Verbose "Found WFE installation at: $physicalPath"
                            
                            # Parse tenants.config
                            $configInfo = Get-TenantsConfigInfo -ConfigPath $tenantsConfig
                            
                            return @{
                                Installed = $true
                                InstallPath = $physicalPath
                                ConfigPath = Join-Path $physicalPath "Web.config"
                                BinPath = Join-Path $physicalPath "bin"
                                TenantsConfigPath = $tenantsConfig
                                SiteName = $site.Name
                                ApplicationPath = $pathInfo.ApplicationPath
                                ApplicationPool = $pathInfo.ApplicationPool
                                DatabaseServer = $configInfo.DatabaseServer
                                DatabaseName = $configInfo.DatabaseName
                                ClientUrl = $configInfo.ClientUrl
                                TenantId = $configInfo.TenantId
                                FromEmailAddress = $configInfo.FromEmailAddress
                            }
                        }
                    }
                }
            }
        }
        
        # if no WFE found via IIS, it is not installed on this server
        Write-Verbose "No WFE installation found via IIS - WFE may not be installed on this server."
        return @{
            Installed = $false
            InstallPath = $null
            ConfigPath = $null
            BinPath = $null
            TenantsConfigPath = $null
            SiteName = $null
            ApplicationPath = $null
            ApplicationPool = $null
            DatabaseServer = $null
            DatabaseName = $null
            ClientUrl = $null
            TenantId = $null
            FromEmailAddress = $null
        }
    }
    catch {
        Write-Warning "Error checking WFE installation: $_"
        return @{
            Installed = $false
            InstallPath = $null
            ConfigPath = $null
            BinPath = $null
            TenantsConfigPath = $null
            SiteName = $null
            ApplicationPath = $null
            ApplicationPool = $null
            DatabaseServer = $null
            DatabaseName = $null
            ClientUrl = $null
            TenantId = $null
            FromEmailAddress = $null
        }
    }
}

function Find-WFEInstances {
    <#
    .SYNOPSIS
        Find all WFE installations on the machine
    #>
    [CmdletBinding()]
    param()

    try {
        $wfeInstances = @()
        
        # Import IIS modules
        try {
            Import-Module WebAdministration -ErrorAction SilentlyContinue
            Import-Module IISAdministration -ErrorAction SilentlyContinue
        }
        catch {
            Write-Warning "Could not import IIS modules"
            return $wfeInstances
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
            return $wfeInstances
        }

        foreach ($site in $sites) {
            Write-Verbose "Checking site: $($site.Name)"
            
            # Get applications in this site
            $applications = @()
            try {
                if (Get-Command "Get-IISApplication" -ErrorAction SilentlyContinue) {
                    $applications = Get-IISSite -Name $site.Name | Get-IISApplication -ErrorAction SilentlyContinue
                }
                elseif (Get-Command "Get-WebApplication" -ErrorAction SilentlyContinue) {
                    $applications = Get-WebApplication -Site $site.Name -ErrorAction SilentlyContinue
                }
            }
            catch {
                Write-Verbose "Could not get applications for site $($site.Name)"
            }

            # Check site root and all applications
            $pathsToCheck = @()
            
            # Add site root
            if ($site.PhysicalPath) {
                $pathsToCheck += @{
                    Path = $site.PhysicalPath
                    ApplicationPath = "/"
                    ApplicationPool = $site.ApplicationPool
                    IsRoot = $true
                }
            }
            
            # Add applications
            foreach ($app in $applications) {
                if ($app.PhysicalPath) {
                    $pathsToCheck += @{
                        Path = $app.PhysicalPath
                        ApplicationPath = $app.Path
                        ApplicationPool = $app.ApplicationPool
                        IsRoot = $false
                    }
                }
            }

            # Check each path for WFE installation
            foreach ($pathInfo in $pathsToCheck) {
                $physicalPath = $pathInfo.Path
                
                if ($physicalPath -and (Test-Path $physicalPath)) {
                    # Look for tenants.config
                    $tenantsConfig = Join-Path $physicalPath "tenants.config"
                    
                    if (Test-Path $tenantsConfig) {
                        Write-Verbose "Found WFE installation at: $physicalPath"
                        
                        # Parse tenants.config
                        $configInfo = Get-TenantsConfigInfo -ConfigPath $tenantsConfig
                        
                        $wfeInstance = @{
                            SiteName = $site.Name
                            PhysicalPath = $physicalPath
                            ApplicationPath = $pathInfo.ApplicationPath
                            ApplicationPool = $pathInfo.ApplicationPool
                            IsRootApplication = $pathInfo.IsRoot
                            TenantsConfigPath = $tenantsConfig
                            DatabaseServer = $configInfo.DatabaseServer
                            DatabaseName = $configInfo.DatabaseName
                            TenantID = $configInfo.TenantId
                            ClientURL = $configInfo.ClientUrl
                        }
                        
                        $wfeInstances += [PSCustomObject]$wfeInstance
                    }
                }
            }
        }

        return $wfeInstances
    }
    catch {
        Write-Warning "Error finding WFE instances: $_"
        return @()
    }
}

function Get-TenantsConfigInfo {
    <#
    .SYNOPSIS
        Parses tenants.config file to extract connection and configuration info.
    .PARAMETER ConfigPath
        Path to the tenants.config file.
    #>
    
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ConfigPath
    )

    try {
        if (-not (Test-Path $ConfigPath)) {
            Write-Warning "tenants.config file not found at path: $ConfigPath"
            return @{}
        }

        $configContent = Get-Content $ConfigPath -Raw
        $configInfo = @{
            DatabaseServer = $null
            DatabaseName = $null
            ClientUrl = $null
            TenantId = $null
            FromEmailAddress = $null
        }

        # Extract Connection string information
        $workflowDbMatch = [regex]::Match($configContent, '<workflowDatabaseConnection>([^<]*)</workflowDatabaseConnection>')
        if ($workflowDbMatch.Success) {
            $connectionString = $workflowDbMatch.Groups[1].Value

            # Parse the connection string
            $serverMatch = [regex]::Match($connectionString, 'data source=([^;]*)')
            if ($serverMatch.Success) {
                $configInfo.DatabaseServer = $serverMatch.Groups[1].Value.Trim()
            }

            $catalogMatch = [regex]::Match($connectionString, 'initial catalog=([^;]*)')
            if ($catalogMatch.Success) {
                $configInfo.DatabaseName = $catalogMatch.Groups[1].Value.Trim()
            }
        }

        # Extract Client URL
        $clientUrlMatch = [regex]::Match($configContent, '<clientUrl>([^<]*)</clientUrl>')
        if ($clientUrlMatch.Success) {
            $configInfo.ClientUrl = $clientUrlMatch.Groups[1].Value.Trim()
        }

        # Extract Tenant ID
        $tenantIdMatch = [regex]::Match($configContent, '<tenant id="([^"]*)">')
        if ($tenantIdMatch.Success) {
            $configInfo.TenantId = $tenantIdMatch.Groups[1].Value.Trim()
        }

        # Extract From Email Address
        $fromEmailAddressMatch = [regex]::Match($configContent, '<from-email-address>([^<]*)</from-email-address>')
        if ($fromEmailAddressMatch.Success) {
            $configInfo.FromEmailAddress = $fromEmailAddressMatch.Groups[1].Value.Trim()
        }

        return $configInfo
    }
    catch {
        Write-Warning "Error parsing tenants.config: $_"
        return @{}
    }
} 