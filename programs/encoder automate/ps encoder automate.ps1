param(
    [Parameter(Mandatory=$true)]
    [string]$EncoderIP
)

# ================================
# Nextiva S1708e Encoder Extractor
# ================================

$port = 23
$outputCsv = "C:\Temp\S1708_Encoder1.csv"

# CSV header
"Input,Bitrate,FrameRate,QuantMin,QuantMax,Streaming,Transport,RemoteIP,UDPPort,Resolution,RateControl,Compression,IntraInterval" |
    Out-File $outputCsv

# Telnet client
$client = New-Object System.Net.Sockets.TcpClient
$client.Connect($EncoderIP, $port)

$stream = $client.GetStream()
$writer = New-Object System.IO.StreamWriter($stream)
$reader = New-Object System.IO.StreamReader($stream)
$writer.AutoFlush = $true

function Send-Key {
    param($key)
    Start-Sleep -Milliseconds 350
    $writer.WriteLine($key)
}

function Read-Block {
    Start-Sleep -Milliseconds 500
    return $reader.ReadToEnd()
}

# -------------------------------
# Verify we are at MAIN MENU
# -------------------------------
$initial = Read-Block

if ($initial -notmatch "Main Menu") {
    Write-Host "ERROR: Not at Main Menu. Telnet session did not start correctly."
    $client.Close()
    exit
}

# -------------------------------
# Enter option 6 twice
# -------------------------------
Send-Key "6"
Send-Key "6"

# Now inside: Advanced → Video
# -------------------------------

foreach ($input in 1..8) {

    # Enter Input X
    Send-Key $input

    # Enter Encoder 1
    Send-Key "1"

    # Capture encoder screen
    $raw = Read-Block

    # -------------------------------
    # Parse fields using regex
    # -------------------------------
    $bitrate       = ($raw -match "Target Bitrate.*?(\d+)" | Out-Null; $Matches[1])
    $framerate     = ($raw -match "Frame Rate.*?(\d+)" | Out-Null; $Matches[1])
    $qmin          = ($raw -match "Quantizer Min.*?(\d+)" | Out-Null; $Matches[1])
    $qmax          = ($raw -match "Quantizer Max.*?(\d+)" | Out-Null; $Matches[1])
    $streaming     = ($raw -match "Streaming.*?(Enabled|Disabled)" | Out-Null; $Matches[1])
    $transport     = ($raw -match "Transport.*?(UDP|RTP|TCP)" | Out-Null; $Matches[1])
    $remoteIP      = ($raw -match "Remote IP.*?(\d+\.\d+\.\d+\.\d+)" | Out-Null; $Matches[1])
    $udpPort       = ($raw -match "UDP Port.*?(\d+)" | Out-Null; $Matches[1])
    $resolution    = ($raw -match "Resolution.*?(\d+x\d+)" | Out-Null; $Matches[1])
    $rateControl   = ($raw -match "Rate Control.*?(CBR|VBR)" | Out-Null; $Matches[1])
    $compression   = ($raw -match "Compression.*?(MPEG4|H264)" | Out-Null; $Matches[1])
    $intra         = ($raw -match "Intra Interval.*?(\d+)" | Out-Null; $Matches[1])

    # -------------------------------
    # Write row to CSV
    # -------------------------------
    "$input,$bitrate,$framerate,$qmin,$qmax,$streaming,$transport,$remoteIP,$udpPort,$resolution,$rateControl,$compression,$intra" |
        Out-File $outputCsv -Append

    # Back out to Video menu
    Send-Key "p"
    Send-Key "p"
}

# Exit cleanly
Send-Key "p"
$client.Close()

Write-Host "Completed. CSV saved to $outputCsv"
