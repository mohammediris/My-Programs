param(
    [string]$CsvFile = "ips.csv",
    [int]$IntervalSeconds = 2,
    [int]$TimeoutMs = 1000,
    [string]$ReportFile = "report.txt"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "SilentlyContinue"

# Ensure input exists
if (!(Test-Path $CsvFile)) {
    Write-Host "CSV not found: $CsvFile" -ForegroundColor Red
    exit
}

# Ensure report file exists (always at start)
if (!(Test-Path $ReportFile)) {
    New-Item -ItemType File -Path $ReportFile -Force | Out-Null
}
Add-Content $ReportFile "=== Ping Monitor Started: $(Get-Date) ==="

# Load hosts
$hostsRaw = Import-Csv $CsvFile

$hostList = @()
foreach ($h in $hostsRaw) {
    if ($h.IP -and $h.Hostname) {
        $hostList += [PSCustomObject]@{
            Hostname   = $h.Hostname.Trim()
            IP         = $h.IP.Trim()
            Status     = "UNKNOWN"
            LastStatus = "UNKNOWN"
            Latency    = "-"
            DownSince  = $null
        }
    }
}

if ($hostList.Count -eq 0) {
    Write-Host "No valid hosts found" -ForegroundColor Red
    exit
}

# Runspace pool
$pool = [runspacefactory]::CreateRunspacePool(1, 30)
$pool.Open()

function Write-Log {
    param($text)
    Add-Content -Path $ReportFile -Value $text
}

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
                return @{Idx=$idx; Status="UP"; Lat=$r.RoundtripTime}
            }
        } catch {}

        return @{Idx=$idx; Status="DOWN"; Lat=-1}
    }).AddArgument($target.IP).AddArgument($index).AddArgument($TimeoutMs)

    return @{ Pipe=$ps; Handle=$ps.BeginInvoke() }
}

function Draw-Dashboard {
    param($hosts)

    Clear-Host

    $time = Get-Date -Format "HH:mm:ss"
    Write-Host "=== NOC PING MONITOR === $time ===" -ForegroundColor Cyan
    Write-Host "Hostname            IP               Status   Latency"
    Write-Host ("-" * 60)

    foreach ($h in $hosts) {
        # Color rules:
        # UP   = White
        # DOWN = Bright Red

        if ($h.Status -eq "UP") {
            $color = "White"
        }
        elseif ($h.Status -eq "DOWN") {
            $color = "Red"  # PowerShell default bright red in console
        }
        else {
            $color = "DarkGray"
        }

        Write-Host ("{0,-18} {1,-15} {2,-8} {3,-8}" -f `
            $h.Hostname, $h.IP, $h.Status, $h.Latency
        ) -ForegroundColor $color
    }
}

# MAIN LOOP
while ($true) {

    $tasks = @()

    for ($i=0; $i -lt $hostList.Count; $i++) {
        $tasks += Start-Ping $hostList[$i] $i
    }

    foreach ($t in $tasks) {
        $res = $t.Pipe.EndInvoke($t.Handle)
        $t.Pipe.Dispose()

        if (-not $res) { continue }

        $h = $hostList[$res.Idx]
        $newStatus = $res.Status
        $now = Get-Date

        if ($h.LastStatus -ne $newStatus) {

            if ($newStatus -eq "DOWN") {
                $h.DownSince = $now
                Write-Log "[$now] DOWN: $($h.Hostname) ($($h.IP))"
            }

            if ($newStatus -eq "UP" -and $h.DownSince) {
                $duration = New-TimeSpan -Start $h.DownSince -End $now
                Write-Log "[$now] UP: $($h.Hostname) ($($h.IP)) DOWN_DURATION: $([math]::Round($duration.TotalSeconds,1))s"
                $h.DownSince = $null
            }
        }

        $h.Status = $newStatus
        $h.Latency = if ($res.Lat -gt 0) { "$($res.Lat) ms" } else { "-" }
        $h.LastStatus = $newStatus
    }

    Draw-Dashboard $hostList

    Start-Sleep -Seconds $IntervalSeconds
}

$pool.Close()
$pool.Dispose()
