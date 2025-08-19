# ESS API Health Check Timeout Improvements

## Overview

The ESS API health check functionality has been enhanced to address intermittent timeout issues and improve reliability. The improvements include increased default timeouts, retry logic, and better error handling.

## Issues Addressed

### 1. **Inconsistent API Response Times**
- **Problem**: ESS API endpoints sometimes respond slowly due to server load, database queries, or network issues
- **Solution**: Increased default timeout from 30 seconds to 60 seconds (individual) and 90 seconds (batch)

### 2. **No Retry Mechanism**
- **Problem**: Failed requests due to temporary issues would fail immediately
- **Solution**: Added configurable retry logic with smart error detection

### 3. **Poor Error Diagnostics**
- **Problem**: Generic error messages made troubleshooting difficult
- **Solution**: Enhanced error messages with specific recommendations

## Improvements Made

### 1. **Enhanced Timeout Settings**

#### Individual API Calls (`Get-ESSHealthCheckViaAPI`)
- **Default Timeout**: Increased from 30 to 60 seconds
- **Configurable**: Can be set via `-TimeoutSeconds` parameter
- **Retry Logic**: Up to 2 retry attempts with 5-second delays

#### Batch API Calls (`Get-ESSHealthCheckForAllInstances`)
- **Default Timeout**: Increased from 30 to 90 seconds
- **Configurable**: Can be set via `-TimeoutSeconds` parameter
- **Retry Logic**: Same retry settings as individual calls

### 2. **Smart Retry Logic**

The retry mechanism intelligently determines which errors to retry:

#### Retryable Errors
- Timeout errors
- Connection errors
- Network errors
- Temporary service unavailability

#### Non-Retryable Errors
- 404 Not Found (endpoint doesn't exist)
- Authentication errors
- Permanent configuration issues

### 3. **Configuration Options**

Settings can be configured in `src/Config.ps1`:

```powershell
APIHealthCheck = @{
    DefaultTimeoutSeconds = 90
    MaxRetries = 2
    RetryDelaySeconds = 5
    ConnectionTimeoutSeconds = 30
    ReadWriteTimeoutSeconds = 60
}
```

### 4. **Enhanced Error Messages**

Error messages now provide specific guidance:

- **Timeout Errors**: Suggest increasing timeout or checking server load
- **404 Errors**: Suggest verifying application path and installation
- **Connection Errors**: Suggest checking network connectivity

## Usage Examples

### Basic Usage (with improved defaults)
```powershell
# Individual ESS health check
$healthCheck = Get-ESSHealthCheckViaAPI -SiteName "Default Web Site" -ApplicationPath "/Self-Service/ESS"

# All ESS instances
$allChecks = Get-ESSHealthCheckForAllInstances
```

### Custom Timeout Settings
```powershell
# Individual with custom timeout
$healthCheck = Get-ESSHealthCheckViaAPI -SiteName "Default Web Site" -ApplicationPath "/Self-Service/ESS" -TimeoutSeconds 120 -MaxRetries 3

# All instances with custom settings
$allChecks = Get-ESSHealthCheckForAllInstances -TimeoutSeconds 120 -MaxRetries 3 -RetryDelaySeconds 10
```

### Testing the Improvements
```powershell
# Run the test script
.\Test-TimeoutImprovements.ps1 -TimeoutSeconds 90 -MaxRetries 2
```

## Troubleshooting

### If You Still Experience Timeouts

1. **Increase Timeout Further**
   ```powershell
   Get-ESSHealthCheckViaAPI -TimeoutSeconds 180 -MaxRetries 3
   ```

2. **Check ESS Application Status**
   - Verify IIS application pools are running
   - Check ESS application logs for errors
   - Ensure database connectivity

3. **Verify Application Path**
   - Confirm the ESS application path is correct
   - Check if the API endpoint exists at the specified path

4. **Network Considerations**
   - Test basic connectivity to the server
   - Check for firewall or proxy issues
   - Verify DNS resolution

### Common Error Scenarios

#### "Request timed out after X seconds"
- **Cause**: ESS application is under heavy load or experiencing issues
- **Solution**: Increase timeout, check server resources, retry later

#### "Endpoint not found (404)"
- **Cause**: ESS application not installed or API endpoint not available
- **Solution**: Verify installation and application path

#### "Connection refused"
- **Cause**: ESS application not running or port blocked
- **Solution**: Start ESS application, check firewall settings

## Performance Impact

- **Increased Reliability**: Fewer false failures due to temporary issues
- **Better Diagnostics**: More informative error messages
- **Configurable**: Can be tuned for specific environments
- **Minimal Overhead**: Retry logic only activates when needed

## Configuration Recommendations

### Development Environment
```powershell
APIHealthCheck = @{
    DefaultTimeoutSeconds = 60
    MaxRetries = 1
    RetryDelaySeconds = 3
}
```

### Production Environment
```powershell
APIHealthCheck = @{
    DefaultTimeoutSeconds = 120
    MaxRetries = 3
    RetryDelaySeconds = 5
}
```

### High-Load Environment
```powershell
APIHealthCheck = @{
    DefaultTimeoutSeconds = 180
    MaxRetries = 4
    RetryDelaySeconds = 10
}
```

## Migration Notes

- **Backward Compatible**: Existing scripts will work with improved defaults
- **No Breaking Changes**: All existing parameters remain functional
- **Enhanced Functionality**: New parameters are optional with sensible defaults

## Testing

Use the provided test script to validate the improvements:

```powershell
# Test with default settings
.\Test-TimeoutImprovements.ps1

# Test with custom settings
.\Test-TimeoutImprovements.ps1 -TimeoutSeconds 120 -MaxRetries 3
```

The test script will:
- Test individual ESS health checks
- Test batch health checks for all instances
- Provide detailed timing and error information
- Offer specific recommendations for issues

