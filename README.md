# ESS Health Checker

A comprehensive PowerShell-based health checking tool for ESS (Employee Self Service) and WFE (Workflow Engine) installations. This tool performs pre-upgrade validation checks to ensure system compatibility and readiness for ESS upgrades.

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Project Structure](#project-structure)
- [Technical Design](#technical-design)
- [Installation](#installation)
- [Usage](#usage)
- [Configuration](#configuration)
- [Modules](#modules)
- [Health Checks](#health-checks)
- [Reports](#reports)
- [Contributing](#contributing)

## 🎯 Overview

The ESS Health Checker is designed to validate system requirements and configurations before ESS upgrades. It performs comprehensive checks including:

- **System Requirements**: OS, memory, disk space, CPU cores
- **IIS Configuration**: Installation, version, sites, application pools
- **ESS/WFE Detection**: Interactive or automatic discovery of installations
- **Database Connectivity**: Connection testing for ESS and WFE databases
- **Network Connectivity**: Internet and network adapter validation
- **Security Permissions**: Administrator rights and file system access

### Enhanced Interactive Mode (v2.0)

The new interactive mode provides significant improvements over the legacy automatic detection:

- **User Control**: Select specific instances to check instead of relying on complex automatic detection
- **Reduced Complexity**: Avoid complex fallback logic and URL guessing
- **Explicit Configuration**: Users provide exact ESS site URLs for API health checks
- **Focused Validation**: Only check selected instances, reducing false positives
- **Better Reliability**: Eliminates detection failures that can occur with automatic mode
- **Clear Progress**: Step-by-step process with confirmation prompts
- **Flexible Deployment**: Support for Combined, ESS Only, and WFE Only deployments
- **IIS Validation**: Early detection if IIS is not installed, guiding users to check other servers
- **Instance Selection**: User-driven selection of specific ESS/WFE instances to validate
- **API Endpoint Testing**: Direct testing of ESS API endpoints using user-provided URLs

## 🏗️ Architecture

### Core Architecture Principles

1. **Modular Design**: Separation of concerns with focused modules
2. **Single Source of Truth**: Centralized result management
3. **Extensible Framework**: Easy addition of new validation types
4. **PowerShell Best Practices**: Approved verbs, error handling, verbose output
5. **Interactive User Experience**: User-driven instance selection and configuration

### Architecture Diagram

#### Interactive Mode Architecture

```
┌─────────────────────────────────────────────────────────────┐
│              ESS Health Checker (Interactive)              │
├─────────────────────────────────────────────────────────────┤
│  InteractiveMain.ps1 (Interactive Orchestration)         │
│  ├── InteractiveDetection.ps1 (User-Driven Detection)    │
│  ├── InteractiveValidation.ps1 (Focused Validation)      │
│  ├── HealthCheckCore.ps1 (Infrastructure)                │
│  ├── Config.ps1 (Configuration)                          │
│  ├── SystemInfo.ps1 (System Information)                 │
│  └── ReportGenerator.ps1 (Reporting)                     │
└─────────────────────────────────────────────────────────────┘
```

#### Legacy Automatic Mode Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    ESS Health Checker                      │
├─────────────────────────────────────────────────────────────┤
│  Main.ps1 (Orchestration Layer)                          │
│  ├── HealthCheckCore.ps1 (Infrastructure)                │
│  ├── Config.ps1 (Configuration)                          │
│  ├── SystemInfo.ps1 (System Information)                 │
│  ├── ESSWFEDetection.ps1 (ESS/WFE Detection)            │
│  ├── SystemValidation.ps1 (Validation Engine)            │
│  └── ReportGenerator.ps1 (Reporting)                     │
└─────────────────────────────────────────────────────────────┘
```

### Data Flow

```
1. Main.ps1 (Entry Point)
   ↓
2. HealthCheckCore.ps1 (Initialize Infrastructure)
   ↓
3. SystemInfo.ps1 (Collect System Information)
   ↓
4. ESSWFEDetection.ps1 (Detect ESS/WFE Installations)
   ↓
5. Config.ps1 (Load Configuration)
   ↓
6. SystemValidation.ps1 (Perform Health Checks)
   ↓
7. ReportGenerator.ps1 (Generate HTML Report)
```

## 📁 Project Structure

```
COMP693_Industry Project/
├── README.md                           # Project documentation
├── RunHealthCheck.ps1                 # Legacy automatic execution script
├── RunInteractiveHealthCheck.ps1      # Interactive execution script (Recommended)
├── docs/                              # Documentation folder
└── src/                               # Source code
    ├── Main.ps1                      # Legacy main orchestration script
    ├── InteractiveMain.ps1           # Interactive main orchestration script
    ├── HealthCheckCore.ps1           # Core infrastructure module
    ├── Config.ps1                    # Configuration management
    ├── ReportGenerator.ps1           # HTML report generation
    ├── ExampleUsage.ps1              # Usage examples
    ├── tests/                        # Test files
    └── modules/                      # Validation modules
        ├── System/                   # System information modules
        │   ├── HardwareInfo.ps1     # Hardware information collection
        │   ├── OSInfo.ps1           # Operating system information
        │   ├── IISInfo.ps1          # IIS configuration information
        │   ├── SQLInfo.ps1          # SQL Server information
        │   └── SystemInfoOrchestrator.ps1 # System info coordination
        ├── Detection/                # Detection modules
        │   ├── InteractiveDetection.ps1 # Interactive detection (New)
        │   ├── DetectionOrchestrator.ps1 # Legacy detection orchestration
        │   ├── ESSDetection.ps1     # Legacy ESS detection logic
        │   ├── WFEDetection.ps1     # Legacy WFE detection logic
        │   └── ESSHealthCheckAPI.ps1 # ESS API health check module
        ├── Validation/               # Validation modules
        │   ├── InteractiveValidation.ps1 # Interactive validation (New)
        │   ├── ValidationOrchestrator.ps1 # Legacy validation orchestration
        │   ├── SystemRequirements.ps1 # System requirement validation
        │   ├── InfrastructureValidation.ps1 # Infrastructure validation
        │   └── ESSValidation.ps1    # ESS-specific validation
        └── Utils/                   # Utility modules
            └── HelperFunctions.ps1  # Common helper functions
```

## 🔧 Technical Design

### Module Responsibilities

#### 1. **HealthCheckCore.ps1** (Infrastructure)
- **Purpose**: Centralized health check result management
- **Key Functions**:
  - `Add-HealthCheckResult`: Add validation results
  - `Get-HealthCheckSummary`: Get statistics
  - `Clear-HealthCheckResults`: Reset results
- **Global Variables**: `$global:HealthCheckResults`

#### 2. **SystemInfo.ps1** (System Information)
- **Purpose**: Collect comprehensive system information
- **Key Functions**:
  - `Get-SystemInformation`: Main collection function
  - `Get-OSInformation`: Operating system details
  - `Get-HardwareInformation`: CPU, memory, disk info
  - `Get-IISInformation`: IIS configuration details
  - `Get-SQLServerInformation`: SQL Server detection
- **Global Variables**: `$global:SystemInfo`

#### 3. **ESSWFEDetection.ps1** (ESS/WFE Detection)
- **Purpose**: Detect and analyze ESS/WFE installations
- **Key Functions**:
  - `Get-ESSWFEDetection`: Main detection function
  - `Find-ESSInstances`: Find ESS installations
  - `Find-WFEInstances`: Find WFE installations
  - `Get-PayGlobalConfigInfo`: Parse ESS config
  - `Get-TenantsConfigInfo`: Parse WFE config
  - `Test-WebConfigEncryption`: Check web.config encryption status
  - `Invoke-WebConfigDecryption`: Decrypt web.config sections
  - `Invoke-WebConfigEncryption`: Encrypt web.config sections
- **Dependencies**: IIS modules, configuration parsing

#### 4. **Config.ps1** (Configuration Management)
- **Purpose**: Dynamic configuration based on system info
- **Key Functions**:
  - `Initialize-ESSHealthCheckerConfiguration`: Setup configuration
  - Dynamic requirements based on detected installations
- **Global Variables**: `$global:ESSConfig`

#### 5. **SystemValidation.ps1** (Validation Engine)
- **Purpose**: Perform health check validations
- **Key Functions**:
  - `Start-SystemValidation`: Main validation orchestration
  - `Test-SystemRequirements`: System requirement checks
  - `Test-ESSWFEDetection`: ESS/WFE validation
  - `Test-IISConfiguration`: IIS configuration checks
  - `Test-DatabaseConnectivity`: Database connection tests
  - `Test-WebConfigEncryptionValidation`: Web.config encryption validation
- **Dependencies**: HealthCheckCore.ps1

#### 6. **ReportGenerator.ps1** (Reporting)
- **Purpose**: Generate HTML health check reports
- **Key Functions**:
  - `New-HealthCheckReport`: Main report generation
  - `New-ReportHTML`: HTML template generation
  - Executive summary and detailed results
- **Output**: HTML report with styling

### Global Variables Architecture

```powershell
# Core Infrastructure
$global:HealthCheckResults = @()  # Centralized results storage

# System Information
$global:SystemInfo = $null        # Comprehensive system data

# Configuration
$global:ESSConfig = $null         # Dynamic configuration

# Detection Results
$global:DetectionResults = $null  # ESS/WFE detection results
```

### Error Handling Strategy

1. **Try-Catch Blocks**: Comprehensive error handling in all modules
2. **Graceful Degradation**: Continue operation even if some checks fail
3. **Verbose Output**: Detailed logging for troubleshooting
4. **Status Reporting**: Clear PASS/FAIL/WARNING/INFO status codes

## 🚀 Installation

### Prerequisites

- **PowerShell 5.1+** or **PowerShell Core 6.0+**
- **Windows Server** or **Windows 10/11**
- **Administrator Rights** (for full functionality)
- **IIS** (for ESS/WFE detection)

### Quick Start

#### Interactive Mode (Recommended)

The interactive mode provides a user-friendly experience with step-by-step prompts:

1. **Clone the repository**:
   ```powershell
   git clone <repository-url>
   cd "COMP693_Industry Project"
   ```

2. **Run the interactive health check**:
   ```powershell
   .\RunInteractiveHealthCheck.ps1
   ```

3. **Follow the prompts**:
   - The script will scan for available ESS/WFE instances
   - You'll be prompted to select which instances to check
   - For ESS instances, you'll provide the site URLs
   - The script will perform health checks only on selected instances

4. **View the report**:
   - HTML report will be generated in the current directory
   - Open `ESS_HealthCheck_Report_<timestamp>.html` in a web browser

#### Legacy Automatic Mode

The original automatic detection mode is still available:

```powershell
.\RunHealthCheck.ps1
```

**Note**: The automatic mode uses complex detection logic that may fail in some environments. The interactive mode is recommended for better reliability and user control.

## 📖 Usage

### Interactive Mode (Recommended)

The interactive mode provides the best user experience with step-by-step guidance:

```powershell
# Run interactive health check
.\RunInteractiveHealthCheck.ps1

# Show help information
.\RunInteractiveHealthCheck.ps1 -Help

# Run with verbose output
.\RunInteractiveHealthCheck.ps1 -Verbose
```

#### Interactive Mode Features

1. **IIS Validation**: Early check if IIS is installed, guides users to other servers if not
2. **Instance Discovery**: Automatically scans for ESS and WFE installations
3. **User Selection**: Prompts you to select specific instances to check
4. **URL Configuration**: For ESS instances, prompts for site URLs for API health checks
5. **Focused Validation**: Performs health checks only on selected instances
6. **Step-by-Step Process**: Clear progress indicators and confirmation steps

#### Interactive Mode Workflow

1. **System Check**: Validates IIS installation and system requirements
2. **Approach Selection**: Choose between automated or manual health checks
3. **Instance Selection**: Select specific ESS/WFE instances to validate
4. **URL Input**: Provide ESS site URLs for API endpoint testing
5. **Targeted Validation**: Run health checks only on selected instances
6. **Report Generation**: Generate focused report with selected instances

#### Example Interactive Session

```
ESS Interactive Pre-Upgrade Health Checker
=============================================
Enhanced version with user-guided health checks

=== System Information Summary ===
Computer Name: SERVER01
OS Version: Windows Server 2019
Total Memory: 16 GB
Available Disk Space: 500 GB
CPU Cores: 8
IIS Version: 10.0

✅ IIS is installed on this machine.
   ESS/WFE installations may be present.

Please choose your health check approach:
1. Auto - Dynamic detection and validation of all ESS/WFE instances
2. Manual - Select specific instances and provide custom URLs
3. Exit - Cancel health check

Enter your choice (1-3): 2

=== Instance Selection ===
Available IIS Applications:
1. Site: Default Web Site
   Application: /
   Pool: DefaultAppPool
   Physical Path: C:\inetpub\wwwroot

2. Site: Default Web Site
   Application: /ESS
   Pool: ESSAppPool
   Physical Path: C:\inetpub\wwwroot\ESS

Select instances to check (comma-separated numbers, e.g., 1,3): 2

=== Instance Details: Default Web Site/ESS ===
Type: ESS
Alias: Default_ESS_ESS

For ESS instances, please provide the ESS site URL for API health checks.
Example: https://ess.company.com or http://localhost/ESS

Enter ESS site URL (or press Enter to skip): https://ess.company.com

✅ Selected 1 instance(s) for health check.

Starting targeted health checks for selected instances...
```

### Legacy Automatic Mode

```powershell
# Run complete health check (automatic detection)
.\RunHealthCheck.ps1

# Run with verbose output
.\RunHealthCheck.ps1 -Verbose

# Run specific modules only
. .\src\Main.ps1
Start-SystemValidation
```

### Advanced Usage

#### Interactive Mode Advanced Usage

```powershell
# Import interactive modules individually
. .\src\InteractiveMain.ps1

# Run interactive health check programmatically
$reportPath = Start-InteractiveESSHealthChecks

# Show interactive help
Show-InteractiveHelp

# See example usage
. .\src\ExampleInteractiveUsage.ps1
```

#### Legacy Mode Advanced Usage

```powershell
# Import modules individually
. .\src\HealthCheckCore.ps1
. .\src\modules\SystemInfo.ps1

# Get system information only
$systemInfo = Get-SystemInformation

# Run ESS/WFE detection only
$detectionResults = Get-ESSWFEDetection

# Generate custom report
$results = Get-HealthCheckResults
New-HealthCheckReport -Results $results -OutputPath "Custom_Report.html"
```

## ⚙️ Configuration

### Configuration Structure

The tool uses dynamic configuration based on detected system information:

```powershell
$global:ESSConfig = @{
    # System Requirements
    MinimumMemoryGB = 8
    MinimumDiskSpaceGB = 50
    MinimumCores = 4
    MinimumProcessorSpeedGHz = 2.0
    
    # Software Requirements
    RequiredIISVersion = "10.0"
    RequiredDotNetVersion = "4.7.2"
    RequiredOSVersions = @("Windows Server 2016", "Windows Server 2019", "Windows Server 2022")
    
    # Detection Results
    DetectionResults = $null
}
```

### Customizing Requirements

Edit `src/Config.ps1` to modify system requirements:

```powershell
# Example: Increase memory requirement
$global:ESSConfig.MinimumMemoryGB = 16

# Example: Add new OS version
$global:ESSConfig.RequiredOSVersions += "Windows Server 2025"
```

## 🔍 Health Checks

### Interactive Mode Health Checks

The interactive mode performs focused health checks based on user selections:

#### System Requirements Checks (Always Run)
- **Memory**: Available RAM vs. minimum requirement
- **Disk Space**: Available disk space vs. minimum requirement
- **CPU Cores**: Number of cores vs. minimum requirement
- **Operating System**: OS version and type validation
- **IIS Installation**: IIS presence and version check

#### ESS-Specific Checks (For Selected ESS Instances)
- **Configuration Parsing**: Parse `payglobal.config` for database connections
- **Web.Config Encryption**: Check encryption status and authentication mode
- **API Health Check**: Test connectivity to user-provided ESS site URLs
- **Health Endpoint**: Test `/health` endpoint if available

#### WFE-Specific Checks (For Selected WFE Instances)
- **Configuration Parsing**: Parse `tenants.config` for database connections
- **Configuration Validation**: Verify configuration file integrity

#### Infrastructure Checks (Always Run)
- **IIS Configuration**: Site and application pool enumeration
- **Network Connectivity**: Internet access and network adapter validation
- **Security Permissions**: Administrator rights and file system access

### Legacy Automatic Mode Health Checks

The legacy mode performs comprehensive automatic detection:

#### System Requirements Checks
- **Memory**: Available RAM vs. minimum requirement
- **Disk Space**: Available disk space vs. minimum requirement
- **CPU Cores**: Number of cores vs. minimum requirement
- **Processor Speed**: Average processor speed vs. minimum requirement
- **Operating System**: OS version and type validation
- **IIS Installation**: IIS presence and version check
- **.NET Framework**: .NET version validation

#### ESS/WFE Detection Checks
- **IIS Installation**: Verify IIS is installed and running
- **ESS Installations**: Find ESS installations via `payglobal.config`
- **WFE Installations**: Find WFE installations via `tenants.config`
- **Deployment Type**: Determine if Combined/ESS Only/WFE Only
- **Configuration Parsing**: Extract database connections and settings

### IIS Configuration Checks

- **IIS Sites**: Count and validate IIS sites
- **Application Pools**: Count and validate application pools
- **IIS Version**: Verify minimum IIS version

### Web.Config Encryption Checks

- **Authentication Mode Detection**: Identify SingleSignOn vs. other authentication modes
- **Encryption Status**: Check if web.config sections are encrypted
- **SingleSignOn Validation**: Ensure proper encryption state for SingleSignOn
- **Upgrade Readiness**: Warn about encrypted web.config before upgrades
- **Encryption Management**: Provide functions to encrypt/decrypt web.config

#### Encryption Functions

```powershell
# Check encryption status for a specific ESS installation
$encryptionInfo = Test-WebConfigEncryption -WebConfigPath "C:\inetpub\wwwroot\Self-Service\ESS\Web.config"

# Decrypt web.config for an ESS installation (use with caution)
$success = Invoke-WebConfigDecryption -ESSInstallPath "C:\inetpub\wwwroot\Self-Service\ESS" -Force

# Encrypt web.config for an ESS installation (use with caution)
$success = Invoke-WebConfigEncryption -ESSInstallPath "C:\inetpub\wwwroot\Self-Service\ESS" -Force
```

#### Encryption Rules

- **SingleSignOn Authentication**: Web.config should NOT be encrypted for upgrades
- **Other Authentication Modes**: Encryption status is informational only
- **Upgrade Process**: Decrypt before upgrade, re-encrypt after upgrade
- **Security**: Always re-encrypt after successful upgrade

### Database Connectivity Checks

- **ESS Database**: Test connection to ESS database
- **WFE Database**: Test connection to WFE database
- **Connection Strings**: Validate connection string format

### Network Connectivity Checks

- **Internet Connectivity**: Test basic internet access
- **Network Adapters**: Validate active network adapters
- **DNS Resolution**: Test DNS server configuration

### Security Permission Checks

- **Administrator Rights**: Verify script is running as administrator
- **File System Access**: Test file system permissions
- **IIS Configuration Access**: Verify IIS configuration access

## 📊 Reports

### Report Structure

The HTML report includes:

1. **Executive Summary**
   - ESS Status (Installed/Not Installed)
   - WFE Status (Installed/Not Installed)
   - Checks Passed/Total
   - SQL Server Status
   - CPU Cores

2. **Health Check Results**
   - System Requirements
   - ESS/WFE Detection
   - IIS Configuration
   - Database Connectivity
   - Network Connectivity
   - Security Permissions

3. **ESS Instances Table**
   - Site Name
   - Application Pool
   - Database Server
   - Database Name
   - Install Path
   - Pool Identity
   - Web Server URL

4. **WFE Instances Table**
   - Site Name
   - Application Pool
   - Database Server
   - Database Name
   - Install Path
   - Pool Identity

### Report Features

- **Color-coded Status**: Green (PASS), Red (FAIL), Yellow (WARNING), Blue (INFO)
- **Detailed Messages**: Comprehensive error and success messages
- **Responsive Design**: Works on desktop and mobile devices
- **Export Ready**: Clean HTML for sharing and archiving

## 🔧 Extending the Tool

### Adding New Validation Modules

1. **Create new module** in `src/modules/`:
   ```powershell
   # src/modules/CustomValidation.ps1
   function Start-CustomValidation {
       # Your validation logic here
       Add-HealthCheckResult -Category "Custom" -Check "My Check" -Status "PASS" -Message "Success"
   }
   ```

2. **Import in Main.ps1**:
   ```powershell
   . .\modules\CustomValidation.ps1
   ```

3. **Call in validation**:
   ```powershell
   Start-CustomValidation
   ```

### Adding New System Information

1. **Extend SystemInfo.ps1**:
   ```powershell
   function Get-CustomInformation {
       # Your information collection logic
       return @{ CustomData = "value" }
   }
   ```

2. **Integrate in Get-SystemInformation**:
   ```powershell
   $systemInfo.Custom = Get-CustomInformation
   ```

### Adding New Health Checks

1. **Use HealthCheckCore.ps1 functions**:
   ```powershell
   Add-HealthCheckResult -Category "New Category" -Check "New Check" -Status "PASS" -Message "Success"
   ```

2. **Follow naming conventions**:
   - Use approved PowerShell verbs
   - Clear, descriptive function names
   - Comprehensive error handling

## 🧪 Testing

### Test Structure

```
src/tests/
├── Unit Tests
├── Integration Tests
└── Sample Data
```

### Running Tests

```powershell
# Run all tests
. .\src\tests\RunTests.ps1

# Run specific test category
. .\src\tests\SystemInfo.Tests.ps1
```

## 🤝 Contributing

### Development Guidelines

1. **PowerShell Best Practices**:
   - Use approved PowerShell verbs
   - Implement proper error handling
   - Add comprehensive comments
   - Follow naming conventions

2. **Code Organization**:
   - Keep modules focused and single-purpose
   - Use clear function names
   - Implement proper parameter validation
   - Add verbose output for debugging

3. **Testing**:
   - Test on multiple Windows versions
   - Validate with different ESS/WFE configurations
   - Test error conditions and edge cases

### Pull Request Process

1. **Fork the repository**
2. **Create feature branch**
3. **Implement changes**
4. **Add tests if applicable**
5. **Update documentation**
6. **Submit pull request**

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

### Troubleshooting

1. **Common Issues**:
   - **Permission Denied**: Run as Administrator
   - **IIS Not Found**: Install IIS or run on server with IIS
   - **Module Import Errors**: Check PowerShell execution policy

2. **Verbose Output**:
   ```powershell
   .\RunHealthCheck.ps1 -Verbose
   ```

3. **Debug Mode**:
   ```powershell
   $VerbosePreference = "Continue"
   .\RunHealthCheck.ps1
   ```

### Getting Help

- **Documentation**: Check this README and docs/ folder
- **Issues**: Create GitHub issue with detailed information
- **Examples**: See ExampleUsage.ps1 for usage patterns

---

**Version**: 1.0  
**Last Updated**: 2025-01-04  
**Author**: Zoe Lai  
**Project**: ESS Health Checker 