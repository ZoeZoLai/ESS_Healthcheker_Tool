# ESS Health Check API Functions
# This module contains functions for performing health checks via the ESS API

function Get-ESSHealthCheckViaAPI {
    <#
    .SYNOPSIS
        Get ESS health check information via API (simplified for localhost)
    .DESCRIPTION
        Performs a health check on the ESS API endpoint and returns detailed health information
        for specific components: PayGlobal database, SelfService software, SelfService database,
        the Bridge, the WFE database, Bridge communication, and Workflow Endpoints.
        Simplified for localhost calls.
    .PARAMETER SiteName
        The IIS site name
    .PARAMETER ApplicationPath
        The application path
    .PARAMETER Protocol
        The protocol to use (http or https, defaults to http for localhost)
    .PARAMETER Port
        The port number to use
    .PARAMETER TimeoutSeconds
        Timeout in seconds for API requests (default: 60 seconds - increased from 30)
    .PARAMETER MaxRetries
        Maximum number of retry attempts for failed requests (default: 2)
    .PARAMETER RetryDelaySeconds
        Delay between retry attempts in seconds (default: 5)
    .EXAMPLE
        Get-ESSHealthCheckViaAPI -SiteName "Default Web Site" -ApplicationPath "/Self-Service/NZ_ESS"
    .EXAMPLE
        Get-ESSHealthCheckViaAPI -SiteName "Default Web Site" -ApplicationPath "Self-Service/NZ_ESS" -TimeoutSeconds 120 -MaxRetries 3
    .RETURNS
        PSCustomObject containing health check results
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SiteName,
        
        [Parameter(Mandatory = $true)]
        [string]$ApplicationPath,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("http", "https")]
        [string]$Protocol = "http",
        
        [Parameter(Mandatory = $false)]
        [int]$Port,
        
        [Parameter(Mandatory = $false)]
        [int]$TimeoutSeconds = 60,  # Increased default timeout from 30 to 60 seconds
        
        [Parameter(Mandatory = $false)]
        [int]$MaxRetries = 2,  # Add retry capability
        
        [Parameter(Mandatory = $false)]
        [int]$RetryDelaySeconds = 5  # Add retry delay
    )
    
    try {
        Write-Verbose "Getting ESS health check via API for $SiteName$ApplicationPath (Timeout: ${TimeoutSeconds}s, MaxRetries: $MaxRetries)"
        
        # Build URI for localhost
        $uriBuilder = @{
            Scheme = $Protocol
            Host = "localhost"
            Port = if ($Port) { $Port } else { if ($Protocol -eq "https") { 443 } else { 80 } }
            Application = $ApplicationPath.TrimStart('/')
            Endpoint = "api/v1/healthcheck"
        }
        
        $portString = if ($uriBuilder.Port -ne 80 -and $uriBuilder.Port -ne 443) { ":$($uriBuilder.Port)" } else { "" }
        $fullUri = "$($uriBuilder.Scheme)://$($uriBuilder.Host)$portString/$($uriBuilder.Application)/$($uriBuilder.Endpoint)"
        
        Write-Verbose "Health check URI: $fullUri"
        
        # Initialize health check result object
        $healthCheckResult = @{
            Uri = $fullUri
            StatusCode = $null
            ResponseContent = $null
            ContentType = $null
            Success = $false
            Components = @()
            OverallStatus = "Unknown"
            Error = $null
            RawResponse = $null
            Summary = @{
                TotalComponents = 0
                HealthyComponents = 0
                UnhealthyComponents = 0
                HasVersionInfo = $false
                HasComponentMessages = $false
            }
            PayGlobalDatabase = $null
            SelfServiceSoftware = $null
            SelfServiceDatabase = $null
            Bridge = $null
            WFEDatabase = $null
            BridgeCommunication = $null
            WorkflowEndpoints = $null
            HTTPStatusInterpretation = $null
            ComponentMessages = @()
            ESSInstance = $null  # Initialize ESSInstance property
            RetryAttempts = 0  # Track retry attempts
        }
        
        # Add debugging information
        Write-Verbose "Testing connectivity to: $fullUri"
        Write-Verbose "Protocol: $Protocol, Port: $($uriBuilder.Port)"
        
        # Skip basic connectivity test for performance - go directly to HTTP request
        Write-Verbose "Skipping connectivity test for performance optimization"
        
        # Initialize response variables
        $responseContent = $null
        $statusCode = $null
        $contentType = $null
        
        # Retry logic for HTTP requests
        $attempt = 0
        $lastException = $null
        
        do {
            $attempt++
            $healthCheckResult.RetryAttempts = $attempt - 1
            
            if ($attempt -gt 1) {
                Write-Verbose "Retry attempt $attempt of $MaxRetries (after $RetryDelaySeconds second delay)"
                Start-Sleep -Seconds $RetryDelaySeconds
            }
            
            # Use Invoke-WebRequest with retry logic
            try {
                Write-Verbose "Making request with Invoke-WebRequest (attempt $attempt)..."
                
                # Validate URI before making request
                if ([string]::IsNullOrEmpty($fullUri)) {
                    throw "URI is null or empty"
                }
                
                $webRequestParams = @{
                    Uri = $fullUri
                    Method = "GET"
                    TimeoutSec = $TimeoutSeconds  # Use configurable timeout parameter
                    Headers = @{
                        "Accept" = "application/json, application/xml, text/xml"
                        "User-Agent" = "PowerShell-ESSHealthCheck/1.0"
                    }
                }
                
                # Disable SSL certificate validation for localhost
                if ($Protocol -eq "https") {
                    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
                }
                
                Write-Verbose "Making request to: $fullUri (attempt $attempt)"
                $response = Invoke-WebRequest @webRequestParams -ErrorAction Stop
                
                if ($null -eq $response) {
                    throw "Response is null"
                }
                
                $responseContent = $response.Content
                $statusCode = $response.StatusCode
                $contentType = $response.Headers["Content-Type"]
                
                Write-Verbose "Invoke-WebRequest successful - Status: $statusCode, Content Length: $($responseContent.Length)"
                
                # If we get here, the request was successful, so break out of retry loop
                break
            }
            catch {
                $lastException = $_
                Write-Verbose "Request attempt $attempt failed: $($_.Exception.Message)"
                
                # Check if this is a retryable error
                $isRetryable = $false
                if ($_.Exception.Message -like "*timeout*" -or 
                    $_.Exception.Message -like "*connection*" -or
                    $_.Exception.Message -like "*network*" -or
                    $_.Exception.Message -like "*temporarily*" -or
                    $_.Exception.Message -like "*service unavailable*") {
                    $isRetryable = $true
                }
                
                # Don't retry on 404 errors (endpoint doesn't exist)
                if ($_.Exception.Message -like "*404*" -or $_.Exception.Message -like "*Not Found*") {
                    $isRetryable = $false
                }
                
                if ($attempt -lt $MaxRetries -and $isRetryable) {
                    Write-Verbose "Retryable error detected, will retry..."
                    continue
                } else {
                    Write-Verbose "Non-retryable error or max retries reached, failing"
                    break
                }
            }
        } while ($attempt -le $MaxRetries)
        
        # If all attempts failed, throw the last exception
        if ($null -eq $responseContent) {
            throw "HTTP request failed after $attempt attempts: $($lastException.Exception.Message)"
        }
        
        # Update health check result with response data
        $healthCheckResult.StatusCode = $statusCode
        $healthCheckResult.ResponseContent = $responseContent
        $healthCheckResult.ContentType = $contentType
        
        # Interpret HTTP status code
        switch ($statusCode) {
            200 {
                $healthCheckResult.HTTPStatusInterpretation = "OK - Site is up and all components are healthy"
                $healthCheckResult.OverallStatus = "Healthy"
            }
            500 {
                $healthCheckResult.HTTPStatusInterpretation = "Site is down (e.g., Bridge Component version issue)"
                $healthCheckResult.OverallStatus = "Unhealthy"
                $healthCheckResult.Error = "Site is down - HTTP 500 error"
            }
            503 {
                $healthCheckResult.HTTPStatusInterpretation = "Parts of the site are down, indicated by the JSON payload content"
                $healthCheckResult.OverallStatus = "Partially Unhealthy"
            }
            default {
                $healthCheckResult.HTTPStatusInterpretation = "Unexpected HTTP status code: $statusCode"
                $healthCheckResult.OverallStatus = "Unknown"
                $healthCheckResult.Error = "Unexpected HTTP status code: $statusCode"
            }
        }
        
        # Parse response based on content type
        if ($responseContent -match '^\s*\{' -or $contentType -like "*json*") {
            # JSON response
            try {
                $jsonResponse = $responseContent | ConvertFrom-Json
                $healthCheckResult.RawResponse = $jsonResponse
                
                # Extract overall success status from JSON
                if ($jsonResponse.PSObject.Properties.Name -contains "Successful") {
                    $healthCheckResult.Success = $jsonResponse.Successful
                    
                    # Override overall status based on JSON response if available
                    if ($jsonResponse.Successful) {
                        $healthCheckResult.OverallStatus = "Healthy"
                    } else {
                        $healthCheckResult.OverallStatus = "Unhealthy"
                    }
                }
                
                # Extract components and their messages
                if ($jsonResponse.Components) {
                    $healthCheckResult.Components = $jsonResponse.Components | ForEach-Object {
                        $component = @{
                            Name = $_.ComponentName
                            Version = $_.ComponentVersion
                            Status = if ($_.Successful) { "Healthy" } else { "Unhealthy" }
                            Messages = @()
                        }
                        
                        # Extract component messages with type and detail
                        if ($_.ComponentMessages) {
                            foreach ($message in $_.ComponentMessages) {
                                if ($message.PSObject.Properties.Name -contains "Type" -and $message.PSObject.Properties.Name -contains "Message") {
                                    $component.Messages += @{
                                        Type = $message.Type
                                        Detail = $message.Message
                                        FullMessage = "$($message.Type): $($message.Message)"
                                    }
                                } else {
                                    # Handle simple string messages
                                    $component.Messages += @{
                                        Type = "Info"
                                        Detail = $message
                                        FullMessage = $message
                                    }
                                }
                            }
                        }
                        
                        $component
                    }
                    
                    # Extract specific component information
                    $healthCheckResult = Get-ComponentInfo -HealthCheckResult $healthCheckResult -Components $jsonResponse.Components
                    
                    # Collect all component messages for summary
                    $healthCheckResult.ComponentMessages = $healthCheckResult.Components | ForEach-Object {
                        if ($_.Messages.Count -gt 0) {
                            $_.Messages | ForEach-Object { $_.FullMessage }
                        }
                    } | Where-Object { $_ } | Sort-Object -Unique
                }
                
                Write-Verbose "Successfully parsed JSON response with $($healthCheckResult.Components.Count) components"
            }
            catch {
                $healthCheckResult.Error = "Failed to parse JSON response: $($_.Exception.Message)"
                Write-Warning "Failed to parse JSON response: $_"
            }
        }
        elseif ($responseContent -match '^\s*<' -or $contentType -like "*xml*") {
            # XML response
            try {
                Write-Verbose "Parsing XML response..."
                $xmlResponse = [xml]$responseContent
                $healthCheckResult.RawResponse = $xmlResponse
                
                # Parse XML response structure
                $overallSuccess = $xmlResponse.HealthCheckResponse.Successful
                $healthCheckResult.Success = if ($overallSuccess -eq "true") { $true } else { $false }
                
                # Override overall status based on XML response
                if ($healthCheckResult.Success) {
                    $healthCheckResult.OverallStatus = "Healthy"
                } else {
                    $healthCheckResult.OverallStatus = "Unhealthy"
                }
                
                # Extract components from XML
                if ($xmlResponse.HealthCheckResponse.Components.Component) {
                    $components = $xmlResponse.HealthCheckResponse.Components.Component | ForEach-Object {
                        $componentName = $_.ComponentName
                        $componentVersion = $_.ComponentVersion
                        $componentSuccess = $_.Successful
                        $componentMessages = $_.ComponentMessages
                        
                        Write-Verbose "Processing component: $componentName (v$componentVersion, Success: $componentSuccess)"
                        
                        @{
                            Name = $componentName
                            Version = $componentVersion
                            Status = if ($componentSuccess -eq "true") { "Healthy" } else { "Unhealthy" }
                            Messages = @()
                        }
                    }
                    
                    # Extract specific component information
                    $healthCheckResult = Get-ComponentInfo -HealthCheckResult $healthCheckResult -Components $components
                } else {
                    Write-Verbose "No components found in XML response"
                }
                
                Write-Verbose "Successfully parsed XML response with $($healthCheckResult.Components.Count) components"
            }
            catch {
                $healthCheckResult.Error = "Failed to parse XML response: $($_.Exception.Message)"
                Write-Warning "Failed to parse XML response: $_"
                Write-Verbose "Raw response content: $responseContent"
            }
        }
        else {
            $healthCheckResult.Error = "Unknown response format. Content-Type: $contentType"
            Write-Warning "Unknown response format. Content-Type: $contentType"
        }
        
        # Add summary information
        $healthCheckResult.Summary = @{
            TotalComponents = $healthCheckResult.Components.Count
            HealthyComponents = ($healthCheckResult.Components | Where-Object { $_.Status -eq "Healthy" }).Count
            UnhealthyComponents = ($healthCheckResult.Components | Where-Object { $_.Status -eq "Unhealthy" }).Count
            HasVersionInfo = ($healthCheckResult.Components | Where-Object { $_.Version }).Count -gt 0
            HasComponentMessages = $healthCheckResult.ComponentMessages.Count -gt 0
        }
        
        return [PSCustomObject]$healthCheckResult
        
    }
    catch {
        $errorResult = @{
            Uri = if ($fullUri) { $fullUri } else { "Unknown" }
            StatusCode = "Error"
            ResponseContent = $null
            ContentType = $null
            Success = $false
            Components = @()
            OverallStatus = "Error"
            Error = $_.Exception.Message
            RawResponse = $null
            Summary = @{
                TotalComponents = 0
                HealthyComponents = 0
                UnhealthyComponents = 0
                HasVersionInfo = $false
                HasComponentMessages = $false
            }
            PayGlobalDatabase = $null
            SelfServiceSoftware = $null
            SelfServiceDatabase = $null
            Bridge = $null
            WFEDatabase = $null
            BridgeCommunication = $null
            WorkflowEndpoints = $null
            HTTPStatusInterpretation = "Error occurred during request"
            ComponentMessages = @()
            ESSInstance = $null  # Add ESSInstance property to error result
        }
        
        Write-Warning "Error calling ESS health check API: $_"
        return [PSCustomObject]$errorResult
    }
}

function Get-ComponentInfo {
    <#
    .SYNOPSIS
        Gets specific component information from health check response
    .DESCRIPTION
        Parses the health check response to get information for specific components:
        PayGlobal database, SelfService software, SelfService database, Bridge, WFE database, 
        Bridge communication, and Workflow Endpoints
    .PARAMETER HealthCheckResult
        The health check result object to populate
    .PARAMETER Components
        Array of components from the API response
    .RETURNS
        Updated health check result object with specific component information
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$HealthCheckResult,
        
        [Parameter(Mandatory = $true)]
        [array]$Components
    )
    
    try {
        foreach ($component in $Components) {
            $componentName = $component.ComponentName
            $componentVersion = $component.ComponentVersion
            $componentStatus = if ($component.Successful) { "Healthy" } else { "Unhealthy" }
            $componentMessages = $component.ComponentMessages
            
            # Map component names to specific properties
            if ($componentName -like "*PayGlobal*Database*" -or $componentName -like "*PayGlobal*DB*") {
                $HealthCheckResult.PayGlobalDatabase = @{
                    Name = $componentName
                    Version = $componentVersion
                    Status = $componentStatus
                    Messages = $componentMessages
                }
            }
            elseif ($componentName -like "*SelfService*Software*" -or $componentName -like "*SelfService*App*" -or $componentName -like "*ESS*") {
                $HealthCheckResult.SelfServiceSoftware = @{
                    Name = $componentName
                    Version = $componentVersion
                    Status = $componentStatus
                    Messages = $componentMessages
                }
            }
            elseif ($componentName -like "*SelfService*Database*" -or $componentName -like "*SelfService*DB*") {
                $HealthCheckResult.SelfServiceDatabase = @{
                    Name = $componentName
                    Version = $componentVersion
                    Status = $componentStatus
                    Messages = $componentMessages
                }
            }
            elseif ($componentName -like "*Bridge*" -and $componentName -notlike "*Communication*") {
                $HealthCheckResult.Bridge = @{
                    Name = $componentName
                    Version = $componentVersion
                    Status = $componentStatus
                    Messages = $componentMessages
                }
            }
            elseif ($componentName -like "*WFE*Database*" -or $componentName -like "*WFE*DB*") {
                $HealthCheckResult.WFEDatabase = @{
                    Name = $componentName
                    Version = $componentVersion
                    Status = $componentStatus
                    Messages = $componentMessages
                }
            }
            elseif ($componentName -like "*Bridge*Communication*" -or $componentName -like "*Communication*") {
                $HealthCheckResult.BridgeCommunication = @{
                    Name = $componentName
                    Version = $componentVersion
                    Status = $componentStatus
                    Messages = $componentMessages
                }
            }
            elseif ($componentName -like "*Workflow*Endpoint*" -or $componentName -like "*Workflow*endpoint*") {
                $HealthCheckResult.WorkflowEndpoints = @{
                    Name = $componentName
                    Version = $componentVersion
                    Status = $componentStatus
                    Messages = $componentMessages
                }
            }
        }
        return $HealthCheckResult
    }
    catch {
        Write-Warning "Error extracting component information: $_"
        return $HealthCheckResult
    }
}

function Test-ESSHealthCheckEndpoint {
    <#
    .SYNOPSIS
        Test if the ESS health check endpoint is accessible and working (simplified for localhost)
    .DESCRIPTION
        Tests the health check endpoint to verify it's accessible and returns valid responses.
        Simplified for localhost calls and focused on the specific ESS components.
    .PARAMETER SiteName
        The IIS site name to test
    .PARAMETER ApplicationPath
        The application path to test
    .PARAMETER Protocol
        The protocol to test (http or https, defaults to http for localhost)
    .PARAMETER Port
        The port number to test
    .EXAMPLE
        Test-ESSHealthCheckEndpoint -SiteName "Default Web Site" -ApplicationPath "/Self-Service/NZ_ESS"
    .RETURNS
        PSCustomObject containing test results
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SiteName,
        
        [Parameter(Mandatory = $true)]
        [string]$ApplicationPath,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("http", "https")]
        [string]$Protocol = "http",
        
        [Parameter(Mandatory = $false)]
        [int]$Port,
        
        [Parameter(Mandatory = $false)]
        [int]$TimeoutSeconds = 30
    )
    
    try {
        Write-Host "Testing ESS health check endpoint accessibility..." -ForegroundColor Yellow
        
        $testResults = @{
            SiteName = $SiteName
            ApplicationPath = $ApplicationPath
            Protocol = $Protocol
            Port = $Port
            HostName = "localhost"
            EndpointAccessible = $false
            HealthCheckWorking = $false
            Uri = $null
            TestResults = @()
            Recommendations = @()
            ComponentStatus = @{}
        }
        
        # Test 1: Basic connectivity
        Write-Host "Test 1: Testing basic connectivity..." -ForegroundColor Cyan
        
        $uriBuilder = @{
            Scheme = $Protocol
            Host = "localhost"
            Port = if ($Port) { $Port } else { if ($Protocol -eq "https") { 443 } else { 80 } }
            Application = $ApplicationPath.TrimStart('/')
            Endpoint = "api/v1/healthcheck"
        }
        
        $portString = if ($uriBuilder.Port -ne 80 -and $uriBuilder.Port -ne 443) { ":$($uriBuilder.Port)" } else { "" }
        $fullUri = "$($uriBuilder.Scheme)://$($uriBuilder.Host)$portString/$($uriBuilder.Application)/$($uriBuilder.Endpoint)"
        $testResults.Uri = $fullUri
        
        Write-Host "Testing URI: $fullUri" -ForegroundColor Gray
        
        # Test basic HTTP connectivity
        try {
            $request = [System.Net.WebRequest]::Create($fullUri)
            $request.Method = "GET"
            $request.Timeout = ($TimeoutSeconds * 1000)  # Convert seconds to milliseconds for WebRequest
            $request.Accept = "application/json, application/xml, text/xml"
            
            $response = $request.GetResponse()
            $response.Close()
            $testResults.EndpointAccessible = $true
            $testResults.TestResults += @{
                Test = "Basic Connectivity"
                Status = "PASS"
                Message = "Endpoint is accessible"
                Details = "HTTP Status: $($response.StatusCode)"
            }
            Write-Host "PASS - Basic connectivity test passed" -ForegroundColor Green
        }
        catch {
            $testResults.TestResults += @{
                Test = "Basic Connectivity"
                Status = "FAIL"
                Message = "Endpoint is not accessible"
                Details = "Error: $($_.Exception.Message)"
            }
            Write-Host "FAIL - Basic connectivity test failed: $($_.Exception.Message)" -ForegroundColor Red
            $testResults.Recommendations += "Check if the site is running and accessible"
            $testResults.Recommendations += "Verify the application path is correct"
            $testResults.Recommendations += "Check IIS application pool status"
            return [PSCustomObject]$testResults
        }
        
        # Test 2: Health check API functionality
        Write-Host "Test 2: Testing health check API functionality..." -ForegroundColor Cyan
        
        try {
            $healthCheckResult = Get-ESSHealthCheckViaAPI -SiteName $SiteName -ApplicationPath $ApplicationPath -Protocol $Protocol -Port $Port -TimeoutSeconds $TimeoutSeconds
            
            if ($null -ne $healthCheckResult.Success) {
                $testResults.HealthCheckWorking = $true
                $testResults.TestResults += @{
                    Test = "Health Check API"
                    Status = "PASS"
                    Message = "Health check API is working"
                    Details = "Overall Status: $($healthCheckResult.OverallStatus), Components: $($healthCheckResult.Summary.TotalComponents)"
                }
                Write-Host "PASS - Health check API test passed" -ForegroundColor Green
                
                # Extract component status information
                $testResults.ComponentStatus = @{
                    PayGlobalDatabase = $healthCheckResult.PayGlobalDatabase
                    SelfServiceSoftware = $healthCheckResult.SelfServiceSoftware
                    SelfServiceDatabase = $healthCheckResult.SelfServiceDatabase
                    Bridge = $healthCheckResult.Bridge
                    WFEDatabase = $healthCheckResult.WFEDatabase
                    BridgeCommunication = $healthCheckResult.BridgeCommunication
                }
                
                # Display component details
                if ($healthCheckResult.Components.Count -gt 0) {
                    Write-Host "Components found:" -ForegroundColor Gray
                    foreach ($component in $healthCheckResult.Components) {
                        $statusColor = if ($component.Status -eq "Healthy") { "Green" } else { "Red" }
                        Write-Host "  - $($component.Name): $($component.Status) (v$($component.Version))" -ForegroundColor $statusColor
                    }
                }
            }
            else {
                $testResults.TestResults += @{
                    Test = "Health Check API"
                    Status = "FAIL"
                    Message = "Health check API returned invalid response"
                    Details = "Error: $($healthCheckResult.Error)"
                }
                Write-Host "FAIL - Health check API test failed: $($healthCheckResult.Error)" -ForegroundColor Red
            }
        }
        catch {
            $testResults.TestResults += @{
                Test = "Health Check API"
                Status = "FAIL"
                Message = "Health check API test failed"
                Details = "Exception: $($_.Exception.Message)"
            }
            Write-Host "FAIL - Health check API test failed: $($_.Exception.Message)" -ForegroundColor Red
        }
        
        # Generate recommendations
        if ($testResults.HealthCheckWorking) {
            $testResults.Recommendations += "Health check endpoint is working correctly"
            $testResults.Recommendations += "Use Get-ESSHealthCheckViaAPI function for regular health checks"
            $testResults.Recommendations += "Consider implementing automated monitoring using this endpoint"
        }
        else {
            $testResults.Recommendations += "Verify the application path and site configuration"
            $testResults.Recommendations += "Check IIS application pool status"
            $testResults.Recommendations += "Verify the health check API is enabled in the application"
        }
        
        return [PSCustomObject]$testResults
        
    }
    catch {
        Write-Warning "Error testing ESS health check endpoint: $_"
        return @{
            SiteName = $SiteName
            ApplicationPath = $ApplicationPath
            Protocol = $Protocol
            Port = $Port
            HostName = "localhost"
            EndpointAccessible = $false
            HealthCheckWorking = $false
            Uri = $null
            TestResults = @()
            Recommendations = @("Error occurred during testing: $($_.Exception.Message)")
            ComponentStatus = @{}
        }
    }
}

function Get-ESSHealthCheckForAllInstances {
    <#
    .SYNOPSIS
        Get health check information for all discovered ESS instances
    .DESCRIPTION
        Automatically discovers ESS instances and performs health checks for each one.
        Returns comprehensive health information for all components.
    .PARAMETER UseGlobalDetection
        Whether to use global detection results (default: true)
    .PARAMETER TimeoutSeconds
        Timeout in seconds for API requests (default: 90 seconds - increased for better reliability)
    .PARAMETER MaxRetries
        Maximum number of retry attempts for failed requests (default: 2)
    .PARAMETER RetryDelaySeconds
        Delay between retry attempts in seconds (default: 5)
    .EXAMPLE
        Get-ESSHealthCheckForAllInstances
    .EXAMPLE
        Get-ESSHealthCheckForAllInstances -TimeoutSeconds 120 -MaxRetries 3
    .RETURNS
        Array of health check results for all ESS instances
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [bool]$UseGlobalDetection = $true,
        
        [Parameter(Mandatory = $false)]
        [int]$TimeoutSeconds = 90,  # Increased default timeout from 30 to 90 seconds
        
        [Parameter(Mandatory = $false)]
        [int]$MaxRetries = 2,  # Add retry capability
        
        [Parameter(Mandatory = $false)]
        [int]$RetryDelaySeconds = 5  # Add retry delay
    )
    
    try {
        Write-Host "Getting health check information for all ESS instances..." -ForegroundColor Yellow
        
        $allHealthChecks = @()
        
        # Get ESS instances from global detection or discover them
        $essInstances = @()
        if ($UseGlobalDetection -and $global:DetectionResults -and $global:DetectionResults.ESSInstances) {
            $essInstances = $global:DetectionResults.ESSInstances
            Write-Host "Using $($essInstances.Count) ESS instances from global detection results" -ForegroundColor Cyan
        }
        else {
            # Import the discovery function from ESSDetection module
            $essInstances = Find-ESSInstances
            Write-Host "Discovered $($essInstances.Count) ESS instances" -ForegroundColor Cyan
        }
        
        if ($essInstances.Count -eq 0) {
            Write-Host "No ESS instances found for health check" -ForegroundColor Yellow
            return $allHealthChecks
        }
        
        foreach ($ess in $essInstances) {
            Write-Host "Checking health for ESS instance: $($ess.SiteName)$($ess.ApplicationPath)" -ForegroundColor Gray
            
            try {
                $healthCheck = Get-ESSHealthCheckViaAPI -SiteName $ess.SiteName -ApplicationPath $ess.ApplicationPath -TimeoutSeconds $TimeoutSeconds -MaxRetries $MaxRetries -RetryDelaySeconds $RetryDelaySeconds
                
                # Add ESS instance information to the health check result
                $healthCheck.ESSInstance = @{
                    SiteName = $ess.SiteName
                    ApplicationPath = $ess.ApplicationPath
                    PhysicalPath = $ess.PhysicalPath
                    ApplicationPool = $ess.ApplicationPool
                    DatabaseServer = $ess.DatabaseServer
                    DatabaseName = $ess.DatabaseName
                    TenantID = $ess.TenantID
                }
                
                $allHealthChecks += $healthCheck
                
                # Display summary
                $statusColor = if ($healthCheck.Success) { "Green" } else { "Red" }
                Write-Host " Status: $($healthCheck.OverallStatus)" -ForegroundColor $statusColor
                Write-Host " Components: $($healthCheck.Summary.TotalComponents) total, $($healthCheck.Summary.HealthyComponents) healthy" -ForegroundColor Gray
            }
            catch {
                $errorMessage = $_.Exception.Message
                if ($errorMessage -like "*timeout*") {
                    Write-Warning "Error checking health for ESS instance $($ess.SiteName)$($ess.ApplicationPath): Request timed out after $TimeoutSeconds seconds with $MaxRetries retry attempts. This may indicate the ESS application is under heavy load or experiencing issues."
                } elseif ($errorMessage -like "*404*" -or $errorMessage -like "*Not Found*") {
                    Write-Warning "Error checking health for ESS instance $($ess.SiteName)$($ess.ApplicationPath): Endpoint not found (404). This may indicate the ESS application is not properly configured or the API endpoint is not available."
                } else {
                    Write-Warning "Error checking health for ESS instance $($ess.SiteName)$($ess.ApplicationPath): $errorMessage"
                }
                
                # Add error result
                $errorHealthCheck = @{
                    Uri = "Error"
                    StatusCode = "Error"
                    Success = $false
                    OverallStatus = "Error"
                    Error = $_.Exception.Message
                    ESSInstance = @{
                        SiteName = $ess.SiteName
                        ApplicationPath = $ess.ApplicationPath
                        PhysicalPath = $ess.PhysicalPath
                        ApplicationPool = $ess.ApplicationPool
                        DatabaseServer = $ess.DatabaseServer
                        DatabaseName = $ess.DatabaseName
                        TenantID = $ess.TenantID
                    }
                    Components = @()
                    Summary = @{
                        TotalComponents = 0
                        HealthyComponents = 0
                        UnhealthyComponents = 0
                        HasVersionInfo = $false
                        HasComponentMessages = $false
                    }
                    PayGlobalDatabase = $null
                    SelfServiceSoftware = $null
                    SelfServiceDatabase = $null
                    Bridge = $null
                    WFEDatabase = $null
                    BridgeCommunication = $null
                    WorkflowEndpoints = $null
                    HTTPStatusInterpretation = "Error occurred during request"
                    ComponentMessages = @()
                }
                
                $allHealthChecks += [PSCustomObject]$errorHealthCheck
                
                # Display summary for error case
                Write-Host " Status: Error" -ForegroundColor Red
                Write-Host " Components: 0 total, 0 healthy" -ForegroundColor Gray
            }
        }
        
        Write-Host "Completed health checks for $($allHealthChecks.Count) ESS instances" -ForegroundColor Green
        return $allHealthChecks
        
    }
    catch {
        Write-Warning "Error getting health check for all instances: $_"
        return @()
    }
}

function Add-APIHealthCheckResults {
    <#
    .SYNOPSIS
        Add API health check results to the global health check results
    .DESCRIPTION
        Processes API health check results and adds them to the global health check results
        for reporting purposes.
    .PARAMETER HealthChecks
        Array of health check results from API calls
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$HealthChecks
    )
    
    try {
        Write-Verbose "Adding API health check results to global results..."
        
        foreach ($healthCheck in $HealthChecks) {
            # Handle cases where healthCheck might be an error object
            if (-not $healthCheck -or $healthCheck -is [System.Management.Automation.ErrorRecord]) {
                Write-Warning "Skipping invalid health check result"
                continue
            }
            
            $siteIdentifier = if ($healthCheck.ESSInstance) {
                "$($healthCheck.ESSInstance.SiteName)$($healthCheck.ESSInstance.ApplicationPath)"
            } else {
                "Unknown"
            }
            
            # Add overall health check result with error handling
            try {
                if ($healthCheck.Success) {
                    $summaryMessage = "ESS instance $siteIdentifier is healthy"
                    if ($healthCheck.Summary) {
                        $summaryMessage += ". Components: $($healthCheck.Summary.TotalComponents) total, $($healthCheck.Summary.HealthyComponents) healthy"
                    }
                    Add-HealthCheckResult -Category "ESS API Health Check" -Check "Overall Status - $siteIdentifier" -Status "PASS" -Message $summaryMessage
                } else {
                    $errorMessage = "ESS instance $siteIdentifier health check failed"
                    if ($healthCheck.Error) {
                        $errorMessage += ": $($healthCheck.Error)"
                    }
                    Add-HealthCheckResult -Category "ESS API Health Check" -Check "Overall Status - $siteIdentifier" -Status "FAIL" -Message $errorMessage
                }
            }
            catch {
                Write-Warning "Error adding overall health check result for $siteIdentifier - $($_.Exception.Message)"
            }
            
            # Add specific component results
            $components = @(
                @{ Name = "PayGlobal Database"; Data = $healthCheck.PayGlobalDatabase },
                @{ Name = "SelfService Software"; Data = $healthCheck.SelfServiceSoftware },
                @{ Name = "SelfService Database"; Data = $healthCheck.SelfServiceDatabase },
                @{ Name = "Bridge"; Data = $healthCheck.Bridge },
                @{ Name = "WFE Database"; Data = $healthCheck.WFEDatabase },
                @{ Name = "Bridge Communication"; Data = $healthCheck.BridgeCommunication },
                @{ Name = "Workflow Endpoints"; Data = $healthCheck.WorkflowEndpoints }
            )
            
            foreach ($component in $components) {
                try {
                    if ($component.Data) {
                        $status = if ($component.Data.Status -eq "Healthy") { "PASS" } else { "FAIL" }
                        $message = "$($component.Name) is $($component.Data.Status)"
                        if ($component.Data.Version) {
                            $message += " (v$($component.Data.Version))"
                        }
                        if ($component.Data.Messages) {
                            $message += ". Messages: $($component.Data.Messages -join ', ')"
                        }
                        
                        Add-HealthCheckResult -Category "ESS API Components" -Check "$($component.Name) - $siteIdentifier" -Status $status -Message $message
                    }
                }
                catch {
                    Write-Warning "Error adding component result for $($component.Name) - $siteIdentifier - $($_.Exception.Message)"
                }
            }
        }
        
        Write-Verbose "Successfully added API health check results"
    }
    catch {
        Write-Warning "Error adding API health check results: $_"
        Write-Verbose "Exception details: $($_.Exception.Message)"
        Write-Verbose "Stack trace: $($_.ScriptStackTrace)"
    }
} 