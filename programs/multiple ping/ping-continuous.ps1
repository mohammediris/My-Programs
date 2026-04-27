param(
    [string]$CsvFile = "ips.csv",
    [int]$IntervalSeconds = 5,
    [string]$ReportCsvFile = "ping-report.csv",
    [string]$DisconnectReportCsvFile = "ping-disconnect-report.csv",
    [switch]$RunOnce
)

<#
.SYNOPSIS
    Continuous live ping monitor.

.DESCRIPTION
    Starts a continuous ping (-t) process for every host and refreshes the screen every interval.
    Status is shown as connected or disconnected with the ping failure reason in brackets.
    Press R to export the current status report; press Q to quit and export disconnect intervals.
#>

if (-not (Test-Path $CsvFile)) {
    Write-Host "Error: CSV file '$CsvFile' not found. Please create it with IP addresses." -ForegroundColor Red
    exit 1
}

$hosts = Import-Csv $CsvFile
if ($hosts.Count -eq 0) {
    Write-Host "Error: No hosts found in CSV file." -ForegroundColor Red
    exit 1
}

if (-not $hosts[0].PSObject.Properties.Name.Contains('IP')) {
    Write-Host "Error: CSV file must contain an 'IP' column." -ForegroundColor Red
    exit 1
}

$hostStatus = @{}
foreach ($entry in $hosts) {
    $ip = $entry.IP.Trim()
    if (-not $ip) { continue }
    $hostname = if ($entry.PSObject.Properties.Name.Contains('Hostname') -and $entry.Hostname) { $entry.Hostname } else { $ip }
    $hostStatus[$ip] = [PSCustomObject]@{
        Hostname = $hostname
        IP = $ip
        Status = 'disconnected (starting)'
        LastStatus = 'disconnected (starting)'
        LastChange = Get-Date
        CurrentDisconnect = $null
        DisconnectPeriods = @()
        Updated = Get-Date
    }
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$reportCsvPath = Join-Path $scriptDir $ReportCsvFile
$disconnectReportCsvPath = Join-Path $scriptDir $DisconnectReportCsvFile

function Export-CurrentReport {
    $hostStatus.Values | Select-Object Hostname, IP, Status, @{Name='Updated';Expression={($_.Updated).ToString('yyyy-MM-dd HH:mm:ss')}} | Export-Csv -Path $reportCsvPath -NoTypeInformation
    Write-Host "Current status report exported to $reportCsvPath" -ForegroundColor Green
}

function Export-DisconnectReport {
    $now = Get-Date
    foreach ($entry in $hostStatus.Values) {
        if ($entry.CurrentDisconnect) {
            $entry.CurrentDisconnect.End = $now
            $entry.CurrentDisconnect.Duration = $entry.CurrentDisconnect.End - $entry.CurrentDisconnect.Start
            $entry.DisconnectPeriods += $entry.CurrentDisconnect
            $entry.CurrentDisconnect = $null
        }
    }

    $rows = @()
    foreach ($entry in $hostStatus.Values | Sort-Object Hostname) {
        foreach ($interval in $entry.DisconnectPeriods) {
            $rows += [PSCustomObject]@{
                Hostname = $entry.Hostname
                IP = $entry.IP
                Start = $interval.Start.ToString('yyyy-MM-dd HH:mm:ss')
                End = $interval.End.ToString('yyyy-MM-dd HH:mm:ss')
                Duration = ([math]::Round($interval.Duration.TotalSeconds, 1)).ToString() + 's'
                Reason = $interval.Reason
            }
        }
    }

    if ($rows.Count -eq 0) {
        Write-Host "No disconnect intervals recorded." -ForegroundColor Yellow
        return
    }

    $rows | Export-Csv -Path $disconnectReportCsvPath -NoTypeInformation
    Write-Host "Disconnect report exported to $disconnectReportCsvPath" -ForegroundColor Green
}

function Update-HostStatus {
    param($ip, $newStatus)

    $entry = $hostStatus[$ip]
    $currentTime = Get-Date
    $prevStatus = $entry.LastStatus

    if ($prevStatus -ne $newStatus) {
        $wasConnected = $prevStatus -eq 'connected'
        $isConnected = $newStatus -eq 'connected'

        if ($wasConnected -and -not $isConnected) {
            $entry.CurrentDisconnect = [PSCustomObject]@{
                Start = $currentTime
                Reason = $newStatus
                End = $null
                Duration = $null
            }
        } elseif (-not $wasConnected -and $isConnected) {
            if ($entry.CurrentDisconnect) {
                $entry.CurrentDisconnect.End = $currentTime
                $entry.CurrentDisconnect.Duration = $entry.CurrentDisconnect.End - $entry.CurrentDisconnect.Start
                $entry.DisconnectPeriods += $entry.CurrentDisconnect
                $entry.CurrentDisconnect = $null
            }
        }

        $entry.LastStatus = $newStatus
        $entry.LastChange = $currentTime
    }

    $entry.Status = $newStatus
    $entry.Updated = $currentTime
}

function Get-PingStatusFromLine {
    param($line)
    if (-not $line) { return $null }
    if ($line -match 'Reply from') { return 'connected' }
    if ($line -match 'Request timed out') { return 'disconnected (Request timed out)' }
    if ($line -match 'Destination host unreachable') { return 'disconnected (Destination host unreachable)' }
    if ($line -match 'General failure') { return 'disconnected (General failure)' }
    if ($line -match 'Ping request could not find host|Could not find host') { return 'disconnected (Could not find host)' }
    if ($line -match 'TTL expired in transit') { return 'disconnected (TTL expired in transit)' }
    if ($line -match 'Unknown host') { return 'disconnected (Unknown host)' }
    return $null
}

function Start-PingJobs {
    $jobs = @()
    foreach ($ip in $hostStatus.Keys) {
        $hostStatus[$ip].Status = 'disconnected (starting)'
        $hostStatus[$ip].Updated = Get-Date

        $job = Start-Job -ScriptBlock {
            param($ip)
            ping.exe -t $ip 2>&1 | ForEach-Object { Write-Output $_ }
        } -ArgumentList $ip
        $job | Add-Member -NotePropertyName TargetIP -NotePropertyValue $ip -Force
        $jobs += $job
    }
    return $jobs
}

$jobs = Start-PingJobs

while ($true) {
    foreach ($job in $jobs) {
        $lines = Receive-Job -Job $job -ErrorAction SilentlyContinue
        foreach ($line in $lines) {
            $statusText = Get-PingStatusFromLine -line $line
            if ($statusText) {
                Update-HostStatus -ip $job.TargetIP -newStatus $statusText
            }
        }
    }

    [Console]::Clear()
    $title = "Ping Monitor - Live - $(Get-Date -Format 'HH:mm:ss')"
    Write-Host $title -ForegroundColor Cyan
    Write-Host ("=" * $title.Length) -ForegroundColor Cyan
    Write-Host "Press 'Q' to exit, 'R' to export current status" -ForegroundColor Yellow
    Write-Host ''

    $hostnameWidth = [Math]::Max(10, ($hostStatus.Values.Hostname | Measure-Object -Maximum -Property Length).Maximum + 2)
    $ipWidth = [Math]::Max(15, ($hostStatus.Values.IP | Measure-Object -Maximum -Property Length).Maximum + 2)
    $statusWidth = 50
    Write-Host ("{0,-$hostnameWidth}{1,-$ipWidth}{2,-$statusWidth}" -f 'Hostname', 'IP Address', 'Status') -ForegroundColor White
    Write-Host ("-" * ($hostnameWidth + $ipWidth + $statusWidth)) -ForegroundColor White

    foreach ($item in $hostStatus.Values | Sort-Object Hostname) {
        $color = if ($item.Status -eq 'connected') { 'Green' } else { 'Red' }
        Write-Host ("{0,-$hostnameWidth}{1,-$ipWidth}{2,-$statusWidth}" -f $item.Hostname, $item.IP, $item.Status) -ForegroundColor $color
    }

    if ([Console]::KeyAvailable) {
        $key = [Console]::ReadKey($true)
        if ($key.KeyChar -eq 'q' -or $key.KeyChar -eq 'Q') {
            Write-Host "`nExiting..." -ForegroundColor Yellow
            Export-DisconnectReport
            foreach ($job in $jobs) {
                if ($job.State -ne 'Completed') {
                    Stop-Job -Job $job -ErrorAction SilentlyContinue
                }
                Remove-Job -Job $job -ErrorAction SilentlyContinue
            }
            break
        } elseif ($key.KeyChar -eq 'r' -or $key.KeyChar -eq 'R') {
            Export-CurrentReport
            Start-Sleep -Seconds 2
        }
    }

    if ($RunOnce) {
        foreach ($job in $jobs) {
            if ($job.State -ne 'Completed') {
                Stop-Job -Job $job -ErrorAction SilentlyContinue
            }
            Remove-Job -Job $job -ErrorAction SilentlyContinue
        }
        break
    }

    Start-Sleep -Seconds $IntervalSeconds
}
