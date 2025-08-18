<#
.SYNOPSIS
    Interactive report generator for user-guided health checks
.DESCRIPTION
    Generates HTML reports for interactive health checks with user-selected instances
.NOTES
    Author: Zoe Lai
    Date: 13/08/2025
    Version: 1.0
#>

function New-InteractiveHealthCheckReport {
    <#
    .SYNOPSIS
        Generates an interactive health check report
    .DESCRIPTION
        Creates an HTML report for user-guided health checks with selected instances
    .PARAMETER Results
        Array of health check results
    .PARAMETER Instances
        Array of user-selected instances
    .RETURNS
        Path to the generated report file
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject[]]$Results,
        
        [Parameter(Mandatory = $true)]
        [PSCustomObject[]]$Instances
    )

    try {
        Write-Host "Generating Interactive Health Check Report..." -ForegroundColor Cyan
        
        # Get report output path
        $reportPath = Get-InteractiveReportOutputPath
        $reportFileName = "ESS_Interactive_HealthCheck_{0:yyyyMMdd_HHmmss}.html" -f (Get-Date)
        $fullReportPath = Join-Path $reportPath $reportFileName
        
        # Ensure output directory exists
        if (-not (Test-Path $reportPath)) {
            New-Item -ItemType Directory -Path $reportPath -Force | Out-Null
        }
        
        # Generate HTML content
        $htmlContent = New-InteractiveReportHTML -Results $Results -Instances $Instances
        
        # Write report to file
        $htmlContent | Out-File -FilePath $fullReportPath -Encoding UTF8
        
        Write-Host "Interactive health check report generated: $fullReportPath" -ForegroundColor Green
        return $fullReportPath
    }
    catch {
        Write-Error "Error generating interactive health check report: $_"
        throw
    }
}

function Get-InteractiveReportOutputPath {
    <#
    .SYNOPSIS
        Gets the output path for interactive reports
    .DESCRIPTION
        Determines where to save interactive health check reports
    .RETURNS
        Output directory path
    #>
    [CmdletBinding()]
    param()

    # Use temp path
    if ($env:TEMP) {
        return Join-Path $env:TEMP "ESSInteractiveHealthCheckReports"
    }
    
    # Fallback to current directory
    return Join-Path (Get-Location) "ESSInteractiveHealthCheckReports"
}

function New-InteractiveReportHTML {
    <#
    .SYNOPSIS
        Generates HTML content for interactive health check report
    .DESCRIPTION
        Creates HTML report with user-selected instances and health check results
    .PARAMETER Results
        Array of health check results
    .PARAMETER Instances
        Array of user-selected instances
    .RETURNS
        HTML content string
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject[]]$Results,
        
        [Parameter(Mandatory = $true)]
        [PSCustomObject[]]$Instances
    )

    try {
        # Get system information
        $systemInfo = $global:SystemInfo
        
        # Generate report sections
        $header = New-InteractiveReportHeader -SystemInfo $systemInfo -Instances $Instances
        $summary = New-InteractiveReportSummary -Results $Results
        $instanceDetails = New-InteractiveInstanceDetails -Instances $Instances
        $results = New-InteractiveResultsSection -Results $Results
        $footer = New-InteractiveReportFooter
        
        # Combine all sections
        $htmlContent = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ESS Interactive Health Check Report</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 0; padding: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background-color: white; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); overflow: hidden; }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; text-align: center; }
        .header h1 { margin: 0; font-size: 2.5em; font-weight: 300; }
        .header p { margin: 10px 0 0 0; opacity: 0.9; font-size: 1.1em; }
        .content { padding: 30px; }
        .section { margin-bottom: 40px; }
        .section h2 { color: #333; border-bottom: 2px solid #667eea; padding-bottom: 10px; margin-bottom: 20px; }
        .summary-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin-bottom: 30px; }
        .summary-card { background: #f8f9fa; border-radius: 8px; padding: 20px; text-align: center; border-left: 4px solid #667eea; }
        .summary-card h3 { margin: 0 0 10px 0; color: #333; }
        .summary-card .number { font-size: 2em; font-weight: bold; color: #667eea; }
        .instance-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; }
        .instance-card { background: #f8f9fa; border-radius: 8px; padding: 20px; border: 1px solid #e9ecef; }
        .instance-card h4 { margin: 0 0 15px 0; color: #333; }
        .instance-info { margin-bottom: 10px; }
        .instance-info strong { color: #667eea; }
        .results-table { width: 100%; border-collapse: collapse; margin-top: 20px; }
        .results-table th, .results-table td { padding: 12px; text-align: left; border-bottom: 1px solid #e9ecef; }
        .results-table th { background-color: #f8f9fa; font-weight: 600; color: #333; }
        .status-pass { color: #28a745; font-weight: bold; }
        .status-fail { color: #dc3545; font-weight: bold; }
        .status-warning { color: #ffc107; font-weight: bold; }
        .status-info { color: #17a2b8; font-weight: bold; }
        .footer { background-color: #f8f9fa; padding: 20px; text-align: center; color: #6c757d; border-top: 1px solid #e9ecef; }
        .method-badge { display: inline-block; background: #667eea; color: white; padding: 5px 10px; border-radius: 15px; font-size: 0.8em; margin-left: 10px; }
    </style>
</head>
<body>
    <div class="container">
        $header
        <div class="content">
            $summary
            $instanceDetails
            $results
        </div>
        $footer
    </div>
</body>
</html>
"@

        return $htmlContent
    }
    catch {
        Write-Error "Error generating interactive report HTML: $_"
        throw
    }
}

function New-InteractiveReportHeader {
    <#
    .SYNOPSIS
        Generates header section for interactive report
    .DESCRIPTION
        Creates the header with title and system information
    .PARAMETER SystemInfo
        System information object
    .PARAMETER Instances
        Array of user-selected instances
    .RETURNS
        HTML header content
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$SystemInfo,
        
        [Parameter(Mandatory = $true)]
        [PSCustomObject[]]$Instances
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $instanceCount = $Instances.Count
    
    return @"
        <div class="header">
            <h1>ESS Interactive Health Check Report</h1>
            <p>Generated on $timestamp | Computer: $($SystemInfo.ComputerName) | Selected Instances: $instanceCount</p>
            <span class="method-badge">Interactive Mode</span>
        </div>
"@
}

function New-InteractiveReportSummary {
    <#
    .SYNOPSIS
        Generates summary section for interactive report
    .DESCRIPTION
        Creates summary statistics for health check results
    .PARAMETER Results
        Array of health check results
    .RETURNS
        HTML summary content
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject[]]$Results
    )

    # Calculate statistics
    $totalChecks = $Results.Count
    $passCount = ($Results | Where-Object { $_.Status -eq "PASS" }).Count
    $failCount = ($Results | Where-Object { $_.Status -eq "FAIL" }).Count
    $warningCount = ($Results | Where-Object { $_.Status -eq "WARNING" }).Count
    $infoCount = ($Results | Where-Object { $_.Status -eq "INFO" }).Count
    
    $passPercentage = if ($totalChecks -gt 0) { [math]::Round(($passCount / $totalChecks) * 100, 1) } else { 0 }

    return @"
        <div class="section">
            <h2>Health Check Summary</h2>
            <div class="summary-grid">
                <div class="summary-card">
                    <h3>Total Checks</h3>
                    <div class="number">$totalChecks</div>
                </div>
                <div class="summary-card">
                    <h3>Passed</h3>
                    <div class="number status-pass">$passCount</div>
                </div>
                <div class="summary-card">
                    <h3>Failed</h3>
                    <div class="number status-fail">$failCount</div>
                </div>
                <div class="summary-card">
                    <h3>Warnings</h3>
                    <div class="number status-warning">$warningCount</div>
                </div>
                <div class="summary-card">
                    <h3>Info</h3>
                    <div class="number status-info">$infoCount</div>
                </div>
                <div class="summary-card">
                    <h3>Success Rate</h3>
                    <div class="number">$passPercentage%</div>
                </div>
            </div>
        </div>
"@
}

function New-InteractiveInstanceDetails {
    <#
    .SYNOPSIS
        Generates instance details section for interactive report
    .DESCRIPTION
        Creates details about user-selected instances
    .PARAMETER Instances
        Array of user-selected instances
    .RETURNS
        HTML instance details content
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject[]]$Instances
    )

    $instanceCards = ""
    
    foreach ($instance in $Instances) {
        $essSiteUrl = if ($instance.ESSSiteUrl) { $instance.ESSSiteUrl } else { "Not provided" }
        
        $instanceCards += @"
            <div class="instance-card">
                <h4>$($instance.SiteName)$($instance.ApplicationPath)</h4>
                <div class="instance-info"><strong>Type:</strong> $($instance.InstanceType)</div>
                <div class="instance-info"><strong>Alias:</strong> $($instance.Alias)</div>
                <div class="instance-info"><strong>Application Pool:</strong> $($instance.ApplicationPool)</div>
                <div class="instance-info"><strong>Physical Path:</strong> $($instance.PhysicalPath)</div>
                <div class="instance-info"><strong>ESS Site URL:</strong> $essSiteUrl</div>
            </div>
"@
    }

    return @"
        <div class="section">
            <h2>Selected Instances</h2>
            <div class="instance-grid">
                $instanceCards
            </div>
        </div>
"@
}

function New-InteractiveResultsSection {
    <#
    .SYNOPSIS
        Generates results section for interactive report
    .DESCRIPTION
        Creates detailed results table for health checks
    .PARAMETER Results
        Array of health check results
    .RETURNS
        HTML results content
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject[]]$Results
    )

    $resultRows = ""
    
    foreach ($result in $Results) {
        $statusClass = "status-$($result.Status.ToLower())"
        $timestamp = $result.Timestamp.ToString("yyyy-MM-dd HH:mm:ss")
        
        $resultRows += @"
            <tr>
                <td>$($result.Category)</td>
                <td>$($result.Check)</td>
                <td class="$statusClass">$($result.Status)</td>
                <td>$($result.Message)</td>
                <td>$timestamp</td>
            </tr>
"@
    }

    return @"
        <div class="section">
            <h2>Detailed Results</h2>
            <table class="results-table">
                <thead>
                    <tr>
                        <th>Category</th>
                        <th>Check</th>
                        <th>Status</th>
                        <th>Message</th>
                        <th>Timestamp</th>
                    </tr>
                </thead>
                <tbody>
                    $resultRows
                </tbody>
            </table>
        </div>
"@
}

function New-InteractiveReportFooter {
    <#
    .SYNOPSIS
        Generates footer section for interactive report
    .DESCRIPTION
        Creates footer with additional information
    .RETURNS
        HTML footer content
    #>
    [CmdletBinding()]
    param()

    return @"
        <div class="footer">
            <p>ESS Interactive Health Check Report | Generated by ESS Health Checker v2.0</p>
            <p>This report was generated using interactive mode with user-selected instances.</p>
        </div>
"@
}
