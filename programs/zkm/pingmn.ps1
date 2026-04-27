param(
    [string]$CsvFile = "ips.csv",
    [int]$IntervalSeconds = 2,
    [int]$TimeoutMs = 1000
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "SilentlyContinue"

if (!(Test-Path $CsvFile)) {
    Write-Host "CSV not found: $CsvFile" -ForegroundColor Red
    exit
}

# Load hosts
$hosts = Import-Csv $CsvFile

$hostList = @()
foreach ($h in $hosts) {
    if ($h.IP -and $h.Hostname) {
        $hostList += [PSCustomObject]@{
            Hostname      = $h.Hostname.Trim()
            IP            = $h.IP.Trim()
            Status        = "DOWN"
            LastStatus    = "DOWN"
            Latency       = "-"
            DownStartTime = $null
        }
    }
}

if ($hostList.Count -eq 0) {
    Write-Host "No valid hosts found" -ForegroundColor Red
    exit
}

# Report file
$reportFile = Join-Path (Split-Path $CsvFile) "report.txt"

function Write-Log {
    param($text)
    try { Add-Content -Path $reportFile -Value $text } catch {}
}

# Console setup
[Console]::CursorVisible = $false
Clear-Host

# Runspace pool (fast parallel ping)
$pool = [runspacefactory]::CreateRunspacePool(1, 25)
$pool.Open()

function Start-Ping {
    param($target, $index)

    $ps = [powershell]::Create()
    $ps.RunspacePool = $pool

    $ps.AddScript({
        param($ip, $idx, $timeout)

        try {
            $p = New-Object System.Net.NetworkInformation.Ping
            $r = $p.Send($ip, $timeout)

            if ($r.Status -eq "Success") {
                return @{Idx=$idx; Status="UP"; Lat="$($r.RoundtripTime) ms"}
            }
        } catch {}

        return @{Idx=$idx; Status="DOWN"; Lat="-"}
    }).AddArgument($target.IP).AddArgument($index).AddArgument($TimeoutMs)

    return @{
        Pipe   = $ps
        Handle = $ps.BeginInvoke()
    }
}

function Draw-Dashboard {
    param($hosts)

    $width = [Console]::WindowWidth
    $height = [Console]::WindowHeight

    if ($width -lt 60 -or $height -lt 10) {
        Clear-Host
        Write-Host "Window too small..." -ForegroundColor Red
        return
    }

    $time = Get-Date -Format "HH:mm:ss"
    $title = " MULTI-HOST PING MONITOR  [$time]  (Q to quit) "

    # Clamp rows
    $maxRows = $height - 6
    if ($maxRows -lt 1) { return }

    Clear-Host

    # Header
    Write-Host ($title.PadRight($width)) -ForegroundColor Cyan
    Write-Host ("".PadRight($width))

    $sep = "+" + ("-"*22) + "+" + ("-"*17) + "+" + ("-"*10) + "+" + ("-"*12) + "+"
    Write-Host $sep -ForegroundColor DarkGray

    $headerLine = "| {0,-20} | {1,-15} | {2,-8} | {3,-10} |" -f "Hostname","IP","Status","Latency"
    Write-Host ($headerLine.PadRight($width)) -ForegroundColor White

    Write-Host $sep -ForegroundColor DarkGray

    # Rows
    for ($i=0; $i -lt $maxRows -and $i -lt $hosts.Count; $i++) {

        $h = $hosts[$i]

        $line = "| {0,-20} | {1,-15} | {2,-8} | {3,-10} |" -f `
            $h.Hostname, $h.IP, $h.Status, $h.Latency

        $line = $line.PadRight($width)

        if ($h.Status -eq "UP") {
            Write-Host $line -ForegroundColor White
        }
        else {
            Write-Host $line -ForegroundColor Red
        }
    }

    # Fill remaining space (prevents ghost artifacts)
    for ($i=$hosts.Count; $i -lt $maxRows; $i++) {
        Write-Host ("".PadRight($width))
    }
}

# Main loop
while ($true) {

    # Start all pings
    $tasks = @()

    for ($i=0; $i -lt $hostList.Count; $i++) {
        $tasks += Start-Ping -target $hostList[$i] -index $i
    }

    # Collect results
    foreach ($t in $tasks) {
        $res = $t.Pipe.EndInvoke($t.Handle)
        $t.Pipe.Dispose()

        if ($res) {
            $idx = $res.Idx
            $h = $hostList[$idx]

            $newStatus = $res.Status

            # DOWN event
            if ($h.LastStatus -eq "UP" -and $newStatus -eq "DOWN") {
                $h.DownStartTime = Get-Date
                Write-Log ("{0} DOWN {1} ({2})" -f (Get-Date), $h.Hostname, $h.IP)
            }

            # UP event
            if ($h.LastStatus -eq "DOWN" -and $newStatus -eq "UP") {
                if ($h.DownStartTime) {
                    $duration = New-TimeSpan -Start $h.DownStartTime -End (Get-Date)
                    $secs = [math]::Round($duration.TotalSeconds,1)

                    Write-Log ("{0} UP {1} ({2}) Duration: {3}s" -f (Get-Date), $h.Hostname, $h.IP, $secs)
                } else {
                    Write-Log ("{0} UP {1} ({2})" -f (Get-Date), $h.Hostname, $h.IP)
                }

                $h.DownStartTime = $null
            }

            $h.Status = $newStatus
            $h.Latency = $res.Lat
            $h.LastStatus = $newStatus
        }
    }

    # Input handling
    if ([Console]::KeyAvailable) {
        if ([Console]::ReadKey($true).Key -eq "Q") { break }
    }

    # Render full dashboard safely
    Draw-Dashboard -hosts $hostList

    Start-Sleep -Seconds $IntervalSeconds
}

# Cleanup
$pool.Close()
$pool.Dispose()
[Console]::CursorVisible = $true

Write-Host "`nStopped." -ForegroundColor Yellow