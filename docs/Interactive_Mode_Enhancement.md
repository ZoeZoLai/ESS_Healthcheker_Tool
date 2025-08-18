# Interactive Mode Enhancement - ESS Health Checker v2.0

## Overview

This document outlines the enhancements made to the ESS Health Checker to support interactive user-guided health checks, addressing the requirements for reducing unnecessary try-and-fallback logic and providing better user control.

## Key Enhancements

### 1. IIS Installation Validation
- **Early Detection**: System checks IIS installation first before proceeding
- **User Guidance**: If IIS is not installed, clearly indicates no ESS/WFE installations and guides users to check other servers
- **Reduced Complexity**: Eliminates unnecessary detection attempts when IIS is not present

### 2. User-Driven Approach Selection
- **Choice Options**: Users can choose between automated and manual health check approaches
- **Clear Benefits**: Each approach is explained with its benefits and use cases
- **Flexible Deployment**: Supports different deployment scenarios (Combined, ESS Only, WFE Only)

### 3. Instance Selection Interface
- **Available Instances Display**: Shows all IIS applications that could be ESS/WFE instances
- **User Selection**: Allows users to select specific instances using comma-separated numbers
- **Instance Details**: Provides detailed information about each instance (site, application, pool, path)

### 4. ESS Site URL Input
- **Explicit Configuration**: Users provide exact ESS site URLs for API health checks
- **URL Validation**: Basic validation ensures proper URL format (http/https)
- **Optional Input**: Users can skip URL input if API health checks are not needed
- **API Endpoint Testing**: Uses provided URLs to test ESS API endpoints directly

### 5. Targeted Health Checks
- **Focused Validation**: Only validates user-selected instances
- **Reuse Existing Functions**: Leverages existing validation functions to avoid code duplication
- **Instance-Specific Checks**: Performs appropriate checks based on instance type (ESS/WFE)
- **System-Level Validation**: Still runs system-level checks that apply to all instances

### 6. Enhanced Reporting
- **Separate Report Generator**: Created `InteractiveReportGenerator.ps1` to avoid modifying existing code
- **User Selection Display**: Shows which instances were selected by the user
- **ESS Site URLs**: Displays provided ESS site URLs in the report
- **Consistent Format**: Maintains same health check result format regardless of approach

## New Files Created

### Core Interactive Files
- `src/InteractiveMain.ps1` - Main orchestrator for interactive health checks
- `src/modules/Interactive/InteractiveDetection.ps1` - User-driven instance detection
- `src/modules/Interactive/InteractiveValidation.ps1` - Targeted instance validation
- `src/InteractiveReportGenerator.ps1` - Interactive-specific report generation

### Launcher Scripts
- `RunInteractiveHealthCheck.ps1` - New launcher for interactive mode

### Documentation
- `src/modules/Interactive/README.md` - Interactive modules documentation
- `src/tests/Test-InteractiveHealthCheck.ps1` - Test script for interactive functionality

## Architecture Changes

### Modular Design
- **Separation of Concerns**: Interactive functionality is separated into focused modules
- **Reuse Existing Code**: Leverages existing validation functions instead of duplicating code
- **Extensible Framework**: Easy to add new interactive features

### Data Flow
```
1. InteractiveMain.ps1 (Entry Point)
   ↓
2. System Information Collection
   ↓
3. IIS Installation Check
   ↓
4. User Approach Selection (Auto/Manual)
   ↓
5a. Auto: Existing automated logic
   ↓
5b. Manual: User instance selection
   ↓
6. Targeted Health Checks
   ↓
7. Interactive Report Generation
```

## Benefits Achieved

### 1. Reduced Complexity
- **Eliminated Fallback Logic**: No more complex URL guessing or detection fallbacks
- **Clear User Control**: Users explicitly choose what to check
- **Focused Validation**: Only validates selected instances

### 2. Better Reliability
- **Explicit Configuration**: Users provide exact URLs instead of guessing
- **Reduced False Positives**: Only checks what users want to check
- **Clear Error Handling**: Better error messages and user guidance

### 3. Enhanced User Experience
- **Step-by-Step Process**: Clear progress indicators and confirmation steps
- **User-Friendly Interface**: Intuitive prompts and selections
- **Comprehensive Feedback**: Detailed information about each step

### 4. Maintained Consistency
- **Same Health Check Logic**: Reuses existing validation functions
- **Consistent Reports**: Same report format regardless of approach
- **Backward Compatibility**: Original automated mode still available

## Usage Examples

### Interactive Mode Workflow
1. **System Check**: Validates IIS installation
2. **Approach Selection**: Choose automated or manual mode
3. **Instance Selection**: Select specific instances to validate
4. **URL Input**: Provide ESS site URLs for API testing
5. **Targeted Validation**: Run health checks on selected instances
6. **Report Generation**: Generate focused report

### Example User Session
```
ESS Interactive Pre-Upgrade Health Checker
=============================================

✅ IIS is installed on this machine.

Please choose your health check approach:
1. Auto - Dynamic detection and validation of all ESS/WFE instances
2. Manual - Select specific instances and provide custom URLs
3. Exit - Cancel health check

Enter your choice (1-3): 2

=== Instance Selection ===
Available IIS Applications:
1. Site: Default Web Site
   Application: /ESS
   Pool: ESSAppPool
   Physical Path: C:\inetpub\wwwroot\ESS

Select instances to check: 1

=== Instance Details: Default Web Site/ESS ===
Type: ESS
Alias: Default_ESS_ESS

Enter ESS site URL: https://ess.company.com

✅ Selected 1 instance(s) for health check.
```

## Technical Implementation

### Function Reuse
- `Test-SystemRequirements` - System-level validation
- `Test-InfrastructureRequirements` - Infrastructure checks
- `Test-IISRequirements` - IIS validation
- `Add-HealthCheckResult` - Result management

### New Functions
- `Get-UserInstanceSelection` - User-driven instance selection
- `Start-TargetedHealthChecks` - Focused validation orchestration
- `Test-ESSAPIEndpoint` - Direct API endpoint testing
- `New-InteractiveHealthCheckReport` - Interactive report generation

### Error Handling
- **Graceful Degradation**: Continues operation even if some checks fail
- **Clear Error Messages**: User-friendly error descriptions
- **Validation**: Input validation for user-provided data

## Future Enhancements

### Potential Improvements
1. **Configuration Persistence**: Save user selections for future runs
2. **Batch Processing**: Support for multiple server health checks
3. **Advanced URL Validation**: More sophisticated URL and endpoint validation
4. **Custom Health Checks**: Allow users to define custom validation rules
5. **Integration APIs**: REST API for programmatic health checks

### Extensibility
- **Plugin Architecture**: Easy addition of new validation types
- **Custom Report Templates**: User-defined report formats
- **Integration Hooks**: Points for integrating with other tools

## Conclusion

The interactive mode enhancement successfully addresses the original requirements by:

1. **Reducing Complexity**: Eliminated unnecessary try-and-fallback logic
2. **Providing User Control**: Users can select specific instances and provide exact URLs
3. **Maintaining Consistency**: Same health check logic and report format
4. **Improving Reliability**: More reliable detection and validation
5. **Enhancing User Experience**: Clear, step-by-step process with good feedback

The enhancement follows the user rules by:
- **Splitting Large Rules**: Created focused, composable modules
- **Avoiding Vague Guidance**: Clear, specific functionality
- **Following DRY Code**: Reuses existing functions instead of duplicating code
- **Managing File Size**: Created separate files to avoid large monolithic modules
