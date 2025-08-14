<#
.SYNOPSIS
    Hardware information collection module
.DESCRIPTION
    Collects detailed hardware information including CPU, memory, disk, and network
.NOTES
    Author: Zoe Lai
    Date: 04/08/2025
    Version: 1.0
#>

function Get-HardwareInformation {
    <#
    .SYNOPSIS
        Get hardware information of the system.
    #>
    
    try {
        $computerSystem = Get-CimInstance Win32_ComputerSystem
        $processors = Get-CimInstance Win32_Processor
        $physicalMemory = Get-CimInstance Win32_PhysicalMemory
        $logicalDisks = Get-CimInstance Win32_LogicalDisk

        $totalMemory = ($physicalMemory | Measure-Object -Property Capacity -Sum).Sum
        $totalCores = ($processors | Measure-Object -Property NumberOfCores -Sum).Sum
        $totalLogicalProcessors = ($processors | Measure-Object -Property NumberOfLogicalProcessors -Sum).Sum
        
        # Calculate processor speed information
        $processorSpeeds = $processors | ForEach-Object { $_.MaxClockSpeed }
        $averageProcessorSpeed = ($processorSpeeds | Measure-Object -Average).Average
        $minProcessorSpeed = ($processorSpeeds | Measure-Object -Minimum).Minimum
        $maxProcessorSpeed = ($processorSpeeds | Measure-Object -Maximum).Maximum

        return @{
            Manufacturer = $computerSystem.Manufacturer
            Model = $computerSystem.Model
            TotalPhysicalMemory = [Math]::Round($totalMemory / 1GB, 2)
            TotalCores = $totalCores
            TotalLogicalProcessors = $totalLogicalProcessors
            AverageProcessorSpeedGHz = [Math]::Round($averageProcessorSpeed / 1000, 2)
            MinProcessorSpeedGHz = [Math]::Round($minProcessorSpeed / 1000, 2)
            MaxProcessorSpeedGHz = [Math]::Round($maxProcessorSpeed / 1000, 2)
            Processors = $processors | ForEach-Object {
                @{
                    Name = $_.Name
                    Cores = $_.NumberOfCores
                    LogicalProcessors = $_.NumberOfLogicalProcessors
                    MaxClockSpeed = [Math]::Round($_.MaxClockSpeed / 1000, 2)
                    CurrentClockSpeed = [Math]::Round($_.CurrentClockSpeed / 1000, 2)
                }
            }
            LogicalDisks = $logicalDisks | ForEach-Object {
                @{
                    DeviceID = $_.DeviceID
                    Size = [Math]::Round($_.Size / 1GB, 2)
                    FreeSpace = [Math]::Round($_.FreeSpace / 1GB, 2)
                    FileSystem = $_.FileSystem
                }
            }
        }
    }
    catch {
        Write-Warning "Could not retrieve hardware information: $_"
        return @{}
    }
}

function Get-NetworkInformation {
    <#
    .SYNOPSIS
        Get network information of the system.
    #>
    
    try {
        $networkAdapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }
        $ipConfig = Get-NetIPConfiguration | Where-Object { $_.IPv4Address}
        $dnsServers = Get-DnsClientServerAddress | Where-Object { $_.ServerAddresses }
        
        return @{
            NetworkAdapters = $networkAdapters | ForEach-Object {
                @{
                    Name = $_.Name
                    InterfaceDescription = $_.InterfaceDescription
                    Status = $_.Status
                    MACAddress = $_.MacAddress
                }
            }
            IPConfigurations = $ipConfig | ForEach-Object {
                @{
                    InterfaceAlias = $_.InterfaceAlias
                    IPv4Address = $_.IPv4Address.IPAddressToString
                    IPv4DefaultGateway = $_.IPv4DefaultGateway.NextHop
                    SubnetMask = $_.IPv4Address.PrefixLength
                }
            }
            DNSServers = $dnsServers | ForEach-Object {
                @{
                    InterfaceAlias = $_.InterfaceAlias
                    ServerAddresses = $_.ServerAddresses
                }
            }
        }
    }
    catch {
        Write-Warning "Could not retrieve network information: $_"
        return @{}  
    }
} 