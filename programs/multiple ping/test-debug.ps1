$CsvFile = "c:\My Data\My Projects\Coding\programs\multiple ping\ips.csv"
Write-Host "Starting test..." -Fore Green

$hosts = Import-Csv -LiteralPath $CsvFile
Write-Host "Loaded $($hosts.Count) hosts" -Fore Green
$hosts | Select-Object Hostname, IP | Format-Table

$hostList = @()
foreach ($h in $hosts) {
    $ip = ($h.IP -as [string]).Trim()
    $hostname = ($h.Hostname -as [string]).Trim()
    Write-Host "Processing: $hostname -> $ip"
    if ($ip -and $hostname) {
        $hostList += @{ Hostname = $hostname; IP = $ip; Status = 'DOWN'; Latency = '-' }
    }
}

Write-Host "Host list count: $($hostList.Count)" -Fore Green
$hostList | ForEach-Object { Write-Host "  $($_.Hostname) ($($_.IP))" }

Write-Host "Testing cursor position..." -Fore Yellow
$topLine = [Console]::CursorTop
Write-Host "TopLine: $topLine"

Write-Host "Allocating screen..." -Fore Yellow
1..5 | ForEach-Object { Write-Host '' }

Write-Host "Attempting to set cursor and write..." -Fore Yellow
try {
    [Console]::SetCursorPosition(0, $topLine)
    Write-Host "TEST LINE 1" -NoNewline -Fore Cyan
    Write-Host ""
} catch {
    Write-Host "ERROR: $_" -Fore Red
}

Write-Host "Done!" -Fore Green
