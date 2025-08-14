# ESS Health Checker - Modular Structure

This directory contains the modular components of the ESS Health Checker, organized by functionality for better maintainability and extensibility.

## Directory Structure

```
src/modules/
├── Detection/                    # ESS and WFE detection modules
│   ├── ESSDetection.ps1         # ESS-specific detection and configuration parsing
│   ├── WFEDetection.ps1         # WFE-specific detection and configuration parsing
│   └── DetectionOrchestrator.ps1 # Main detection coordination
├── System/                      # System information collection modules
│   ├── HardwareInfo.ps1         # Hardware information (CPU, memory, disk, network)
│   ├── OSInfo.ps1              # Operating system and registry information
│   ├── IISInfo.ps1             # IIS information (sites, application pools)
│   ├── SQLInfo.ps1             # SQL Server information
│   └── SystemInfoOrchestrator.ps1 # Main system information coordination
├── Validation/                  # Validation modules
│   ├── SystemRequirements.ps1   # System requirements validation
│   ├── InfrastructureValidation.ps1 # Infrastructure validation (IIS, DB, network)
│   ├── ESSValidation.ps1       # ESS-specific validation (detection, encryption)
│   └── ValidationOrchestrator.ps1 # Main validation coordination
├── Utils/                      # Utility functions
│   └── HelperFunctions.ps1     # Common helper functions
├── ModuleLoader.ps1            # Module loading orchestrator
└── README.md                   # This documentation
```

## Module Descriptions

### Detection Modules

#### ESSDetection.ps1
- **Purpose**: ESS-specific detection and configuration parsing
- **Key Functions**:
  - `Test-ESSInstallation`: Detects ESS installations via IIS
  - `Find-ESSInstances`: Finds all ESS instances on the machine
  - `Get-PayGlobalConfigInfo`: Parses payglobal.config files
  - `Test-WebConfigEncryption`: Checks web.config encryption status
  - `Get-WebServerURL`: Constructs web server URLs

#### WFEDetection.ps1
- **Purpose**: WFE-specific detection and configuration parsing
- **Key Functions**:
  - `Test-WFEInstallation`: Detects WFE installations via IIS
  - `Find-WFEInstances`: Finds all WFE instances on the machine
  - `Get-TenantsConfigInfo`: Parses tenants.config files

#### DetectionOrchestrator.ps1
- **Purpose**: Coordinates ESS and WFE detection
- **Key Functions**:
  - `Get-ESSWFEDetection`: Main detection orchestration
  - `Test-IISInstallation`: Simple IIS installation check

### System Modules

#### HardwareInfo.ps1
- **Purpose**: Hardware information collection
- **Key Functions**:
  - `Get-HardwareInformation`: CPU, memory, disk information
  - `Get-NetworkInformation`: Network adapter and configuration

#### OSInfo.ps1
- **Purpose**: Operating system and registry information
- **Key Functions**:
  - `Get-OSInformation`: OS version, type, memory
  - `Get-RegistryInformation`: .NET Framework versions

#### IISInfo.ps1
- **Purpose**: IIS information collection
- **Key Functions**:
  - `Get-IISInformation`: Sites, application pools, configuration

#### SQLInfo.ps1
- **Purpose**: SQL Server information collection
- **Key Functions**:
  - `Get-SQLServerInformation`: SQL Server instances, services, versions

#### SystemInfoOrchestrator.ps1
- **Purpose**: Coordinates all system information collection
- **Key Functions**:
  - `Get-SystemInformation`: Main system information gathering
  - `Test-SystemInfoAvailability`: Checks if system info is available
  - `Get-SystemInfoValue`: Retrieves specific system info values

### Validation Modules

#### SystemRequirements.ps1
- **Purpose**: System requirements validation
- **Key Functions**:
  - `Test-SystemRequirements`: Validates hardware, OS, and software requirements

#### InfrastructureValidation.ps1
- **Purpose**: Infrastructure component validation
- **Key Functions**:
  - `Test-IISConfiguration`: IIS configuration validation
  - `Test-DatabaseConnectivity`: Database connectivity tests
  - `Test-NetworkConnectivity`: Network connectivity tests
  - `Test-SecurityPermissions`: Security permission tests

#### ESSValidation.ps1
- **Purpose**: ESS-specific validation
- **Key Functions**:
  - `Test-ESSWFEDetection`: ESS/WFE detection validation
  - `Test-WebConfigEncryptionValidation`: Web.config encryption validation

#### ValidationOrchestrator.ps1
- **Purpose**: Coordinates all validation checks
- **Key Functions**:
  - `Start-SystemValidation`: Main validation orchestration

### Utils Modules

#### HelperFunctions.ps1
- **Purpose**: Common utility functions
- **Key Functions**:
  - `Get-FormattedSiteIdentifier`: Formats site names with application aliases
  - `Get-AppPoolIdentity`: Gets application pool identity information
  - `Test-SystemInfoAvailability`: Checks system info availability

## Module Loading

The `ModuleLoader.ps1` file automatically loads all modules in the correct dependency order:

1. **System modules** (dependencies for other modules)
2. **Detection modules** (ESS/WFE detection)
3. **Utils modules** (helper functions)
4. **Validation modules** (depend on other modules)

## Benefits of Modular Structure

1. **Maintainability**: Each module focuses on a specific area of functionality
2. **Extensibility**: Easy to add new validation types (e.g., compatibility, dependencies)
3. **Testability**: Individual modules can be tested in isolation
4. **Reusability**: Functions can be reused across different validation types
5. **Organization**: Clear separation of concerns

## Adding New Validation Types

To add new validation types (e.g., compatibility checks, dependency validation):

1. Create a new module in the appropriate directory:
   - `Validation/CompatibilityValidation.ps1` for compatibility checks
   - `Validation/DependencyValidation.ps1` for dependency validation

2. Add the new module to the `ModuleLoader.ps1` loading sequence

3. Add the new validation function to `ValidationOrchestrator.ps1`

4. Update the main validation orchestration to call your new validation function

## Migration from Old Structure

The old monolithic files have been broken down:
- `ESSWFEDetection.ps1` → Detection modules
- `SystemInfo.ps1` → System modules  
- `SystemValidation.ps1` → Validation modules

All existing functionality is preserved while providing better organization for future enhancements. 