param(
    [string]$CsvFile = "ips.csv",
    [int]$PingCount = 5,
    [int]$IntervalSeconds = 5,
    [string]$OutputLogFile = "ping-results.txt",
    [switch]$RunOnce,
    [switch]$NoLoop,
    [switch]$Verbose,
    [switch]$Debug
)

<#
.SYNOPSIS
    Multi-host ping monitoring tool with real-time display and logging.

.DESCRIPTION
    Pings multiple hosts from a CSV file, displays status in real-time,
    logs results, and supports various configuration options.

.PARAMETER CsvFile
    Path to CSV file containing IP addresses (default: ips.csv)

.PARAMETER PingCount
    Number of pings per host per cycle (default: 5)

.PARAMETER IntervalSeconds
    Seconds between cycles (default: 5)

.PARAMETER OutputLogFile
    Path to output log file (default: ping-results.txt)

.PARAMETER RunOnce
    Run one cycle and exit

.PARAMETER NoLoop
    Disable continuous looping

.PARAMETER Verbose
    Enable verbose output

.PARAMETER Debug
    Enable debug output

.EXAMPLE
    .\ping-multiple.ps1 -CsvFile "servers.csv" -PingCount 3 -IntervalSeconds 10

.EXAMPLE
    .\ping-multiple.ps1 -RunOnce -Verbose
#>

# Import IPs from CSV file
# Assumes CSV has columns: IP (required), Hostname (optional)
if (-not (Test-Path $CsvFile)) {
    Write-Host "Error: CSV file '$CsvFile' not found. Please create it with IP addresses." -ForegroundColor Red
    exit 1
}

$ips = Import-Csv $CsvFile

if ($ips.Count -eq 0) {
    Write-Host "Error: No IP addresses found in CSV file." -ForegroundColor Red
    exit 1
}

# Validate that IP column exists
if (-not $ips[0].PSObject.Properties.Name.Contains('IP')) {
    Write-Host "Error: CSV file must contain an 'IP' column." -ForegroundColor Red
    exit 1
}

$cycle = 1
$totalHosts = $ips.Count

# Initialize per-host history
$hostHistory = @{}
foreach ($ipObj in $ips) {
    $ip = $ipObj.IP
    $hostname = if ($ipObj.Hostname) { $ipObj.Hostname } else { $ip }
    $hostHistory[$ip] = @{
        Hostname = $hostname
        History = New-Object System.Collections.Generic.Queue[PSCustomObject]
        ConsecutiveFailures = 0
        LastState = "unknown"
    }
}

# Infinite loop to continuously ping all IPs
while ($true) {
    # Initialize status hashtable with objects
    $status = @{}
    $jobs = @()
    
    # Start ping jobs for all IPs (throttled to 10 concurrent)
    $jobCount = 0
    foreach ($ipObj in $ips) {
        $ip = $ipObj.IP
        $hostname = if ($ipObj.Hostname) { $ipObj.Hostname } else { $ip }
        $status[$ip] = [PSCustomObject]@{
            Hostname = $hostname
            IP = $ip
            State = "trying"
            AvgMs = "-"
            LastPingMs = "-"
            Errors = 0
            ResponseTimes = @()
        }
        
        $job = Start-Job -ScriptBlock {
            param($ip, $pingCount)
            $responseTimes = @()
            $errors = 0
            for ($i = 1; $i -le $pingCount; $i++) {
                Write-Output "ping_$i"
                try {
                    $pingResult = Test-Connection -ComputerName $ip -Count 1 -ErrorAction Stop
                    if ($pingResult -and $pingResult.Status -eq 'Success') {
                        $responseTimes += $pingResult.Latency
                    } else {
                        $errors++
                    }
                } catch {
                    $errors++
                }
                Start-Sleep -Milliseconds 200
            }
            
            if ($responseTimes.Count -gt 0) {
                $average = [math]::Round(($responseTimes | Measure-Object -Average).Average, 2)
                Write-Output "connected|$average|$errors"
            } else {
                Write-Output "not reachable|-|$errors"
            }
        } -ArgumentList $ip, $PingCount
        
        $job | Add-Member -NotePropertyName IP -NotePropertyValue $ip -Force
        $jobs += $job
        $jobCount++
        
        # Throttle to 10 concurrent jobs
        if ($jobCount % 10 -eq 0) {
            Start-Sleep -Milliseconds 100
        }
    }
    
    # Monitor jobs and update display in realtime
    $runningJobs = $jobs | Where-Object { $_.State -eq 'Running' }
    while ($runningJobs.Count -gt 0) {
        $remaining = ($status.Values | Where-Object { $_.State -eq "trying" }).Count
        
        # Calculate column widths
        $hostnameWidth = [Math]::Max(10, ($status.Values.Hostname | Measure-Object -Maximum -Property Length).Maximum + 2)
        $ipWidth = [Math]::Max(15, ($status.Keys | Measure-Object -Maximum -Property Length).Maximum + 2)
        $statusWidth = 15
        $tableWidth = $hostnameWidth + $ipWidth + $statusWidth

        $title = "Cycle $cycle - Ping Status at $(Get-Date -Format 'HH:mm:ss')"
        $remainingText = "Remaining hosts: $remaining out of $totalHosts"
        $quitText = "Press 'Q' to exit, 'R' for report"
        $maxTextWidth = [Math]::Max([Math]::Max($title.Length, $remainingText.Length), $quitText.Length)
        $totalWidth = [Math]::Max($tableWidth, $maxTextWidth)

        # Protect against too-large width causing Console exceptions
        $consoleWidth = [Console]::WindowWidth
        if ($consoleWidth -lt 20) { $consoleWidth = 80 }
        if ($totalWidth -ge $consoleWidth) { $totalWidth = $consoleWidth - 1 }

        # If the table is bigger than available, clamp columns to fit
        if ($tableWidth -ge $totalWidth) {
            $hostnameWidth = [Math]::Min($hostnameWidth, $totalWidth - ($ipWidth + $statusWidth))
            $ipWidth = [Math]::Min($ipWidth, $totalWidth - ($hostnameWidth + $statusWidth))
            $statusWidth = [Math]::Min($statusWidth, $totalWidth - ($hostnameWidth + $ipWidth))
            $tableWidth = $hostnameWidth + $ipWidth + $statusWidth
        }

        # Use a standard screen clear to avoid mixed-screen artifacts.
        [Console]::Clear()
        Write-Host ("═" * $totalWidth) -ForegroundColor Cyan
        Write-Host $title -ForegroundColor Cyan
        Write-Host $remainingText -ForegroundColor Magenta
        Write-Host $quitText -ForegroundColor Yellow
        Write-Host ("═" * $totalWidth) -ForegroundColor Cyan
        Write-Host ("{0,-$hostnameWidth}{1,-$ipWidth}{2,-$statusWidth}" -f "Hostname", "IP Address", "Status") -ForegroundColor White
        Write-Host ("-" * $tableWidth) -ForegroundColor White
        
        foreach ($ip in $status.Keys | Sort-Object) {
            $stat = $status[$ip].State
            $hostname = $status[$ip].Hostname
            $color = if ($stat -eq "trying") { "Yellow" } elseif ($stat -eq "connected") { "Green" } elseif ($stat -eq "not reachable") { "Red" } else { "White" }
            Write-Host ("{0,-$hostnameWidth}{1,-$ipWidth}{2,-$statusWidth}" -f $hostname, $ip, $stat) -ForegroundColor $color
        }
        Write-Host ("═" * $totalWidth) -ForegroundColor Cyan
        
        
        # Check for user input to exit or report
        if ([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true)
            if ($key.KeyChar -eq 'q' -or $key.KeyChar -eq 'Q') {
                Write-Host "`nExiting program..." -ForegroundColor Yellow
                # Clean up any remaining jobs
                $jobs | ForEach-Object { Remove-Job $_ -Force }
                exit 0
            } elseif ($key.KeyChar -eq 'r' -or $key.KeyChar -eq 'R') {
                # Generate CSV report
                $csvFile = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'ping-report.csv'
                $status.Values | Select-Object Hostname, IP, State, AvgMs, LastPingMs, Errors | Export-Csv -Path $csvFile -NoTypeInformation
                Write-Host "`nReport saved to $csvFile" -ForegroundColor Green
                Start-Sleep -Seconds 2
            }
        }
        
        Start-Sleep -Milliseconds 500
        
        # Update status for completed jobs and get progress from running ones
        foreach ($job in $jobs) {
            $ip = $job.IP
            if ($job.State -eq 'Completed') {
                if ($status[$ip].State -eq "trying") {
                    try {
                        $results = Receive-Job $job
                        $finalOutput = $results[-1]  # Last output is the final result
                        
                        # Parse the result format: "status|averageTime|errors"
                        if ($finalOutput -like "*|*|*") {
                            $parts = $finalOutput -split "\|"
                            $status[$ip].State = $parts[0]
                            $status[$ip].AvgMs = if ($parts[1] -ne "-") { "$($parts[1]) ms" } else { "-" }
                            $status[$ip].Errors = [int]$parts[2]
                        } else {
                            $status[$ip].State = $finalOutput
                        }
                    } catch {
                        $status[$ip].State = "error"
                        $status[$ip].Errors++
                        if ($Debug) { Write-Host "Job error for $ip : $_" -ForegroundColor Red }
                    }
                    Remove-Job $job
                }
            } elseif ($job.State -eq 'Running') {
                # If job is still running, keep status on trying.
                $status[$ip].State = "trying"
            }
        }
        $jobs = $jobs | Where-Object { $_.State -ne 'Completed' }
        $runningJobs = $jobs | Where-Object { $_.State -eq 'Running' }
    }
    
    # Clean up completed jobs
    $jobs | ForEach-Object { Remove-Job $_ -Force }
    
    # Final display after all pings complete
    # Calculate column widths
    $hostnameWidth = [Math]::Max(10, ($status.Values.Hostname | Measure-Object -Maximum -Property Length).Maximum + 2)
    $ipWidth = [Math]::Max(15, ($status.Keys | Measure-Object -Maximum -Property Length).Maximum + 2)
    $statusWidth = 15
    $avgWidth = 10
    $tableWidth = $hostnameWidth + $ipWidth + $statusWidth + $avgWidth
    
    $title = "Cycle $cycle - Final Ping Status at $(Get-Date -Format 'HH:mm:ss')"
    $completeText = "All tests complete!"
    $maxTextWidth = [Math]::Max($title.Length, $completeText.Length)
    $totalWidth = [Math]::Max($tableWidth, $maxTextWidth)
    
    [Console]::Clear()
    Write-Host ("═" * $totalWidth) -ForegroundColor Cyan
    Write-Host $title -ForegroundColor Cyan
    Write-Host $completeText -ForegroundColor Green
    Write-Host ("═" * $totalWidth) -ForegroundColor Cyan
    Write-Host ("{0,-$hostnameWidth}{1,-$ipWidth}{2,-$statusWidth}{3,-$avgWidth}" -f "Hostname", "IP Address", "Status", "Avg Time") -ForegroundColor White
    Write-Host ("-" * $tableWidth) -ForegroundColor White
    foreach ($ip in $status.Keys | Sort-Object) {
        $finalStat = $status[$ip].State
        $hostname = $status[$ip].Hostname
        $avgTime = $status[$ip].AvgMs
        $color = if ($finalStat -eq "connected") { "Green" } elseif ($finalStat -eq "not reachable") { "Red" } else { "White" }
        Write-Host ("{0,-$hostnameWidth}{1,-$ipWidth}{2,-$statusWidth}{3,-$avgWidth}" -f $hostname, $ip, $finalStat, $avgTime) -ForegroundColor $color
    }
    Write-Host ("═" * $totalWidth) -ForegroundColor Cyan
    
    Write-Host "`nCycle $cycle completed. Next update in $IntervalSeconds seconds..." -ForegroundColor Yellow
    Write-Host "Press 'Q' to exit or any other key to continue" -ForegroundColor Yellow

    # Update per-host history
    foreach ($ip in $status.Keys) {
        $currentState = $status[$ip].State
        $hostHistory[$ip].History.Enqueue([PSCustomObject]@{
            Timestamp = Get-Date
            State = $currentState
            AvgMs = $status[$ip].AvgMs
            Errors = $status[$ip].Errors
        })
        # Keep only last 10 cycles
        while ($hostHistory[$ip].History.Count -gt 10) {
            $hostHistory[$ip].History.Dequeue() | Out-Null
        }
        # Update consecutive failures
        if ($currentState -eq "not reachable" -or $currentState -eq "error") {
            $hostHistory[$ip].ConsecutiveFailures++
        } else {
            $hostHistory[$ip].ConsecutiveFailures = 0
        }
        $hostHistory[$ip].LastState = $currentState
    }

    # Save cycle results to file (append)
    $logFile = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) $OutputLogFile
    $cycleTime = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $hostnameWidth = 20
    $ipWidth = 18
    $statusWidth = 13
    $avgWidth = 10

    Add-Content -Path $logFile -Value "=========================== Cycle $cycle - $cycleTime ==========================="
    Add-Content -Path $logFile -Value ("{0,-$hostnameWidth}{1,-$ipWidth}{2,-$statusWidth}{3,-$avgWidth}" -f 'Hostname', 'IP Address', 'Status', 'Avg Time')

    foreach ($ip in $status.Keys | Sort-Object) {
        $finalStat = $status[$ip].State
        $hostname = $status[$ip].Hostname
        $avgTime = $status[$ip].AvgMs
        Add-Content -Path $logFile -Value ("{0,-$hostnameWidth}{1,-$ipWidth}{2,-$statusWidth}{3,-$avgWidth}" -f $hostname, $ip, $finalStat, $avgTime)
    }
    Add-Content -Path $logFile -Value ""

    # Wait for user input or timeout after interval seconds
    $elapsed = 0
    while ($elapsed -lt ($IntervalSeconds * 1000)) {
        if ([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true)
            if ($key.KeyChar -eq 'q' -or $key.KeyChar -eq 'Q') {
                Write-Host "`nExiting program..." -ForegroundColor Yellow
                exit 0
            } else {
                break  # Continue to next cycle
            }
        }
        Start-Sleep -Milliseconds 100
        $elapsed += 100
    }
    
    $cycle++
    
    # Check for RunOnce or NoLoop
    if ($RunOnce -or $NoLoop) {
        break
    }
}