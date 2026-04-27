param(
    [string]$CsvFile = "ips.csv",
    [int]$IntervalSeconds = 2,
    [int]$TimeoutMs = 1000
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "SilentlyContinue"

# Validate CSV
if (!(Test-Path $CsvFile)) {
    Write-Host "CSV not found: $CsvFile" -ForegroundColor Red
    exit
}

$hosts = Import-Csv $CsvFile

# Normalize
$hostList = @()
foreach ($h in $hosts) {
    if ($h.IP -and $h.Hostname) {
        $hostList += [PSCustomObject]@{
            Hostname        = $h.Hostname.Trim()
            IP              = $h.IP.Trim()
            Status          = "DOWN"
            LastStatus      = "DOWN"
            Latency         = "-"
            DownStartTime   = $null
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
    try {
        Add-Content -Path $reportFile -Value $text
    } catch {}
}

# UI Setup
Clear-Host
[Console]::CursorVisible = $false

# Draw header
function Draw-Header {
    [Console]::SetCursorPosition(0,0)

    $title = "MULTI-HOST PING MONITOR ({0}) - Q to quit" -f (Get-Date -Format HH:mm:ss)
    Write-Host $title.PadRight(90) -ForegroundColor Cyan

    Write-Host ""

    $sep = "+" + ("-"*22) + "+" + ("-"*17) + "+" + ("-"*10) + "+" + ("-"*12) + "+"
    Write-Host $sep -ForegroundColor DarkGray
    Write-Host ("| {0,-20} | {1,-15} | {2,-8} | {3,-10} |" -f "Hostname","IP","Status","Latency") -ForegroundColor White
    Write-Host $sep -ForegroundColor DarkGray

    for ($i=0; $i -lt $hostList.Count; $i++) {
        Write-Host ("| {0,-20} | {1,-15} | {2,-8} | {3,-10} |" -f "","","","")
    }

    Write-Host $sep -ForegroundColor DarkGray
}

Draw-Header

# Runspace pool
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

while ($true) {

    $tasks = @()

    # Start pings
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

            # UP event (calculate duration)
            if ($h.LastStatus -eq "DOWN" -and $newStatus -eq "UP") {
                if ($h.DownStartTime) {
                    $duration = New-TimeSpan -Start $h.DownStartTime -End (Get-Date)
                    $secs = [math]::Round($duration.TotalSeconds,1)

                    Write-Log ("{0} UP   {1} ({2}) Duration: {3}s" -f (Get-Date), $h.Hostname, $h.IP, $secs)
                } else {
                    Write-Log ("{0} UP   {1} ({2})" -f (Get-Date), $h.Hostname, $h.IP)
                }

                $h.DownStartTime = $null
            }

            $h.Status = $newStatus
            $h.Latency = $res.Lat
            $h.LastStatus = $newStatus
        }
    }

    # Update header time (FULL overwrite safe)
    [Console]::SetCursorPosition(0,0)

    $width = 120

    $title = "MULTI-HOST PING MONITOR ({0}) - Q to quit" -f (Get-Date -Format HH:mm:ss)

    Write-Host ($title.PadRight($width)) -ForegroundColor Cyan

    Write-Host ("".PadRight($width))

    $sep = "+" + ("-"*22) + "+" + ("-"*17) + "+" + ("-"*10) + "+" + ("-"*12) + "+"
    Write-Host ($sep.PadRight($width)) -ForegroundColor DarkGray
    Write-Host ("| {0,-20} | {1,-15} | {2,-8} | {3,-10} |" -f "Hostname","IP","Status","Latency").PadRight($width) -ForegroundColor White
    Write-Host ($sep.PadRight($width)) -ForegroundColor DarkGray

    # Update rows
    for ($i=0; $i -lt $hostList.Count; $i++) {
        $h = $hostList[$i]
        $HeaderHeight = 5
        [Console]::SetCursorPosition(0, $HeaderHeight + $i)

        $line = "| {0,-20} | {1,-15} | {2,-8} | {3,-10} |" -f `
            $h.Hostname, $h.IP, $h.Status, $h.Latency

        $line = $line.PadRight(90)

        if ($h.Status -eq "UP") {
            # White text only
            Write-Host $line -ForegroundColor White -NoNewline
        }
        else {
            # Bright red text only
            Write-Host $line -ForegroundColor Red -NoNewline
        }
    }

    # Exit key
    if ([Console]::KeyAvailable) {
        if ([Console]::ReadKey($true).Key -eq "Q") { break }
    }

    Start-Sleep -Seconds $IntervalSeconds
}

# Cleanup
$pool.Close()
$pool.Dispose()
[Console]::CursorVisible = $true

Write-Host "`nStopped." -ForegroundColor Yellow