param(
    [string]$CsvFile = "ips.csv",
    [int]$IntervalSeconds = 2,
    [int]$TimeoutMs = 1000,
    [string]$ReportFile = "report.txt"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "SilentlyContinue"

# -----------------------------
# FILE CHECKS
# -----------------------------
if (!(Test-Path $CsvFile)) {
    Write-Host "CSV not found: $CsvFile" -ForegroundColor Red
    exit
}

if (!(Test-Path $ReportFile)) {
    New-Item -ItemType File -Path $ReportFile -Force | Out-Null
}

Add-Content $ReportFile "=== Ping Monitor Started: $(Get-Date) ==="

# -----------------------------
# LOAD HOSTS
# -----------------------------
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

# -----------------------------
# RUNSPACE POOL
# -----------------------------
$pool = [runspacefactory]::CreateRunspacePool(1, 30)
$pool.Open()

# -----------------------------
# COLUMN WIDTH CALCULATOR
# -----------------------------
function Get-ColumnWidths {
    param($hosts)

    $maxHost = ($hosts.Hostname | Measure-Object -Property Length -Maximum).Maximum
    $maxIP   = ($hosts.IP       | Measure-Object -Property Length -Maximum).Maximum

    if (-not $maxHost) { $maxHost = 12 }
    if (-not $maxIP)   { $maxIP = 15 }

    if ($maxHost -lt 12) { $maxHost = 12 }
    if ($maxIP -lt 15)   { $maxIP = 15 }

    return @{
        Host = $maxHost + 2
        IP   = $maxIP + 2
        Stat = 8
        Lat  = 10
    }
}

# -----------------------------
# LOGGING (STRUCTURED)
# -----------------------------
function Write-Log {
    param(
        [string]$host,
        [string]$ip,
        [string]$event,
        [string]$extra
    )

    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    $line = "{0} | {1,-12} | {2,-15} | {3,-6} | {4}" -f `
        $time, $host, $ip, $event, $extra

    Add-Content -Path $ReportFile -Value $line
}

# -----------------------------
# PING FUNCTION (ASYNC)
# -----------------------------
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

    return @{
        Pipe   = $ps
        Handle = $ps.BeginInvoke()
    }
}

# -----------------------------
# DASHBOARD RENDER
# -----------------------------
function Draw-Dashboard {
    param($hosts)

    Clear-Host

    $time = Get-Date -Format "HH:mm:ss"
    $w = Get-ColumnWidths $hosts

    $header = "{0,-$($w.Host)} {1,-$($w.IP)} {2,-$($w.Stat)} {3,-$($w.Lat)}" -f `
        "Hostname", "IP", "Status", "Latency"

    Write-Host "=== NOC PING MONITOR === $time ===" -ForegroundColor Cyan
    Write-Host $header -ForegroundColor Yellow
    Write-Host ("-" * $header.Length)

    foreach ($h in $hosts) {

        switch ($h.Status) {
            "UP"   { $color = "White" }
            "DOWN" { $color = "Red" }
            default { $color = "DarkGray" }
        }

        $line = "{0,-$($w.Host)} {1,-$($w.IP)} {2,-$($w.Stat)} {3,-$($w.Lat)}" -f `
            $h.Hostname, $h.IP, $h.Status, $h.Latency

        Write-Host $line -ForegroundColor $color
    }
}

# -----------------------------
# MAIN LOOP
# -----------------------------
while ($true) {

    $tasks = @()

    for ($i = 0; $i -lt $hostList.Count; $i++) {
        $tasks += Start-Ping $hostList[$i] $i
    }

    foreach ($t in $tasks) {

        $res = $t.Pipe.EndInvoke($t.Handle)
        $t.Pipe.Dispose()

        if (-not $res) { continue }

        $h = $hostList[$res.Idx]
        $newStatus = $res.Status
        $now = Get-Date

        # -----------------------------
		# STATUS HANDLING (FIXED)
		# -----------------------------
		$now = Get-Date

		if ($h.LastStatus -ne $newStatus) {

			# DOWN EVENT
			if ($newStatus -eq "DOWN") {
				$h.DownSince = $now
				Write-Log $h.Hostname $h.IP "DOWN" ""
			}

			# UP EVENT
			elseif ($newStatus -eq "UP" -and $h.LastStatus -eq "DOWN") {

				if ($h.DownSince) {
					$duration = New-TimeSpan -Start $h.DownSince -End $now
					$durationSec = [math]::Round($duration.TotalSeconds, 1)

					Write-Log $h.Hostname $h.IP "UP" "$durationSec s"
					$h.DownSince = $null
				}
			}
		}

		# ONLY AFTER LOGIC
		$h.Status = $newStatus
		$h.Latency = if ($res.Lat -gt 0) { "$($res.Lat) ms" } else { "-" }
		$h.LastStatus = $newStatus
    }

    Draw-Dashboard $hostList

    Start-Sleep -Seconds $IntervalSeconds
}

# Cleanup (unreachable unless loop breaks)
$pool.Close()
$pool.Dispose()