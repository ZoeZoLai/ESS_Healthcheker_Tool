# Interactive Modules

This directory contains modules that support interactive user-guided health checks for the ESS Health Checker.

## Overview

The Interactive modules provide an enhanced user experience by allowing users to:
- Choose between automated and manual health check approaches
- Select specific ESS/WFE instances to validate
- Provide custom ESS site URLs for API health checks
- Focus validation on user-selected instances only

## Modules

### InteractiveDetection.ps1
Handles user-driven instance selection and URL input for manual health checks.

**Key Functions:**
- `Get-UserInstanceSelection` - Presents available instances and gets user input
- `Get-AvailableInstances` - Scans IIS for potential ESS/WFE instances
- `Get-InstanceDetails` - Collects additional user input for selected instances
- `Get-InstanceAlias` - Generates meaningful aliases for instances

### InteractiveValidation.ps1
Performs targeted health checks on user-selected instances using existing validation functions.

**Key Functions:**
- `Start-TargetedHealthChecks` - Orchestrates targeted health checks
- `Start-InstanceValidation` - Validates specific instances
- `Test-ESSInstance` - ESS-specific validation with API endpoint testing
- `Test-WFEInstance` - WFE-specific validation
- `Test-ESSAPIEndpoint` - Tests ESS API endpoints using user-provided URLs

## Usage

The Interactive modules are used by the `InteractiveMain.ps1` orchestrator and provide:

1. **Instance Discovery**: Scans IIS for potential ESS/WFE instances
2. **User Selection**: Presents available instances for user selection
3. **URL Input**: Collects ESS site URLs for API health checks
4. **Targeted Validation**: Performs health checks only on selected instances
5. **API Testing**: Tests ESS API endpoints using provided URLs

## Benefits

- **Reduced Complexity**: Avoids complex automatic detection logic
- **User Control**: Users select exactly which instances to check
- **Explicit Configuration**: Users provide exact URLs for API testing
- **Focused Results**: Only validates selected instances
- **Better Reliability**: Eliminates detection failures from automatic mode

## Integration

The Interactive modules integrate with existing validation functions:
- Reuses `Test-SystemRequirements` for system-level checks
- Reuses `Test-InfrastructureRequirements` for infrastructure validation
- Reuses `Test-IISRequirements` for IIS validation
- Extends validation with instance-specific checks

## Report Generation

Interactive health checks use a separate report generator (`InteractiveReportGenerator.ps1`) that:
- Shows user-selected instances
- Displays provided ESS site URLs
- Maintains consistent health check result format
- Provides clear indication of interactive mode usage
