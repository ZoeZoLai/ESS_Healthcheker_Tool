# WFE Detection Tests and Diagnostics

This directory contains comprehensive tests and diagnostic tools for the WFE (Workflow Engine) detection functionality in the ESS Health Checker Tool.

## Files Overview

### Test Files
- **`WFEDetection.Tests.ps1`** - Comprehensive Pester tests for the WFEDetection.ps1 module (Development only)
- **`Run-WFEDetectionTests.ps1`** - Test runner script with reporting capabilities (Development only)
- **`Test-WFEDetection.ps1`** - Windows Server compatible test runner (No Pester required)
- **`Test-APIHealthCheck.ps1`** - API health check test and troubleshooting script

### Diagnostic Tools
- **`Diagnose-WFEIssues.ps1`** - Diagnostic script to identify WFE detection and API health check issues

## Prerequisites

### Required Modules
```powershell
# Install Pester (if not already installed)
Install-Module -Name Pester -Force -SkipPublisherCheck

# Import required modules
Import-Module Pester
```

### PowerShell Version
- PowerShell 5.1 or higher
- Windows Server 2016/2019/2022 or Windows 10/11

## Running Tests

### Windows Server Compatible Tests (No Pester Required)
```powershell
# Navigate to the tests directory
cd "src\tests"

# Run WFE detection tests (Windows Server compatible)
.\Test-WFEDetection.ps1

# Run API health check tests
.\Test-APIHealthCheck.ps1

# Run with verbose output
.\Test-WFEDetection.ps1 -Verbose
```

### Development Environment Tests (Pester Required)
```powershell
# Run the test runner
.\Run-WFEDetectionTests.ps1

# Run with verbose output
.\Run-WFEDetectionTests.ps1 -Verbose

# Run with code coverage analysis
.\Run-WFEDetectionTests.ps1 -CodeCoverage

# Specify custom output path
.\Run-WFEDetectionTests.ps1 -OutputPath "CustomTestResults"

# Run tests directly with Pester
Invoke-Pester -Path "WFEDetection.Tests.ps1"

# Run with code coverage
Invoke-Pester -Path "WFEDetection.Tests.ps1" -CodeCoverage "..\modules\Detection\WFEDetection.ps1"
```

## Running Diagnostics

### Basic Diagnostics
```powershell
# Run the diagnostic script
.\Diagnose-WFEIssues.ps1
```

### Verbose Diagnostics
```powershell
# Run with verbose output
.\Diagnose-WFEIssues.ps1 -Verbose
```

## Test Coverage

The `WFEDetection.Tests.ps1` file includes tests for:

### Core Functions
- **`Test-WFEInstallation`** - Tests WFE installation detection
- **`Find-WFEInstances`** - Tests discovery of multiple WFE instances
- **`Get-TenantsConfigInfo`** - Tests parsing of tenants.config files

### Test Scenarios
1. **IIS Not Installed** - Tests behavior when IIS is not available
2. **No WFE Found** - Tests when IIS is installed but no WFE is found
3. **WFE Installed** - Tests successful WFE detection
4. **Error Handling** - Tests graceful error handling
5. **Multiple Installations** - Tests detection of multiple WFE instances
6. **Configuration Parsing** - Tests parsing of various tenants.config formats
7. **Performance** - Tests performance with large numbers of IIS sites

### Edge Cases
- Missing IIS modules
- Malformed configuration files
- Permission issues
- File system access problems
- Multiple tenant configurations

## Understanding Test Results

### Test Output
- **Green** - Test passed
- **Red** - Test failed
- **Yellow** - Test skipped or warning

### Common Test Failures

#### WFE Detection Failures
```powershell
# Issue: WFE not detected when it should be
# Possible causes:
# - tenants.config file not found
# - IIS permissions issues
# - Incorrect file paths
```

#### API Health Check Failures
```powershell
# Issue: "No health check results returned from API"
# Possible causes:
# - ESS instances not detected
# - API endpoint not accessible
# - Network connectivity issues
```

## Troubleshooting Common Issues

### Issue 1: WFE Detection Fails on Windows Server 2019

**Symptoms:**
- WFE detection works on current machine but fails on Windows Server 2019
- Script shows "No WFE installations found" when WFE is actually installed

**Diagnostic Steps:**
1. Run the diagnostic script:
   ```powershell
   .\Diagnose-WFEIssues.ps1
   ```

2. Check IIS installation:
   ```powershell
   Get-WindowsFeature -Name "Web-Server"
   ```

3. Verify IIS modules:
   ```powershell
   Import-Module WebAdministration
   Import-Module IISAdministration
   ```

4. Check file permissions:
   ```powershell
   Test-Path "C:\inetpub\wwwroot"
   Get-Acl "C:\inetpub\wwwroot"
   ```

**Solutions:**
- Ensure IIS is properly installed
- Run PowerShell as Administrator
- Verify tenants.config file exists in WFE installation directory
- Check IIS application pool status

### Issue 2: API Health Check Returns No Results

**Symptoms:**
- API endpoint is accessible but returns "No health check results returned from API"
- ESS instances are detected but API health check fails

**Diagnostic Steps:**
1. Check ESS instance detection:
   ```powershell
   $essInstances = Find-ESSInstances
   $essInstances | Format-Table
   ```

2. Test API endpoint manually:
   ```powershell
   $uri = "http://localhost/ESS_PGNZ/api/v1/healthcheck"
   Invoke-WebRequest -Uri $uri -Method GET
   ```

3. Check application pool status:
   ```powershell
   Get-IISAppPool | Where-Object { $_.Name -like "*ESS*" }
   ```

**Solutions:**
- Verify ESS application is running
- Check IIS application pool is started
- Ensure API endpoint is enabled in the application
- Verify network connectivity

### Issue 3: Permission Issues

**Symptoms:**
- Access denied errors when accessing IIS configuration
- Cannot read registry keys or file system

**Solutions:**
- Run PowerShell as Administrator
- Grant appropriate permissions to the user account
- Check Windows Defender or antivirus exclusions

## Test Development

### Adding New Tests

1. **Create test structure:**
   ```powershell
   Describe "New Feature" {
       Context "When condition is met" {
           It "Should behave correctly" {
               # Test implementation
           }
       }
   }
   ```

2. **Use appropriate mocks:**
   ```powershell
   Mock Get-IISSite { return @($mockSite) }
   Mock Test-Path { return $true }
   ```

3. **Test edge cases:**
   ```powershell
   Context "When error occurs" {
       Mock Get-WindowsFeature { throw "Access denied" }
       
       It "Should handle error gracefully" {
           # Test error handling
       }
   }
   ```

### Best Practices

1. **Use descriptive test names** that explain what is being tested
2. **Mock external dependencies** to ensure tests are isolated
3. **Test both success and failure scenarios**
4. **Include performance tests** for functions that process large datasets
5. **Use BeforeAll/AfterAll** for test setup and cleanup

## Continuous Integration

### GitHub Actions Example
```yaml
name: WFE Detection Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: windows-latest
    steps:
    - uses: actions/checkout@v2
    - name: Install Pester
      run: Install-Module -Name Pester -Force
    - name: Run Tests
      run: |
        cd src/tests
        .\Run-WFEDetectionTests.ps1 -CodeCoverage
```

## Support

For issues with the tests or diagnostic tools:

1. Run the diagnostic script first
2. Check the test output for specific error messages
3. Review the troubleshooting section above
4. Create an issue with detailed error information

## Version History

- **v1.0** - Initial release with comprehensive test coverage
- Added diagnostic tools for troubleshooting
- Included performance and edge case testing
