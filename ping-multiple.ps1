param(
    [string]$CsvFile = "ips.csv"
)

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

# Infinite loop to continuously ping all IPs
while ($true) {
    # Initialize status hashtable
    $status = @{}
    $jobs = @()
    
    # Start ping jobs for all IPs
    foreach ($ipObj in $ips) {
        $ip = $ipObj.IP
        $hostname = if ($ipObj.Hostname) { $ipObj.Hostname } else { $ip }
        $status[$ip] = @{
            Status = "pinging"
            Hostname = $hostname
        }
        
        $job = Start-Job -ScriptBlock {
            param($ip)
            $result = Test-Connection -ComputerName $ip -Count 5 -Quiet
            if ($result) { "connected" } else { "not reachable" }
        } -ArgumentList $ip
        
        $job | Add-Member -NotePropertyName IP -NotePropertyValue $ip -Force
        $jobs += $job
    }
    
    # Monitor jobs and update display in realtime
    $runningJobs = $jobs | Where-Object { $_.State -eq 'Running' }
    while ($runningJobs.Count -gt 0) {
        $remaining = ($status.Values | Where-Object { $_.Status -eq "pinging" }).Count
        
        [Console]::Clear()
        Write-Host "Cycle $cycle - Ping Status at $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Cyan
        Write-Host "Remaining hosts: $remaining out of $totalHosts" -ForegroundColor Magenta
        Write-Host "Hostname`t`tIP Address`t`t`tStatus" -ForegroundColor White
        Write-Host "--------`t`t----------`t`t`t------" -ForegroundColor White
        
        foreach ($ip in $status.Keys | Sort-Object) {
            $stat = $status[$ip].Status
            $hostname = $status[$ip].Hostname
            $color = if ($stat -eq "pinging") { "Yellow" } elseif ($stat -eq "connected") { "Green" } elseif ($stat -eq "not reachable") { "Red" } else { "White" }
            Write-Host "$hostname`t`t$ip`t`t`t$stat" -ForegroundColor $color
        }
        
        Start-Sleep -Seconds 1
        
        # Update status for completed jobs
        $completedJobs = $jobs | Where-Object { $_.State -eq 'Completed' }
        foreach ($job in $completedJobs) {
            $ip = $job.IP
            $result = Receive-Job $job
            $status[$ip].Status = $result
            Remove-Job $job
        }
        $jobs = $jobs | Where-Object { $_.State -ne 'Completed' }
        $runningJobs = $jobs | Where-Object { $_.State -eq 'Running' }
    }
    
    # Final display after all pings complete
    [Console]::Clear()
    Write-Host "Cycle $cycle - Final Ping Status at $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Cyan
    Write-Host "All tests complete!" -ForegroundColor Green
    Write-Host "Hostname`t`tIP Address`t`t`tStatus" -ForegroundColor White
    Write-Host "--------`t`t----------`t`t`t------" -ForegroundColor White
    foreach ($ip in $status.Keys | Sort-Object) {
        $stat = $status[$ip].Status
        $hostname = $status[$ip].Hostname
        $color = if ($stat -eq "connected") { "Green" } elseif ($stat -eq "not reachable") { "Red" } else { "White" }
        Write-Host "$hostname`t`t$ip`t`t`t$stat" -ForegroundColor $color
    }
    
    Write-Host "`nCycle $cycle completed. Next update in 5 seconds..." -ForegroundColor Yellow
    Write-Host "Press Ctrl+C to exit the program" -ForegroundColor Gray
    Start-Sleep -Seconds 5  # Wait 5 seconds before next cycle
    $cycle++