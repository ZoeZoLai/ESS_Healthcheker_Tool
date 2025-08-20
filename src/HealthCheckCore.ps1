<#
.SYNOPSIS
    Core health check utilities and result management
.DESCRIPTION
    Provides centralized functions for health check result management and shared utilities
.NOTES
    Author: Zoe Lai
    Date: 04/08/2025
    Version: 1.0
#>

# Initialize global results array
$global:HealthCheckResults = @()

function Add-HealthCheckResult {
    <#
    .SYNOPSIS
        Adds a health check result to the global results array
    .PARAMETER Category
        Category of the health check
    .PARAMETER Check
        Name of the check
    .PARAMETER Status
        Status of the check (PASS, FAIL, WARNING, INFO)
    .PARAMETER Message
        Detailed message about the check result
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Category,
        
        [Parameter(Mandatory = $true)]
        [string]$Check,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet("PASS", "FAIL", "WARNING", "INFO")]
        [string]$Status,
        
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    $result = @{
        Category = $Category
        Check = $Check
        Status = $Status
        Message = $Message
        Timestamp = Get-Date
    }
    
    $global:HealthCheckResults += [PSCustomObject]$result
    
    # Debug: Log when FAIL results are added
    if ($Status -eq "FAIL") {
        Write-Verbose "Added FAIL result: $Category - $Check (Total results now: $($global:HealthCheckResults.Count))"
    }
    
    # Display result with appropriate color
    $color = switch ($Status) {
        "PASS" { "Green" }
        "FAIL" { "Red" }
        "WARNING" { "Yellow" }
        "INFO" { "Cyan" }
        default { "White" }
    }
    
    Write-Host "[$Status] $Category - $Check : $Message" -ForegroundColor $color
}

function Get-HealthCheckResults {
    <#
    .SYNOPSIS
        Gets all health check results
    .DESCRIPTION
        Returns the global health check results array
    .RETURNS
        Array of health check results
    #>
    [CmdletBinding()]
    param()
    
    return $global:HealthCheckResults
}

function Clear-HealthCheckResults {
    <#
    .SYNOPSIS
        Clears all health check results
    .DESCRIPTION
        Resets the global health check results array
    #>
    [CmdletBinding()]
    param()
    
    $global:HealthCheckResults = @()
    Write-Verbose "Health check results cleared"
}

function Get-HealthCheckSummary {
    <#
    .SYNOPSIS
        Gets a summary of health check results
    .DESCRIPTION
        Returns statistics about the health check results
    .RETURNS
        Object containing summary statistics
    #>
    [CmdletBinding()]
    param()
    
    $totalChecks = $global:HealthCheckResults.Count
    $passChecks = ($global:HealthCheckResults | Where-Object { $_.Status -eq "PASS" }).Count
    
    # Count FAIL results manually to avoid Where-Object issues
    $failChecks = 0
    foreach ($result in $global:HealthCheckResults) {
        if ($result.Status -eq "FAIL") {
            $failChecks++
        }
    }
    # Count warnings manually instead of using Where-Object
    $warningChecks = 0
    foreach ($result in $global:HealthCheckResults) {
        if ($result.Status -eq "WARNING") {
            $warningChecks++
        }
    }
    $infoChecks = ($global:HealthCheckResults | Where-Object { $_.Status -eq "INFO" }).Count
    
    # Debug: Log the actual status values found
    Write-Verbose "Summary calculation - Total: $totalChecks, Pass: $passChecks, Fail: $failChecks, Warning: $warningChecks, Info: $infoChecks"
    Write-Verbose "All status values found: $($global:HealthCheckResults.Status | Sort-Object -Unique)"
    
    # Debug: Check FAIL filter specifically
    $failResults = $global:HealthCheckResults | Where-Object { $_.Status -eq "FAIL" }
    Write-Verbose "FAIL filter results count: $($failResults.Count)"
    

    

    
    return @{
        Total = $totalChecks
        Pass = $passChecks
        Fail = $failChecks
        Warning = $warningChecks
        Info = $infoChecks
    }
}

function Get-HealthCheckResultsByCategory {
    <#
    .SYNOPSIS
        Gets health check results filtered by category
    .PARAMETER Category
        Category to filter by
    .RETURNS
        Array of health check results for the specified category
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Category
    )
    
    return $global:HealthCheckResults | Where-Object { $_.Category -eq $Category }
}

function Get-HealthCheckResultsByStatus {
    <#
    .SYNOPSIS
        Gets health check results filtered by status
    .PARAMETER Status
        Status to filter by (PASS, FAIL, WARNING, INFO)
    .RETURNS
        Array of health check results for the specified status
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("PASS", "FAIL", "WARNING", "INFO")]
        [string]$Status
    )
    
    return $global:HealthCheckResults | Where-Object { $_.Status -eq $Status }
} 