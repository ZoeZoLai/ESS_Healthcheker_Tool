<#
.SYNOPSIS
    Interactive validation module for targeted health checks
.DESCRIPTION
    Performs health checks on user-selected instances using existing validation functions
.NOTES
    Author: Zoe Lai
    Date: 13/08/2025
    Version: 1.0
#>

function Start-TargetedHealthChecks {
    <#
    .SYNOPSIS
        Runs targeted health checks on user-selected instances
    .DESCRIPTION
        Performs health checks only on the instances selected by the user
    .PARAMETER Instances
        Array of user-selected instances to validate
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject[]]$Instances
    )

    try {
        Write-Host "Starting targeted health checks for selected instances..." -ForegroundColor Cyan
        Write-Host ""

        # Run system-level validation first (always needed)
        Write-Host "=== System-Level Validation ===" -ForegroundColor Magenta
        Start-SystemLevelValidation
        
        # Run instance-specific validation
        Write-Host ""
        Write-Host "=== Instance-Specific Validation ===" -ForegroundColor Magenta
        
        foreach ($instance in $Instances) {
            Write-Host ""
            Write-Host "Validating instance: $($instance.SiteName)$($instance.ApplicationPath)" -ForegroundColor Yellow
            Write-Host "Type: $($instance.InstanceType) | Alias: $($instance.Alias)" -ForegroundColor Gray
            
            Start-InstanceValidation -Instance $instance
        }

        Write-Host ""
        Write-Host "[OK] Targeted health checks completed!" -ForegroundColor Green
    }
    catch {
        Write-Error "Error during targeted health checks: $_"
        throw
    }
}

function Start-SystemLevelValidation {
    <#
    .SYNOPSIS
        Runs system-level validation checks
    .DESCRIPTION
        Performs validation that applies to all instances (OS, hardware, IIS, etc.)
    #>
    [CmdletBinding()]
    param()

    try {
        # Run system requirements validation
        Write-Host "Running system requirements validation..." -ForegroundColor Cyan
        Test-SystemRequirements
        
        # Run infrastructure validation
        Write-Host "Running infrastructure validation..." -ForegroundColor Cyan
        Test-IISConfiguration
        Test-DatabaseConnectivity
        Test-NetworkConnectivity
        Test-SecurityPermissions
    }
    catch {
        Write-Error "Error during system-level validation: $_"
        Add-HealthCheckResult -Category "System Validation" -Check "System-Level Checks" -Status "FAIL" -Message "Error during system validation: $($_.Exception.Message)"
    }
}

function Start-InstanceValidation {
    <#
    .SYNOPSIS
        Runs validation for a specific instance
    .DESCRIPTION
        Performs instance-specific health checks based on instance type
    .PARAMETER Instance
        Instance object to validate
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Instance
    )

    try {
        $siteName = $Instance.SiteName
        $applicationPath = $Instance.ApplicationPath
        $instanceType = $Instance.InstanceType
        $alias = $Instance.Alias
        
        # Create instance identifier for reporting
        $instanceId = "$siteName$applicationPath"
        
        # Validate IIS application pool
        Test-ApplicationPool -Instance $Instance
        
        # Validate physical path and file access
        Test-PhysicalPath -Instance $Instance
        
        # Instance-specific validation
        switch ($instanceType) {
            "ESS" {
                Test-ESSInstance -Instance $Instance
            }
            "WFE" {
                Test-WFEInstance -Instance $Instance
            }
            default {
                Test-UnknownInstance -Instance $Instance
            }
        }
    }
    catch {
        Write-Error "Error during instance validation for $($Instance.SiteName)$($Instance.ApplicationPath): $_"
        Add-HealthCheckResult -Category "Instance Validation" -Check "$instanceId" -Status "FAIL" -Message "Error during instance validation: $($_.Exception.Message)"
    }
}

function Test-ApplicationPool {
    <#
    .SYNOPSIS
        Validates application pool for an instance
    .DESCRIPTION
        Checks application pool status and configuration
    .PARAMETER Instance
        Instance object to validate
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Instance
    )

    try {
        $poolName = $Instance.ApplicationPool
        $instanceId = "$($Instance.SiteName)$($Instance.ApplicationPath)"
        
        # Check if application pool exists
        $pool = Get-IISAppPool -Name $poolName -ErrorAction SilentlyContinue
        if ($pool) {
            Add-HealthCheckResult -Category "Application Pool" -Check "$instanceId - Pool Exists" -Status "PASS" -Message "Application pool '$poolName' exists"
            
            # Check pool status
            if ($pool.State -eq "Started") {
                Add-HealthCheckResult -Category "Application Pool" -Check "$instanceId - Pool Status" -Status "PASS" -Message "Application pool '$poolName' is running"
            } else {
                Add-HealthCheckResult -Category "Application Pool" -Check "$instanceId - Pool Status" -Status "FAIL" -Message "Application pool '$poolName' is not running (State: $($pool.State))"
            }
        } else {
            Add-HealthCheckResult -Category "Application Pool" -Check "$instanceId - Pool Exists" -Status "FAIL" -Message "Application pool '$poolName' not found"
        }
    }
    catch {
        Add-HealthCheckResult -Category "Application Pool" -Check "$instanceId - Pool Validation" -Status "FAIL" -Message "Error validating application pool: $($_.Exception.Message)"
    }
}

function Test-PhysicalPath {
    <#
    .SYNOPSIS
        Validates physical path for an instance
    .DESCRIPTION
        Checks if physical path exists and is accessible
    .PARAMETER Instance
        Instance object to validate
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Instance
    )

    try {
        $physicalPath = $Instance.PhysicalPath
        $instanceId = "$($Instance.SiteName)$($Instance.ApplicationPath)"
        
        if (Test-Path $physicalPath) {
            Add-HealthCheckResult -Category "Physical Path" -Check "$instanceId - Path Exists" -Status "PASS" -Message "Physical path exists: $physicalPath"
            
            # Check if path is accessible
            try {
                $testFile = Join-Path $physicalPath "web.config"
                if (Test-Path $testFile) {
                    Add-HealthCheckResult -Category "Physical Path" -Check "$instanceId - Web.Config" -Status "PASS" -Message "web.config found in physical path"
                } else {
                    Add-HealthCheckResult -Category "Physical Path" -Check "$instanceId - Web.Config" -Status "WARNING" -Message "web.config not found in physical path"
                }
            }
            catch {
                Add-HealthCheckResult -Category "Physical Path" -Check "$instanceId - Path Access" -Status "FAIL" -Message "Cannot access physical path: $($_.Exception.Message)"
            }
        } else {
            Add-HealthCheckResult -Category "Physical Path" -Check "$instanceId - Path Exists" -Status "FAIL" -Message "Physical path does not exist: $physicalPath"
        }
    }
    catch {
        Add-HealthCheckResult -Category "Physical Path" -Check "$instanceId - Path Validation" -Status "FAIL" -Message "Error validating physical path: $($_.Exception.Message)"
    }
}

function Test-ESSInstance {
    <#
    .SYNOPSIS
        Validates ESS-specific components for an instance
    .DESCRIPTION
        Performs ESS-specific health checks including API endpoint validation
    .PARAMETER Instance
        ESS instance object to validate
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Instance
    )

    try {
        $instanceId = "$($Instance.SiteName)$($Instance.ApplicationPath)"
        $essSiteUrl = $Instance.ESSSiteUrl
        
        # Check for ESS configuration files
        $physicalPath = $Instance.PhysicalPath
        $payglobalConfig = Join-Path $physicalPath "payglobal.config"
        
        if (Test-Path $payglobalConfig) {
            Add-HealthCheckResult -Category "ESS Configuration" -Check "$instanceId - PayGlobal.Config" -Status "PASS" -Message "payglobal.config found"
            
            # Parse and validate configuration
            Test-ESSConfiguration -ConfigPath $payglobalConfig -InstanceId $instanceId
        } else {
            Add-HealthCheckResult -Category "ESS Configuration" -Check "$instanceId - PayGlobal.Config" -Status "FAIL" -Message "payglobal.config not found"
        }
        
        # Check web.config encryption if available
        $webConfigPath = Join-Path $physicalPath "web.config"
        if (Test-Path $webConfigPath) {
            Test-WebConfigEncryption -ConfigPath $webConfigPath -InstanceId $instanceId
        }
        
        # API endpoint health check if URL provided
        if ($essSiteUrl -and $essSiteUrl.Trim() -ne "") {
            Test-ESSAPIEndpoint -SiteUrl $essSiteUrl -InstanceId $instanceId
        } else {
            Add-HealthCheckResult -Category "ESS API" -Check "$instanceId - API Endpoint" -Status "INFO" -Message "ESS site URL not provided, skipping API health check"
        }
    }
    catch {
        Add-HealthCheckResult -Category "ESS Validation" -Check "$instanceId - ESS Checks" -Status "FAIL" -Message "Error during ESS validation: $($_.Exception.Message)"
    }
}

function Test-WFEInstance {
    <#
    .SYNOPSIS
        Validates WFE-specific components for an instance
    .DESCRIPTION
        Performs WFE-specific health checks
    .PARAMETER Instance
        WFE instance object to validate
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Instance
    )

    try {
        $instanceId = "$($Instance.SiteName)$($Instance.ApplicationPath)"
        
        # Check for WFE configuration files - only tenants.config is required for WFE
        $physicalPath = $Instance.PhysicalPath
        $tenantsConfig = Join-Path $physicalPath "tenants.config"
        
        # Check for tenants.config (primary WFE config)
        if (Test-Path $tenantsConfig) {
            Add-HealthCheckResult -Category "WFE Configuration" -Check "$instanceId - Tenants.Config" -Status "PASS" -Message "tenants.config found"
            
            # Parse and validate configuration
            Test-WFEConfiguration -ConfigPath $tenantsConfig -InstanceId $instanceId
        } else {
            Add-HealthCheckResult -Category "WFE Configuration" -Check "$instanceId - Tenants.Config" -Status "FAIL" -Message "tenants.config not found"
        }
    }
    catch {
        Add-HealthCheckResult -Category "WFE Validation" -Check "$instanceId - WFE Checks" -Status "FAIL" -Message "Error during WFE validation: $($_.Exception.Message)"
    }
}

function Test-UnknownInstance {
    <#
    .SYNOPSIS
        Validates unknown instance types
    .DESCRIPTION
        Performs basic validation for instances with unknown type
    .PARAMETER Instance
        Unknown instance object to validate
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Instance
    )

    try {
        $instanceId = "$($Instance.SiteName)$($Instance.ApplicationPath)"
        
        Add-HealthCheckResult -Category "Unknown Instance" -Check "$instanceId - Type" -Status "INFO" -Message "Instance type unknown, performing basic validation"
        
        # Basic file checks
        $physicalPath = $Instance.PhysicalPath
        $webConfigPath = Join-Path $physicalPath "web.config"
        
        if (Test-Path $webConfigPath) {
            Add-HealthCheckResult -Category "Unknown Instance" -Check "$instanceId - Web.Config" -Status "PASS" -Message "web.config found"
        } else {
            Add-HealthCheckResult -Category "Unknown Instance" -Check "$instanceId - Web.Config" -Status "WARNING" -Message "web.config not found"
        }
    }
    catch {
        Add-HealthCheckResult -Category "Unknown Instance" -Check "$instanceId - Basic Checks" -Status "FAIL" -Message "Error during basic validation: $($_.Exception.Message)"
    }
}

function Test-ESSConfiguration {
    <#
    .SYNOPSIS
        Validates ESS configuration file
    .DESCRIPTION
        Parses and validates payglobal.config file
    .PARAMETER ConfigPath
        Path to payglobal.config file
    .PARAMETER InstanceId
        Instance identifier for reporting
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigPath,
        
        [Parameter(Mandatory = $true)]
        [string]$InstanceId
    )

    try {
        $configContent = Get-Content $ConfigPath -Raw -ErrorAction Stop
        
        # Check for database connection string using the same pattern as ESSDetection.ps1
        $connectionStringFound = $false
        
        # Pattern used in ESSDetection.ps1: <connection type="sql">...</connection>
        $connectionMatch = [regex]::Match($configContent, '<connection type="sql">([^<]*)</connection>')
        if ($connectionMatch.Success) {
            $connectionStringFound = $true
            $connectionString = $connectionMatch.Groups[1].Value.Trim()
            
            # Parse the connection string to extract server and database info
            $serverMatch = [regex]::Match($connectionString, 'data source=([^;]*)')
            $catalogMatch = [regex]::Match($connectionString, 'initial catalog=([^;]*)')
            
            $serverInfo = if ($serverMatch.Success) { $serverMatch.Groups[1].Value.Trim() } else { "Unknown" }
            $databaseInfo = if ($catalogMatch.Success) { $catalogMatch.Groups[1].Value.Trim() } else { "Unknown" }
            
            Add-HealthCheckResult -Category "ESS Configuration" -Check "$InstanceId - Database Connection" -Status "PASS" -Message "Database connection string found (Server: $serverInfo, Database: $databaseInfo)"
        } else {
            Add-HealthCheckResult -Category "ESS Configuration" -Check "$InstanceId - Database Connection" -Status "WARNING" -Message "Database connection string not found in configuration"
        }
        
        # Check for version information (using the same approach as ESSDetection.ps1)
        # Note: Version information is typically found in the bin folder DLLs, not in payglobal.config
        # This is handled by the existing ESS detection module
        Add-HealthCheckResult -Category "ESS Configuration" -Check "$InstanceId - Version" -Status "INFO" -Message "Version information is extracted from DLL files in the bin folder"
    }
    catch {
        Add-HealthCheckResult -Category "ESS Configuration" -Check "$InstanceId - Config Parsing" -Status "FAIL" -Message "Error parsing configuration file: $($_.Exception.Message)"
    }
}

function Test-WFEConfiguration {
    <#
    .SYNOPSIS
        Validates WFE configuration file
    .DESCRIPTION
        Parses and validates tenants.config file
    .PARAMETER ConfigPath
        Path to tenants.config file
    .PARAMETER InstanceId
        Instance identifier for reporting
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigPath,
        
        [Parameter(Mandatory = $true)]
        [string]$InstanceId
    )

    try {
        $configContent = Get-Content $ConfigPath -Raw -ErrorAction Stop
        
        # Check for tenant configuration
        if ($configContent -match '<tenant') {
            Add-HealthCheckResult -Category "WFE Configuration" -Check "$InstanceId - Tenant Config" -Status "PASS" -Message "Tenant configuration found"
        } else {
            Add-HealthCheckResult -Category "WFE Configuration" -Check "$InstanceId - Tenant Config" -Status "WARNING" -Message "No tenant configuration found"
        }
    }
    catch {
        Add-HealthCheckResult -Category "WFE Configuration" -Check "$InstanceId - Config Parsing" -Status "FAIL" -Message "Error parsing configuration file: $($_.Exception.Message)"
    }
}



function Test-WebConfigEncryption {
    <#
    .SYNOPSIS
        Validates web.config encryption
    .DESCRIPTION
        Checks if web.config is properly encrypted
    .PARAMETER ConfigPath
        Path to web.config file
    .PARAMETER InstanceId
        Instance identifier for reporting
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigPath,
        
        [Parameter(Mandatory = $true)]
        [string]$InstanceId
    )

    try {
        $configContent = Get-Content $ConfigPath -Raw -ErrorAction Stop
        
        # Check for encrypted sections
        if ($configContent -match 'configProtectedData') {
            Add-HealthCheckResult -Category "Web.Config Encryption" -Check "$InstanceId - Encryption" -Status "INFO" -Message "Web.config contains encrypted sections"
        } else {
            Add-HealthCheckResult -Category "Web.Config Encryption" -Check "$InstanceId - Encryption" -Status "INFO" -Message "Web.config is not encrypted"
        }
    }
    catch {
        Add-HealthCheckResult -Category "Web.Config Encryption" -Check "$InstanceId - Encryption Check" -Status "FAIL" -Message "Error checking web.config encryption: $($_.Exception.Message)"
    }
}

function Test-ESSAPIEndpoint {
    <#
    .SYNOPSIS
        Tests ESS API endpoint health
    .DESCRIPTION
        Performs health check on ESS API endpoint using provided URL
    .PARAMETER SiteUrl
        ESS site URL to test
    .PARAMETER InstanceId
        Instance identifier for reporting
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SiteUrl,
        
        [Parameter(Mandatory = $true)]
        [string]$InstanceId
    )

    try {
        # Construct API endpoint URL - use the correct ESS API path
        $apiUrl = "$SiteUrl/api/v1/healthcheck"
        
        Write-Host "Testing ESS API endpoint: $apiUrl" -ForegroundColor Gray
        
        # Test API endpoint
        $response = Invoke-WebRequest -Uri $apiUrl -Method GET -TimeoutSec 30 -ErrorAction Stop
        
        if ($response.StatusCode -eq 200) {
            Add-HealthCheckResult -Category "ESS API" -Check "$InstanceId - API Health" -Status "PASS" -Message "ESS API endpoint responded successfully (Status: $($response.StatusCode))"
            
            # Parse response if possible
            try {
                $apiResponse = $response.Content | ConvertFrom-Json -ErrorAction SilentlyContinue
                if ($apiResponse) {
                    Add-HealthCheckResult -Category "ESS API" -Check "$InstanceId - API Response" -Status "INFO" -Message "API returned valid JSON response"
                }
            }
            catch {
                Add-HealthCheckResult -Category "ESS API" -Check "$InstanceId - API Response" -Status "WARNING" -Message "API response is not valid JSON"
            }
        } else {
            Add-HealthCheckResult -Category "ESS API" -Check "$InstanceId - API Health" -Status "FAIL" -Message "ESS API endpoint returned status code: $($response.StatusCode)"
        }
    }
    catch {
        Add-HealthCheckResult -Category "ESS API" -Check "$InstanceId - API Health" -Status "FAIL" -Message "Error testing ESS API endpoint: $($_.Exception.Message)"
    }
}
