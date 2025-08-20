<#
.SYNOPSIS
    ESS detection and configuration parsing
.DESCRIPTION
    Handles detection of ESS installations and parsing of ESS configuration files
.NOTES
    Author: Zoe Lai
    Date: 04/08/2025
    Version: 1.0
#>

function Test-ESSInstallation {
    <#
    .SYNOPSIS
        Test if ESS is installed on current server via IIS discovery.
    .DESCRIPTION
        Discovers ESS installation by check IIS sites and payglobal.config file.
    #>
    
    try {
        Write-Verbose "Starting ESS installation check..."
        
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
        
        # Check for ESS sites in IIS
        if ($iisInstalled) {
            # Import IIS module if available
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
                Write-Verbose "Checking IIS site for ESS: $($site.Name)"

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
                
                # Check each path for ESS installation
                foreach ($pathInfo in $allPathsToCheck) {
                    $physicalPath = $pathInfo.Path
                    
                    if ($physicalPath -and (Test-Path $physicalPath)) {
                        # Look for payglobal.config
                        $payglobalConfig = Join-Path $physicalPath "payglobal.config"
                        
                        if (Test-Path $payglobalConfig) {
                            Write-Verbose "Found ESS installation at: $physicalPath"
                            
                            # Get web.config path for encryption checking
                            $webConfigPath = Join-Path $physicalPath "Web.config"
                            
                            # Parse payglobal.config
                            $configInfo = Get-PayGlobalConfigInfo -ConfigPath $payglobalConfig -WebConfigPath $webConfigPath
                            
                            # Get version information from bin folder
                            $binPath = Join-Path $physicalPath "bin"
                            $versionInfo = Get-ESSVersionInfo -BinPath $binPath
                            
                            # Test version compatibility
                            $compatibilityInfo = Test-ESSVersionCompatibility -ESSVersion $versionInfo.ESSVersion -PayGlobalVersion $versionInfo.PayGlobalVersion
                            
                            return @{
                                Installed = $true
                                InstallPath = $physicalPath
                                WebConfigPath = Join-Path $physicalPath "Web.config"
                                BinPath = Join-Path $physicalPath "bin"
                                PayGlobalConfigPath = $payglobalConfig
                                SiteName = $site.Name
                                ApplicationPath = $pathInfo.ApplicationPath
                                ApplicationPool = $pathInfo.ApplicationPool
                                DatabaseServer = $configInfo.DatabaseServer
                                DatabaseName = $configInfo.DatabaseName
                                TenantID = $configInfo.TenantID
                                HostName = $configInfo.HostName
                                VirtualRoot = $configInfo.VirtualRoot
                                Protocol = $configInfo.Protocol
                                AuthenticationMode = $configInfo.AuthenticationMode
                                WebConfigEncrypted = $configInfo.WebConfigEncrypted
                                EncryptionStatus = $configInfo.EncryptionStatus
                                ESSVersion = $versionInfo.ESSVersion
                                PayGlobalVersion = $versionInfo.PayGlobalVersion
                                VersionCompatibility = $compatibilityInfo
                            }
                        }
                    }
                }
            }
        }
        
        # if no ESS found via IIS, it might be installed on other server
        Write-Verbose "No ESS installation found in IIS - ESS may not be installed on this server."
        return @{
            Installed = $false
            InstallPath = $null
            WebConfigPath = $null
            BinPath = $null
            PayGlobalConfigPath = $null
            SiteName = $null
            ApplicationPath = $null
            ApplicationPool = $null
            DatabaseServer = $null
            DatabaseName = $null
            TenantID = $null
            HostName = $null
            VirtualRoot = $null
            Protocol = "null"
            AuthenticationMode = $null
        }
        
    }
    catch {
        Write-Warning "Error checking ESS installation: $_"
        return @{
            Installed = $false
            InstallPath = $null
            WebConfigPath = $null
            BinPath = $null
            PayGlobalConfigPath = $null
            SiteName = $null
            ApplicationPath = $null
            ApplicationPool = $null
            DatabaseServer = $null
            DatabaseName = $null
            TenantID = $null
            HostName = $null
            VirtualRoot = $null
            Protocol = "null"
            AuthenticationMode = $null
        }
    }
}

function Find-ESSInstances {
    <#
    .SYNOPSIS
        Find all ESS installations on the machine
    #>
    [CmdletBinding()]
    param()

    try {
        $essInstances = @()
        
        # Import IIS modules
        try {
            Import-Module WebAdministration -ErrorAction SilentlyContinue
            Import-Module IISAdministration -ErrorAction SilentlyContinue
        }
        catch {
            Write-Warning "Could not import IIS modules"
            return $essInstances
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
            return $essInstances
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

            # Check each path for ESS installation
            foreach ($pathInfo in $pathsToCheck) {
                $physicalPath = $pathInfo.Path
                
                if ($physicalPath -and (Test-Path $physicalPath)) {
                    # Look for payglobal.config
                    $payglobalConfig = Join-Path $physicalPath "payglobal.config"
                    
                    if (Test-Path $payglobalConfig) {
                        Write-Verbose "Found ESS installation at: $physicalPath"
                        
                        # Get web.config path for encryption checking
                        $webConfigPath = Join-Path $physicalPath "Web.config"
                        
                        # Parse payglobal.config
                        $configInfo = Get-PayGlobalConfigInfo -ConfigPath $payglobalConfig -WebConfigPath $webConfigPath
                        
                        # Get version information from bin folder
                        $binPath = Join-Path $physicalPath "bin"
                        $versionInfo = Get-ESSVersionInfo -BinPath $binPath
                        
                        # Test version compatibility
                        $compatibilityInfo = Test-ESSVersionCompatibility -ESSVersion $versionInfo.ESSVersion -PayGlobalVersion $versionInfo.PayGlobalVersion
                        
                        # Get bindings and protocol information
                        $bindingsInfo = Get-ESSBindingsInfo -SiteName $site.Name -ApplicationPath $pathInfo.ApplicationPath
                        
                        # Test SSL certificates if HTTPS is used
                        $sslInfo = @()
                        if ($bindingsInfo.UsesHTTPS) {
                            # Check SSL certificates for all HTTPS bindings
                            foreach ($binding in $bindingsInfo.Bindings) {
                                if ($binding.IsHTTPS) {
                                    # Construct URL using binding information
                                    $hostHeader = $binding.HostHeader
                                    if (-not $hostHeader -or $hostHeader -eq "*") {
                                        # Use hostname from config if no host header in binding
                                        $hostHeader = $configInfo.HostName
                                    }
                                    
                                    # Skip localhost or empty hostnames for SSL testing
                                    if ($hostHeader -and $hostHeader -ne "localhost" -and $hostHeader -ne "127.0.0.1") {
                                        $siteUrl = "https://$hostHeader"
                                        Write-Verbose "Testing SSL certificate for: $siteUrl"
                                        $sslInfo += Test-SSLCertificateExpiry -Url $siteUrl
                                    } else {
                                        Write-Verbose "Skipping SSL certificate test for localhost/empty hostname: $hostHeader"
                                    }
                                }
                            }
                        }
                        
                        $essInstance = [PSCustomObject]@{
                            SiteName = $site.Name
                            PhysicalPath = $physicalPath
                            ApplicationPath = $pathInfo.ApplicationPath
                            ApplicationPool = $pathInfo.ApplicationPool
                            IsRootApplication = $pathInfo.IsRoot
                            PayGlobalConfigPath = $payglobalConfig
                            DatabaseServer = $configInfo.DatabaseServer
                            DatabaseName = $configInfo.DatabaseName
                            TenantID = $configInfo.TenantID
                            Protocol = $configInfo.Protocol
                            Host = $configInfo.HostName
                            VirtualRoot = $configInfo.VirtualRoot
                            Navigator = "BaseForm.aspx" # Default from config
                            AuthenticationMode = $configInfo.AuthenticationMode
                            WebConfigEncrypted = $configInfo.WebConfigEncrypted
                            EncryptionStatus = $configInfo.EncryptionStatus
                            ESSVersion = $versionInfo.ESSVersion
                            PayGlobalVersion = $versionInfo.PayGlobalVersion
                            VersionCompatibility = $compatibilityInfo
                            BindingsInfo = $bindingsInfo
                            SSLInfo = $sslInfo
                        }
                        
                        $essInstances += $essInstance
                    }
                }
            }
        }

        # Return array using comma operator to ensure consistent behavior across PowerShell environments
        if ($essInstances.Count -eq 0) {
            return ,@()
        } else {
            return ,$essInstances
        }
    }
    catch {
        Write-Warning "Error finding ESS instances: $_"
        return @()
    }
}

function Get-PayGlobalConfigInfo {
    <#
    .SYNOPSIS
        Parses payglobal.config file to extract connection and configuration info.
    .PARAMETER ConfigPath
        Path to the payglobal.config file.
    .PARAMETER WebConfigPath
        Optional path to the web.config file for encryption checking.
    #>
    
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ConfigPath,
        
        [Parameter(Mandatory = $false)]
        [string]$WebConfigPath = $null
    )

    try {
        if (-not (Test-Path $ConfigPath)) {
            Write-Warning "payglobal.config file not found at path: $ConfigPath"
            return @{}
        }

        $configContent = Get-Content $ConfigPath -Raw
        $configInfo = @{
            DatabaseServer = $null
            DatabaseName = $null
            TenantID = $null
            HostName = $null
            VirtualRoot = $null
            Protocol = "http"
            AuthenticationMode = $null
            WebConfigEncrypted = $false
            EncryptionStatus = $null
        }

        # Extract Connection string information
        $connectionMatch = [regex]::Match($configContent, '<connection type="sql">([^<]*)</connection>')
        if ($connectionMatch.Success) {
            $connectionString = $connectionMatch.Groups[1].Value
            
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

        # Extract Tenant ID
        $tenantMatch = [regex]::Match($configContent, '<tenantId>([^<]*)</tenantId>')
        if ($tenantMatch.Success) {
            $configInfo.TenantId = $tenantMatch.Groups[1].Value.Trim()
        }

        # Extract HostName
        $hostMatch = [regex]::Match($configContent, '<host>([^<]*)</host>')
        if ($hostMatch.Success) {
            $configInfo.HostName = $hostMatch.Groups[1].Value.Trim()
        }

        # Extract VirtualRoot
        $virtualRootMatch = [regex]::Match($configContent, '<virtual-root>([^<]*)</virtual-root>')
        if ($virtualRootMatch.Success) {
            $configInfo.VirtualRoot = $virtualRootMatch.Groups[1].Value.Trim()
        }

        # Extract Protocol
        $protocolMatch = [regex]::Match($configContent, '<protocol>([^<]*)</protocol>')
        if ($protocolMatch.Success) {
            $configInfo.Protocol = $protocolMatch.Groups[1].Value.Trim()
        }

        # Extract Authentication Mode
        $authMatch = [regex]::Match($configContent, '<authenticationMode>([^<]*)</authenticationMode>')
        if ($authMatch.Success) {
            $configInfo.AuthenticationMode = $authMatch.Groups[1].Value.Trim()
        }

        # Check web.config encryption if SingleSignOn authentication mode is detected
        if ($configInfo.AuthenticationMode -eq "SingleSignOn" -and $WebConfigPath) {
            Write-Verbose "SingleSignOn authentication detected, checking web.config encryption..."
            $encryptionInfo = Test-WebConfigEncryption -WebConfigPath $WebConfigPath
            $configInfo.WebConfigEncrypted = $encryptionInfo.IsEncrypted
            $configInfo.EncryptionStatus = $encryptionInfo
        }

        return $configInfo
    }
    catch {
        Write-Warning "Error parsing payglobal.config: $_"
        return @{}
    }
}

function Test-WebConfigEncryption {
    <#
    .SYNOPSIS
        Tests if web.config sections are encrypted.
    .DESCRIPTION
        Checks if appSettings and MailAuthenticationSection in web.config are encrypted.
        This is important for SingleSignOn authentication mode.
    .PARAMETER WebConfigPath
        Path to the web.config file to check.
    .RETURNS
        Object containing encryption status information.
    #>
    
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$WebConfigPath
    )

    try {
        if (-not (Test-Path $WebConfigPath)) {
            Write-Warning "Web.config file not found at path: $WebConfigPath"
            return @{
                IsEncrypted = $false
                AppSettingsEncrypted = $false
                MailAuthenticationEncrypted = $false
                Error = "Web.config file not found"
            }
        }

        $webConfigContent = Get-Content $WebConfigPath -Raw
        $encryptionInfo = @{
            IsEncrypted = $false
            AppSettingsEncrypted = $false
            MailAuthenticationEncrypted = $false
            Error = $null
        }

        # Check if appSettings section is encrypted
        # Encrypted sections typically contain "configProtectionProvider" attribute
        $appSettingsMatch = [regex]::Match($webConfigContent, '<appSettings[^>]*configProtectionProvider[^>]*>')
        if ($appSettingsMatch.Success) {
            $encryptionInfo.AppSettingsEncrypted = $true
            $encryptionInfo.IsEncrypted = $true
        }

        # Check if MailAuthenticationSection is encrypted
        $mailAuthMatch = [regex]::Match($webConfigContent, '<MailAuthenticationSection[^>]*configProtectionProvider[^>]*>')
        if ($mailAuthMatch.Success) {
            $encryptionInfo.MailAuthenticationEncrypted = $true
            $encryptionInfo.IsEncrypted = $true
        }

        # Additional check for encrypted content patterns
        # Encrypted sections often contain "EncryptedData" elements
        $encryptedDataMatch = [regex]::Match($webConfigContent, '<EncryptedData')
        if ($encryptedDataMatch.Success) {
            $encryptionInfo.IsEncrypted = $true
        }

        return $encryptionInfo
    }
    catch {
        Write-Warning "Error checking web.config encryption: $_"
        return @{
            IsEncrypted = $false
            AppSettingsEncrypted = $false
            MailAuthenticationEncrypted = $false
            Error = $_.Exception.Message
        }
    }
}

function Get-WebServerURL {
    <#
    .SYNOPSIS
        Constructs web server URL from ESS instance configuration.
    .DESCRIPTION
        Builds the web server URL using protocol, host, and virtual root from payglobal.config.
    .PARAMETER ESSInstance
        ESS instance object containing Protocol, Host, and VirtualRoot properties.
    .RETURNS
        String containing the constructed web server URL.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [object]$ESSInstance
    )
    
    if ($ESSInstance.Protocol -and $ESSInstance.Host -and $ESSInstance.VirtualRoot) {
        return "$($ESSInstance.Protocol)://$($ESSInstance.Host)/$($ESSInstance.VirtualRoot)"
    } elseif ($ESSInstance.Protocol -and $ESSInstance.Host) {
        return "$($ESSInstance.Protocol)://$($ESSInstance.Host)"
    } else {
        return "Unknown"
    }
} 

function Get-ESSVersionInfo {
    <#
    .SYNOPSIS
        Gets ESS version information from binary files in the bin folder
    .DESCRIPTION
        Extracts version information from PayGlobal.Hrss.dll and PayGlobal.Business.dll files
    .PARAMETER BinPath
        Path to the bin folder containing the ESS binaries
    .RETURNS
        Object containing ESS and PayGlobal version information
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$BinPath
    )

    try {
        if (-not (Test-Path $BinPath)) {
            Write-Warning "Bin path not found: $BinPath"
            return @{
                ESSVersion = $null
                PayGlobalVersion = $null
                ESSVersionInfo = $null
                PayGlobalVersionInfo = $null
                Error = "Bin path not found"
            }
        }

        $versionInfo = @{
            ESSVersion = $null
            PayGlobalVersion = $null
            ESSVersionInfo = $null
            PayGlobalVersionInfo = $null
            Error = $null
        }

        # Check for PayGlobal.Hrss.dll (ESS version)
        $essDllPath = Join-Path $BinPath "PayGlobal.Hrss.dll"
        if (Test-Path $essDllPath) {
            try {
                $essFileInfo = Get-Item -Path $essDllPath
                $versionInfo.ESSVersion = $essFileInfo.VersionInfo.FileVersion
                $versionInfo.ESSVersionInfo = $essFileInfo.VersionInfo
                Write-Verbose "Found ESS version: $($versionInfo.ESSVersion)"
            }
            catch {
                Write-Warning "Error reading ESS version from $essDllPath : $_"
                $versionInfo.Error = "Error reading ESS version: $($_.Exception.Message)"
            }
        } else {
            Write-Verbose "ESS DLL not found at: $essDllPath"
        }

        # Check for PayGlobal.Business.dll (PayGlobal version)
        $payglobalDllPath = Join-Path $BinPath "PayGlobal.Business.dll"
        if (Test-Path $payglobalDllPath) {
            try {
                $payglobalFileInfo = Get-Item -Path $payglobalDllPath
                $versionInfo.PayGlobalVersion = $payglobalFileInfo.VersionInfo.FileVersion
                $versionInfo.PayGlobalVersionInfo = $payglobalFileInfo.VersionInfo
                Write-Verbose "Found PayGlobal version: $($versionInfo.PayGlobalVersion)"
            }
            catch {
                Write-Warning "Error reading PayGlobal version from $payglobalDllPath : $_"
                if ($versionInfo.Error) {
                    $versionInfo.Error += "; Error reading PayGlobal version: $($_.Exception.Message)"
                } else {
                    $versionInfo.Error = "Error reading PayGlobal version: $($_.Exception.Message)"
                }
            }
        } else {
            Write-Verbose "PayGlobal DLL not found at: $payglobalDllPath"
        }

        return $versionInfo
    }
    catch {
        Write-Warning "Error getting ESS version info: $_"
        return @{
            ESSVersion = $null
            PayGlobalVersion = $null
            ESSVersionInfo = $null
            PayGlobalVersionInfo = $null
            Error = $_.Exception.Message
        }
    }
}

function Test-ESSVersionCompatibility {
    <#
    .SYNOPSIS
        Tests ESS and PayGlobal version compatibility
    .DESCRIPTION
        Validates ESS version against minimum requirements and PayGlobal version compatibility
    .PARAMETER ESSVersion
        ESS version string
    .PARAMETER PayGlobalVersion
        PayGlobal version string
    .RETURNS
        Object containing compatibility test results
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ESSVersion,
        
        [Parameter(Mandatory = $false)]
        [string]$PayGlobalVersion = $null
    )

    try {
        $compatibility = @{
            ESSVersionSupported = $false
            PayGlobalVersionCompatible = $false
            ESSVersionStatus = "UNKNOWN"
            PayGlobalVersionStatus = "UNKNOWN"
            ESSVersionMessage = ""
            PayGlobalVersionMessage = ""
            OverallCompatibility = $false
            Recommendations = @()
        }

        # Parse ESS version
        if ($ESSVersion) {
            $essVersionParts = $ESSVersion.Split('.')
            if ($essVersionParts.Count -ge 4) {
                $essMajor = [int]$essVersionParts[0]
                $essMinor = [int]$essVersionParts[1]
                $essBuild = [int]$essVersionParts[2]
                $essRevision = [int]$essVersionParts[3]
                
                # Check minimum ESS version (5.4.7.2)
                if ($essMajor -gt 5 -or ($essMajor -eq 5 -and $essMinor -gt 4) -or 
                    ($essMajor -eq 5 -and $essMinor -eq 4 -and $essBuild -gt 7) -or
                    ($essMajor -eq 5 -and $essMinor -eq 4 -and $essBuild -eq 7 -and $essRevision -ge 2)) {
                    $compatibility.ESSVersionSupported = $true
                    $compatibility.ESSVersionStatus = "SUPPORTED"
                    $compatibility.ESSVersionMessage = "ESS version $ESSVersion is supported"
                } else {
                    $compatibility.ESSVersionSupported = $false
                    $compatibility.ESSVersionStatus = "UNSUPPORTED"
                    $compatibility.ESSVersionMessage = "ESS version $ESSVersion is not supported. Minimum required version is 5.4.7.2"
                    $compatibility.Recommendations += "Upgrade ESS to version 5.4.7.2 or higher"
                }
            } else {
                $compatibility.ESSVersionStatus = "INVALID"
                $compatibility.ESSVersionMessage = "Invalid ESS version format: $ESSVersion"
            }
        } else {
            $compatibility.ESSVersionStatus = "NOT_FOUND"
            $compatibility.ESSVersionMessage = "ESS version not found"
        }

        # Check PayGlobal version compatibility if available
        if ($PayGlobalVersion) {
            $payglobalVersionParts = $PayGlobalVersion.Split('.')
            if ($payglobalVersionParts.Count -ge 4) {
                $payglobalMajor = [int]$payglobalVersionParts[0]
                $payglobalMinor = [int]$payglobalVersionParts[1]
                $payglobalBuild = [int]$payglobalVersionParts[2]
                $payglobalRevision = [int]$payglobalVersionParts[3]
                
                # Check compatibility based on ESS version
                $compatible = $false
                $requiredVersion = ""
                
                if ($compatibility.ESSVersionSupported -and $ESSVersion) {
                    $essVersionParts = $ESSVersion.Split('.')
                    if ($essVersionParts.Count -ge 4) {
                        $essMajor = [int]$essVersionParts[0]
                        $essMinor = [int]$essVersionParts[1]
                        $essBuild = [int]$essVersionParts[2]
                        $essRevision = [int]$essVersionParts[3]
                        
                        # ESS 5.5.1.2 requires PayGlobal 4.66.0.0 or higher
                        if ($essMajor -eq 5 -and $essMinor -eq 5 -and $essBuild -eq 1 -and $essRevision -eq 2) {
                            $requiredVersion = "4.66.0.0"
                            if ($payglobalMajor -gt 4 -or ($payglobalMajor -eq 4 -and $payglobalMinor -gt 66) -or
                                ($payglobalMajor -eq 4 -and $payglobalMinor -eq 66 -and $payglobalBuild -ge 0 -and $payglobalRevision -ge 0)) {
                                $compatible = $true
                            }
                        }
                        # ESS 5.6.0.0 requires PayGlobal 4.72.0.0 or higher
                        elseif ($essMajor -eq 5 -and $essMinor -eq 6 -and $essBuild -eq 0 -and $essRevision -eq 0) {
                            $requiredVersion = "4.72.0.0"
                            if ($payglobalMajor -gt 4 -or ($payglobalMajor -eq 4 -and $payglobalMinor -gt 72) -or
                                ($payglobalMajor -eq 4 -and $payglobalMinor -eq 72 -and $payglobalBuild -ge 0 -and $payglobalRevision -ge 0)) {
                                $compatible = $true
                            }
                        }
                        # For other supported ESS versions, assume compatible
                        else {
                            $compatible = $true
                            $requiredVersion = "Compatible"
                        }
                    }
                }
                
                if ($compatible) {
                    $compatibility.PayGlobalVersionCompatible = $true
                    $compatibility.PayGlobalVersionStatus = "COMPATIBLE"
                    $compatibility.PayGlobalVersionMessage = "PayGlobal version $PayGlobalVersion is compatible with ESS version $ESSVersion"
                } else {
                    $compatibility.PayGlobalVersionCompatible = $false
                    $compatibility.PayGlobalVersionStatus = "INCOMPATIBLE"
                    $compatibility.PayGlobalVersionMessage = "PayGlobal version $PayGlobalVersion is not compatible with ESS version $ESSVersion. Required version: $requiredVersion"
                    $compatibility.Recommendations += "Upgrade PayGlobal to version $requiredVersion or higher"
                }
            } else {
                $compatibility.PayGlobalVersionStatus = "INVALID"
                $compatibility.PayGlobalVersionMessage = "Invalid PayGlobal version format: $PayGlobalVersion"
            }
        } else {
            $compatibility.PayGlobalVersionStatus = "NOT_FOUND"
            $compatibility.PayGlobalVersionMessage = "PayGlobal version not found"
        }

        # Determine overall compatibility
        $compatibility.OverallCompatibility = $compatibility.ESSVersionSupported -and 
                                            ($compatibility.PayGlobalVersionCompatible -or $compatibility.PayGlobalVersionStatus -eq "NOT_FOUND")

        return $compatibility
    }
    catch {
        Write-Warning "Error testing ESS version compatibility: $_"
        return @{
            ESSVersionSupported = $false
            PayGlobalVersionCompatible = $false
            ESSVersionStatus = "ERROR"
            PayGlobalVersionStatus = "ERROR"
            ESSVersionMessage = "Error testing compatibility: $($_.Exception.Message)"
            PayGlobalVersionMessage = "Error testing compatibility: $($_.Exception.Message)"
            OverallCompatibility = $false
            Recommendations = @("Error occurred during compatibility testing")
        }
    }
} 

function Get-ESSBindingsInfo {
    <#
    .SYNOPSIS
        Gets ESS bindings and protocol information from IIS site bindings
    .DESCRIPTION
        Extracts protocol information from IIS site bindings to determine HTTP/HTTPS usage
    .PARAMETER SiteName
        Name of the IIS site to check bindings for
    .PARAMETER ApplicationPath
        Application path within the site (optional)
    .RETURNS
        Object containing bindings and protocol information
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$SiteName,
        
        [Parameter(Mandatory = $false)]
        [string]$ApplicationPath = "/"
    )

    try {
        $bindingsInfo = @{
            UsesHTTPS = $false
            Protocols = @()
            Bindings = @()
            Error = $null
        }

        # Import IIS modules if available
        try {
            Import-Module WebAdministration -ErrorAction SilentlyContinue
            Import-Module IISAdministration -ErrorAction SilentlyContinue
        }
        catch {
            Write-Warning "Could not import IIS modules"
            $bindingsInfo.Error = "Could not import IIS modules"
            return $bindingsInfo
        }

        # Get site bindings using multiple methods
        $siteBindings = @()
        try {
            # Try IISAdministration module first
            if (Get-Command "Get-IISSiteBinding" -ErrorAction SilentlyContinue) {
                $siteBindings = Get-IISSiteBinding -Name $SiteName -ErrorAction SilentlyContinue
                Write-Verbose "Found $($siteBindings.Count) bindings using Get-IISSiteBinding for site: $SiteName"
            }
            # Fallback to WebAdministration module
            elseif (Get-Command "Get-WebBinding" -ErrorAction SilentlyContinue) {
                $siteBindings = Get-WebBinding -Name $SiteName -ErrorAction SilentlyContinue
                Write-Verbose "Found $($siteBindings.Count) bindings using Get-WebBinding for site: $SiteName"
            }
            # Alternative method using Get-Website
            elseif (Get-Command "Get-Website" -ErrorAction SilentlyContinue) {
                $site = Get-Website -Name $SiteName -ErrorAction SilentlyContinue
                if ($site -and $site.Bindings) {
                    $siteBindings = $site.Bindings
                    Write-Verbose "Found $($siteBindings.Count) bindings using Get-Website for site: $SiteName"
                }
            }
            
            # If no bindings found, log a warning
            if ($siteBindings.Count -eq 0) {
                Write-Warning "No bindings found for site: $SiteName"
                $bindingsInfo.Error = "No bindings found for site: $SiteName"
            }
        }
        catch {
            Write-Warning "Could not retrieve IIS site bindings for site '$SiteName': $_"
            $bindingsInfo.Error = "Could not retrieve IIS site bindings for site '$SiteName': $($_.Exception.Message)"
            return $bindingsInfo
        }

        # Process each binding
        foreach ($binding in $siteBindings) {
            $bindingInfo = @{
                Protocol = $null
                BindingInformation = $null
                Port = $null
                HostHeader = $null
                IsHTTPS = $false
            }

            # Extract binding information based on the type of object returned
            if ($binding.Protocol) {
                $bindingInfo.Protocol = $binding.Protocol.ToLower()
                $bindingInfo.IsHTTPS = ($binding.Protocol.ToLower() -eq "https")
            }
            elseif ($binding.BindingInformation) {
                # Parse binding information string (format: IP:Port:HostHeader)
                $bindingParts = $binding.BindingInformation.Split(':')
                if ($bindingParts.Count -ge 2) {
                    $bindingInfo.Port = $bindingParts[1]
                    if ($bindingParts.Count -ge 3) {
                        $bindingInfo.HostHeader = $bindingParts[2]
                    }
                    # Determine protocol based on port
                    if ($bindingInfo.Port -eq "443") {
                        $bindingInfo.Protocol = "https"
                        $bindingInfo.IsHTTPS = $true
                    } elseif ($bindingInfo.Port -eq "80") {
                        $bindingInfo.Protocol = "http"
                    } else {
                        $bindingInfo.Protocol = "unknown"
                    }
                }
                $bindingInfo.BindingInformation = $binding.BindingInformation
            }
            
            # Additional validation for binding information
            if (-not $bindingInfo.Protocol) {
                Write-Verbose "Could not determine protocol for binding: $($binding | ConvertTo-Json -Depth 1)"
                continue
            }

            # Add to bindings array
            $bindingsInfo.Bindings += $bindingInfo

            # Update protocols and HTTPS status
            if ($bindingInfo.Protocol) {
                if (-not ($bindingsInfo.Protocols -contains $bindingInfo.Protocol)) {
                    $bindingsInfo.Protocols += $bindingInfo.Protocol
                }
                if ($bindingInfo.IsHTTPS) {
                    $bindingsInfo.UsesHTTPS = $true
                }
            }
        }

        # Remove duplicates from protocols
        $bindingsInfo.Protocols = $bindingsInfo.Protocols | Sort-Object -Unique

        Write-Verbose "Found protocols in IIS bindings: $($bindingsInfo.Protocols -join ', ')"
        Write-Verbose "Uses HTTPS: $($bindingsInfo.UsesHTTPS)"
        Write-Verbose "Total bindings processed: $($bindingsInfo.Bindings.Count)"
        
        # Log detailed binding information for debugging
        foreach ($binding in $bindingsInfo.Bindings) {
            Write-Verbose "Binding: Protocol=$($binding.Protocol), Port=$($binding.Port), HostHeader=$($binding.HostHeader), IsHTTPS=$($binding.IsHTTPS)"
        }

        return $bindingsInfo
    }
    catch {
        Write-Warning "Error getting ESS bindings info: $_"
        return @{
            UsesHTTPS = $false
            Protocols = @()
            Bindings = @()
            Error = $_.Exception.Message
        }
    }
}

function Test-SSLCertificateExpiry {
    <#
    .SYNOPSIS
        Tests SSL certificate expiry for HTTPS endpoints
    .DESCRIPTION
        Checks SSL certificate expiry dates for HTTPS URLs
    .PARAMETER Url
        HTTPS URL to check
    .PARAMETER DaysWarning
        Number of days before expiry to warn (default: 30)
    .RETURNS
        Object containing SSL certificate information
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Url,
        
        [Parameter(Mandatory = $false)]
        [int]$DaysWarning = 30
    )

    try {
        $sslInfo = @{
            Url = $Url
            HasValidCertificate = $false
            CertificateExpiry = $null
            DaysUntilExpiry = $null
            CertificateSubject = $null
            CertificateIssuer = $null
            Status = "UNKNOWN"
            Error = $null
        }

        # Ensure URL starts with https
        if (-not $Url.StartsWith("https://")) {
            $sslInfo.Error = "URL must use HTTPS protocol"
            return $sslInfo
        }

        try {
            # Create web request
            $request = [System.Net.WebRequest]::Create($Url)
            $request.Timeout = 10000  # 10 seconds timeout
            
            # Get response
            $response = $request.GetResponse()
            $response.Close()
            
            # Get certificate from the request
            $servicePoint = $request.ServicePoint
            $certificate = $servicePoint.Certificate
            
            if ($certificate) {
                $sslInfo.HasValidCertificate = $true
                $sslInfo.CertificateExpiry = $certificate.GetExpirationDateString()
                $sslInfo.CertificateSubject = $certificate.Subject
                $sslInfo.CertificateIssuer = $certificate.Issuer
                
                # Calculate days until expiry
                $expiryDate = [DateTime]::Parse($certificate.GetExpirationDateString())
                $currentDate = Get-Date
                $sslInfo.DaysUntilExpiry = ($expiryDate - $currentDate).Days
                
                # Determine status
                if ($sslInfo.DaysUntilExpiry -lt 0) {
                    $sslInfo.Status = "EXPIRED"
                } elseif ($sslInfo.DaysUntilExpiry -le $DaysWarning) {
                    $sslInfo.Status = "WARNING"
                } else {
                    $sslInfo.Status = "VALID"
                }
                
                Write-Verbose "SSL certificate for $Url expires in $($sslInfo.DaysUntilExpiry) days"
            } else {
                # Try alternative method using X509Certificate2
                try {
                    $uri = [System.Uri]$Url
                    $tcpClient = New-Object System.Net.Sockets.TcpClient
                    $tcpClient.Connect($uri.Host, 443)
                    $sslStream = New-Object System.Net.Security.SslStream($tcpClient.GetStream(), $false)
                    $sslStream.AuthenticateAsClient($uri.Host)
                    $certificate = $sslStream.RemoteCertificate
                    $sslStream.Close()
                    $tcpClient.Close()
                    
                    if ($certificate) {
                        $sslInfo.HasValidCertificate = $true
                        $sslInfo.CertificateExpiry = $certificate.GetExpirationDateString()
                        $sslInfo.CertificateSubject = $certificate.Subject
                        $sslInfo.CertificateIssuer = $certificate.Issuer
                        
                        # Calculate days until expiry
                        $expiryDate = [DateTime]::Parse($certificate.GetExpirationDateString())
                        $currentDate = Get-Date
                        $sslInfo.DaysUntilExpiry = ($expiryDate - $currentDate).Days
                        
                        # Determine status
                        if ($sslInfo.DaysUntilExpiry -lt 0) {
                            $sslInfo.Status = "EXPIRED"
                        } elseif ($sslInfo.DaysUntilExpiry -le $DaysWarning) {
                            $sslInfo.Status = "WARNING"
                        } else {
                            $sslInfo.Status = "VALID"
                        }
                        
                        Write-Verbose "SSL certificate for $Url expires in $($sslInfo.DaysUntilExpiry) days (alternative method)"
                    } else {
                        $sslInfo.Error = "No certificate found using alternative method"
                    }
                }
                catch {
                    $sslInfo.Error = "No certificate found and alternative method failed: $($_.Exception.Message)"
                }
            }
        }
        catch {
            $sslInfo.Error = "Error checking SSL certificate: $($_.Exception.Message)"
        }

        return $sslInfo
    }
    catch {
        Write-Warning "Error testing SSL certificate expiry: $_"
        return @{
            Url = $Url
            HasValidCertificate = $false
            CertificateExpiry = $null
            DaysUntilExpiry = $null
            CertificateSubject = $null
            CertificateIssuer = $null
            Status = "ERROR"
            Error = $_.Exception.Message
        }
    }
} 



 

 