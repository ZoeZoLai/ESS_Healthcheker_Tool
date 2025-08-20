<#
.SYNOPSIS
    Generates HTML reports from health check results
.DESCRIPTION
    Creates HTML reports from ESS Pre-Upgrade Health Check results
.NOTES
    Author: Zoe Lai
    Date: 04/08/2025
    Version: 1.2
#>

function New-HealthCheckReport {
    <#
    .SYNOPSIS
        Generates an HTML health check report
    .DESCRIPTION
        Creates a comprehensive HTML report from health check results
    .PARAMETER Results
        Array of health check results
    .PARAMETER OutputPath
        Optional output path for the report
    .RETURNS
        Path to the generated report
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$Results,
        
        [Parameter(Mandatory = $false)]
        [string]$OutputPath = $null
    )

    try {
        Write-Verbose "Generating health check report..."
        
        # Determine output path
        if (-not $OutputPath) {
            $OutputPath = $global:ESSConfig.ReportOutputPath
        }
        
        # Create output directory if it doesn't exist
        if (-not (Test-Path $OutputPath)) {
            New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
        }
        
        # Generate report filename
        $reportName = $global:ESSConfig.ReportNameFormat -f (Get-Date)
        $reportPath = Join-Path $OutputPath $reportName
        
        # Generate HTML content
        $htmlContent = New-ReportHTML -Results $Results
        
        # Write report to file
        $htmlContent | Out-File -FilePath $reportPath -Encoding UTF8
        
        Write-Host "Report generated successfully at: $reportPath" -ForegroundColor Green
        return $reportPath
    }
    catch {
        Write-Error "Failed to generate health check report: $_"
        throw
    }
}

function New-ReportHTML {
    <#
    .SYNOPSIS
        Generates HTML content for the health check report
    .PARAMETER Results
        Array of health check results
    .RETURNS
        HTML content as string
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$Results
    )

    $sysInfo = $global:SystemInfo
    # $config = $global:ESSConfig
    
    # Get detection results for displaying all instances
    $detectionResults = $global:DetectionResults
    

    
    # Calculate summary statistics
    $summary = Get-HealthCheckSummary
    $totalChecks = $summary.Total
    $passChecks = $summary.Pass
    $failChecks = $summary.Fail
    $warningChecks = $summary.Warning
    $infoChecks = $summary.Info
    
    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ESS Pre-Upgrade Health Check Report</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            line-height: 1.6;
            margin: 0;
            padding: 20px;
            background-color: #f5f5f5;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background-color: white;
            border-radius: 8px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            overflow: hidden;
        }
        .header {
            background: linear-gradient(135deg, #C497FE 0%, #7B14EF 100%);
            color: white;
            padding: 30px;
            text-align: center;
        }
        .header h1 {
            margin: 0;
            font-size: 2.5em;
            font-weight: 300;
        }
        .header p {
            margin: 10px 0 0 0;
            opacity: 0.9;
        }
        .content {
            padding: 30px;
        }
        .section {
            margin-bottom: 30px;
            border: 1px solid #e0e0e0;
            border-radius: 6px;
            overflow: hidden;
        }
        .section-header {
            background-color: #f8f9fa;
            padding: 15px 20px;
            border-bottom: 1px solid #e0e0e0;
            font-weight: 600;
            color: #495057;
        }
        .section-content {
            padding: 20px;
        }
        .info-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
            margin-bottom: 20px;
        }
        .info-card {
            background-color: #f8f9fa;
            padding: 15px;
            border-radius: 6px;
            border-left: 4px solid #7B14EF;
        }
        .info-card h4 {
            margin: 0 0 10px 0;
            color: #495057;
        }
        .info-item {
            display: flex;
            justify-content: space-between;
            margin-bottom: 8px;
        }
        .info-label {
            font-weight: 500;
            color: #6c757d;
        }
        .info-value {
            color: #495057;
        }
        .status-pass {
            color: #28a745;
            font-weight: 600;
        }
        .status-fail {
            color: #dc3545;
            font-weight: 600;
        }
        .status-warning {
            color: #ffc107;
            font-weight: 600;
        }
        .status-info {
            color: #17a2b8;
            font-weight: 600;
        }
        .requirements-table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 15px;
        }
        .requirements-table th,
        .requirements-table td {
            padding: 12px;
            text-align: left;
            border-bottom: 1px solid #e0e0e0;
        }
        .requirements-table th {
            background-color: #f8f9fa;
            font-weight: 600;
            color: #495057;
        }
        .requirements-table tr:hover {
            background-color: #f8f9fa;
        }
        .instances-table {
            width: 100%;
            border-collapse: collapse;
            margin: 20px 0;
            font-size: 0.85em;
            table-layout: fixed;
            word-wrap: break-word;
        }
        .instances-table th,
        .instances-table td {
            border: 1px solid #ddd;
            padding: 6px 8px;
            text-align: left;
            vertical-align: top;
            word-wrap: break-word;
            overflow-wrap: break-word;
        }
        .instances-table th {
            background-color: #f8f9fa;
            font-weight: 600;
            color: #495057;
            white-space: nowrap;
        }
        .instances-table tr:hover {
            background-color: #f5f5f5;
        }
        .table-container {
            overflow-x: auto;
            margin: 20px 0;
            border: 1px solid #ddd;
            border-radius: 4px;
        }
        /* Responsive table for smaller screens */
        @media (max-width: 1200px) {
            .instances-table {
                font-size: 0.8em;
            }
            .instances-table th,
            .instances-table td {
                padding: 4px 6px;
            }
        }
        @media (max-width: 900px) {
            .instances-table {
                font-size: 0.75em;
            }
            .instances-table th,
            .instances-table td {
                padding: 3px 4px;
            }
        }
        .footer {
            background-color: #f8f9fa;
            padding: 20px;
            text-align: center;
            color: #6c757d;
            border-top: 1px solid #e0e0e0;
        }
        .summary-stats {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
            margin-bottom: 30px;
        }
        .stat-card {
            background: linear-gradient(135deg, #c497fe 0%, #7b14ef 100%);
            color: white;
            padding: 20px;
            border-radius: 8px;
            text-align: center;
        }
        .stat-number {
            font-size: 2em;
            font-weight: bold;
            margin-bottom: 5px;
        }
        .stat-label {
            opacity: 0.9;
        }
        .health-results {
            margin-top: 20px;
        }
        .health-result {
            padding: 10px;
            margin-bottom: 8px;
            border-radius: 4px;
            border-left: 4px solid;
        }
        .health-result.pass {
            background-color: #d4edda;
            border-left-color: #28a745;
        }
        .health-result.fail {
            background-color: #f8d7da;
            border-left-color: #dc3545;
        }
        .health-result.warning {
            background-color: #fff3cd;
            border-left-color: #ffc107;
        }
        .health-result.info {
            background-color: #d1ecf1;
            border-left-color: #17a2b8;
        }
        
        /* Enhanced API Health Check Styles */
        .health-result.http-status {
            background-color: #e3f2fd;
            border-left-color: #2196f3;
            font-weight: 500;
        }
        .health-result.component-messages {
            background-color: #fff8e1;
            border-left-color: #ff9800;
            font-style: italic;
        }
        .health-result.component-result {
            background-color: #f3e5f5;
            border-left-color: #9c27b0;
        }
        .message-content {
            display: block;
            margin-top: 5px;
            line-height: 1.4;
        }
        .deployment-summary {
            background-color: #e9ecef;
            padding: 15px;
            border-radius: 6px;
            margin-bottom: 20px;
        }
        .deployment-summary h4 {
            margin: 0 0 10px 0;
            color: #495057;
        }
        .recommendations-table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 15px;
        }
        .recommendations-table th,
        .recommendations-table td {
            padding: 12px;
            text-align: left;
            border-bottom: 1px solid #e0e0e0;
        }
        .recommendations-table th {
            background-color: #f8f9fa;
            font-weight: 600;
            color: #495057;
        }
        .recommendations-table tr:hover {
            background-color: #f8f9fa;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>ESS Pre-Upgrade Health Check Report</h1>
            <p>Generated on $(Get-Date -Format "MMMM dd, yyyy 'at' HH:mm:ss")</p>
        </div>
        
        <div class="content">
            <!-- Executive Summary -->
            <div class="summary-stats">
                <div class="stat-card">
                    <div class="stat-number">$(if ($global:DetectionResults -and $global:DetectionResults.ESSInstances.Count -gt 0) { "Installed" } else { "Not Installed" })</div>
                    <div class="stat-label">ESS Status</div>
                </div>
                <div class="stat-card">
                    <div class="stat-number">$(if ($global:DetectionResults -and $global:DetectionResults.WFEInstances.Count -gt 0) { "Installed" } else { "Not Installed" })</div>
                    <div class="stat-label">WFE Status</div>
                </div>
                <div class="stat-card">
                    <div class="stat-number">$(if ($sysInfo.SQLServer.IsInstalled) { "Installed" } else { "Not Installed" })</div>
                    <div class="stat-label">SQL Server</div>
                </div>
                <div class="stat-card">
                    <div class="stat-number">$passChecks/$totalChecks</div>
                    <div class="stat-label">Checks Passed</div>
                </div>
                <div class="stat-card">
                    <div class="stat-number">$failChecks</div>
                    <div class="stat-label">Failed Checks</div>
                </div>
                <div class="stat-card">
                    <div class="stat-number">$warningChecks</div>
                    <div class="stat-label">Warnings</div>
                </div>
                <div class="stat-card">
                    <div class="stat-number">$infoChecks</div>
                    <div class="stat-label">Info Items</div>
                </div>
            </div>

            <!-- Deployment Overview -->
            <div class="section">
                <div class="section-header">Deployment Overview</div>
                <div class="section-content">
                    <div class="deployment-summary">
                        <h4>Current Deployment Structure</h4>
                        <div class="info-item">
                            <span class="info-label">Server:</span>
                            <span class="info-value">$($sysInfo.ComputerName)</span>
                        </div>
                        <div class="info-item">
                            <span class="info-label">Deployment Type:</span>
                            <span class="info-value">$(if ($global:DetectionResults) { $global:DetectionResults.DeploymentType } else { 'Unknown' })</span>
                        </div>
                        <div class="info-item">
                            <span class="info-label">Operating System:</span>
                            <span class="info-value">$($sysInfo.OS.Caption) $(if ($sysInfo.OS.IsServer) { '(Server)' } else { '(Client)' })</span>
                        </div>
                        <div class="info-item">
                            <span class="info-label">IIS Status:</span>
                            <span class="info-value $(if ($sysInfo.IIS.IsInstalled) { 'status-pass' } else { 'status-fail' })">$(if ($sysInfo.IIS.IsInstalled) { "Installed ($($sysInfo.IIS.Version))" } else { "Not Installed" })</span>
                        </div>
                    </div>
                    
                    <div class="info-grid">
                        <div class="info-card">
                            <h4>System Information</h4>
                            <div class="info-item">
                                <span class="info-label">Memory:</span>
                                <span class="info-value">$($sysInfo.Hardware.TotalPhysicalMemory) GB</span>
                            </div>
                            <div class="info-item">
                                <span class="info-label">CPU Cores:</span>
                                <span class="info-value">$($sysInfo.Hardware.TotalCores)</span>
                            </div>
                            <div class="info-item">
                                <span class="info-label">Processor Speed:</span>
                                <span class="info-value">$($sysInfo.Hardware.AverageProcessorSpeedGHz) GHz</span>
                            </div>
                            <div class="info-item">
                                <span class="info-label">Disk Space (C:):</span>
                                <span class="info-value">$([math]::Round(($sysInfo.Hardware.LogicalDisks | Where-Object { $_.DeviceID -eq 'C:' } | Select-Object -First 1).Size, 2)) GB</span>
                            </div>
                        </div>
                        
                        <div class="info-card">
                            <h4>Software Requirements</h4>
                            <div class="info-item">
                                <span class="info-label">.NET Framework:</span>
                                <span class="info-value">$(if ($sysInfo.Registry.DotNetVersions -and $sysInfo.Registry.DotNetVersions.Count -gt 0) { ($sysInfo.Registry.DotNetVersions | Sort-Object -Descending | Select-Object -First 1) } else { 'Not Installed' })</span>
                            </div>
                            <div class="info-item">
                                <span class="info-label">IIS Sites:</span>
                                <span class="info-value">$($sysInfo.IIS.Sites.Count) sites</span>
                            </div>
                            <div class="info-item">
                                <span class="info-label">Application Pools:</span>
                                <span class="info-value">$($sysInfo.IIS.ApplicationPools.Count) pools</span>
                            </div>
                            $(if ($sysInfo.SQLServer.IsInstalled) {
                                @"
                            <div class="info-item">
                                <span class="info-label">SQL Server:</span>
                                <span class="info-value">$($sysInfo.SQLServer.Instances.Count) instance$(if($sysInfo.SQLServer.Instances.Count -ne 1){'s'}) - $($sysInfo.SQLServer.Versions -join ', ')</span>
                            </div>
"@
                            })
                        </div>
                    </div>
                </div>
            </div>

            <!-- ESS/WFE Instances -->
            <div class="section">
                <div class="section-header">ESS and WFE Instances</div>
                <div class="section-content">
                    $(if ($detectionResults -and $detectionResults.ESSInstances.Count -gt 0) { 
                        $essTable = @"
                    <h4>ESS Instances Found: $($detectionResults.ESSInstances.Count)</h4>
                    <div class="table-container">
                    <table class="instances-table">
                        <thead>
                            <tr>
                                <th>Site Name</th>
                                <th>App Pool</th>
                                <th>Pool Identity</th>
                                <th>Install Path</th>
                                <th>Web Server URL</th>
                                <th>Database Server</th>
                                <th>DB Name</th>
                                <th>Tenant ID</th>
                                <th>Auth Mode</th>
                            </tr>
                        </thead>
                        <tbody>
"@
                        foreach ($ess in $detectionResults.ESSInstances) {
                            $poolIdentity = Get-AppPoolIdentity -AppPoolName $ess.ApplicationPool
                            $webServerUrl = Get-WebServerURL -ESSInstance $ess
                            
                            # Format site name to include application alias using helper function
                            $siteNameDisplay = Get-FormattedSiteIdentifier -SiteName $ess.SiteName -ApplicationPath $ess.ApplicationPath
                            
                            # Format Auth Mode to include encryption status for SingleSignOn
                            $authModeDisplay = $ess.AuthenticationMode
                            if ($ess.AuthenticationMode -eq "SingleSignOn" -and $ess.WebConfigEncrypted) {
                                $authModeDisplay = "SingleSignOn (encrypted)"
                            }
                            
                            $essTable += @"
                            <tr>
                                <td>$siteNameDisplay</td>
                                <td>$($ess.ApplicationPool)</td>
                                <td>$poolIdentity</td>
                                <td>$($ess.PhysicalPath)</td>
                                <td>$webServerUrl</td>
                                <td>$($ess.DatabaseServer)</td>
                                <td>$($ess.DatabaseName)</td>
                                <td>$($ess.TenantID)</td>
                                <td>$authModeDisplay</td>
                            </tr>
"@
                        }
                        $essTable += @"
                        </tbody>
                    </table>
                    </div>
"@
                        $essTable
                    } else { 
                        "<p>No ESS instances found on this machine.</p>"
                    })
                    
                    $(if ($detectionResults -and $detectionResults.WFEInstances.Count -gt 0) { 
                        $wfeTable = @"
                    <h4>WFE Instances Found: $($detectionResults.WFEInstances.Count)</h4>
                    <div class="table-container">
                    <table class="instances-table">
                        <thead>
                            <tr>
                                <th>Site Name</th>
                                <th>App Pool</th>
                                <th>Pool Identity</th>
                                <th>Install Path</th>
                                <th>Database Server</th>
                                <th>DB Name</th>
                                <th>Tenant ID</th>
                                <th>Client URL</th>
                            </tr>
                        </thead>
                        <tbody>
"@
                        foreach ($wfe in $detectionResults.WFEInstances) {
                            $poolIdentity = Get-AppPoolIdentity -AppPoolName $wfe.ApplicationPool
                            
                            # Format site name to include application alias using helper function
                            $siteNameDisplay = Get-FormattedSiteIdentifier -SiteName $wfe.SiteName -ApplicationPath $wfe.ApplicationPath
                            
                            $wfeTable += @"
                            <tr>
                                <td>$siteNameDisplay</td>
                                <td>$($wfe.ApplicationPool)</td>
                                <td>$poolIdentity</td>
                                <td>$($wfe.PhysicalPath)</td>
                                <td>$($wfe.DatabaseServer)</td>
                                <td>$($wfe.DatabaseName)</td>
                                <td>$($wfe.TenantID)</td>
                                <td>$($wfe.ClientURL)</td>
                            </tr>
"@
                        }
                        $wfeTable += @"
                        </tbody>
                    </table>
                    </div>
"@
                        $wfeTable
                    } else { 
                        "<p>No WFE instances found on this machine.</p>"
                    })
                </div>
            </div>



            <!-- Health Check Results -->
            <div class="section">
                <div class="section-header">Health Check Results</div>
                <div class="section-content">
                    <div class="health-results">
                        $(foreach ($result in $Results) {
                            $statusClass = $result.Status.ToLower()
                            $messageClass = ""
                            
                            # Add special styling for ESS API results
                            if ($result.Category -like "*ESS API*") {
                                # Add special styling for HTTP status codes
                                if ($result.Check -like "*HTTP Status*") {
                                    $messageClass = "http-status"
                                }
                                # Add special styling for component messages
                                elseif ($result.Check -like "*Component Messages*") {
                                    $messageClass = "component-messages"
                                }
                                # Add special styling for component results
                                elseif ($result.Category -eq "ESS API Components") {
                                    $messageClass = "component-result"
                                }
                            }
                            
                            @"
                        <div class="health-result $statusClass $messageClass">
                            <strong>[$($result.Status)] $($result.Category) - $($result.Check)</strong><br>
                            $(if ($result.Category -like "*ESS API*") { "<span class='message-content'>$($result.Message)</span>" } else { $result.Message })
                        </div>
"@
                        })
                    </div>
                </div>
            </div>


        </div>
        
        <div class="footer">
            <p>ESS Pre-Upgrade Health Check Report - Generated by MYOB PayGlobal ESS Health Checker</p>
        </div>
    </div>
</body>
</html>
"@

    return $html
}

