<#
================================================================================
    Domain Controller Health & Replication Check Script
    BASIC VERSION — WITH COMMENTS, USAGE, AND SAMPLE OUTPUTS
================================================================================

.DESCRIPTION
    This script checks the health of two Domain Controllers using:
        - DCDiag
        - RepAdmin
        - DNS tests
        - SYSVOL availability
        - Critical AD services
        - Replication metadata

.PARAMETER DC1
    The hostname or IP address of the first Domain Controller.

.PARAMETER DC2
    The hostname or IP address of the second Domain Controller.

.EXAMPLE
    How to run the script:

        .\Check-DCHealth.ps1 -DC1 DC01 -DC2 DC02

    Or using IP addresses:

        .\Check-DCHealth.ps1 -DC1 192.168.1.10 -DC2 192.168.1.11

================================================================================
SAMPLE OUTPUT — HEALTHY DC
================================================================================

Checking DC01 ...

DomainController     : DC01
Reachable            : True
LastReplication      : 4/25/2026 12:31:44 AM
ReplicationFailures  : 0
ReplicationErrors    : No replication errors
DCDiagErrors         : No errors detected
SYSVOL_OK            : True
CriticalServices     :
                      Name     Status
                      ----     ------
                      NTDS     Running
                      DNS      Running
                      DFSR     Running
                      Netlogon Running
                      KDC      Running
DNSHealth            : DNS OK
FSMO_Roles           : SchemaMaster, DomainNamingMaster, PDCEmulator,
                       RIDMaster, InfrastructureMaster

================================================================================
SAMPLE OUTPUT — ERROR DC
================================================================================

Checking DC02 ...

DomainController     : DC02
Reachable            : True
LastReplication      : 4/24/2026 03:12:09 PM
ReplicationFailures  : 3
ReplicationErrors    :
                      2148074274 (0x80090012) The specified domain either does
                      not exist or could not be contacted.
                      Last error: 8606 (0x219e):
                      Insufficient attributes were given to create an object.

DCDiagErrors         :
                      Starting test: Advertising
                         Warning: DC02 is not advertising as a GC.
                      Starting test: Services
                         The DFS Replication service is not running.
                      Starting test: SysVolCheck
                         Error: SYSVOL is not ready.

SYSVOL_OK            : False

CriticalServices     :
                      Name     Status
                      ----     ------
                      NTDS     Running
                      DNS      Stopped
                      DFSR     Stopped
                      Netlogon Running
                      KDC      Running

DNSHealth            :
                      DNS tests failed:
                      Missing SRV records: _ldap._tcp.dc._msdcs.contoso.local

================================================================================
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$DC1,

    [Parameter(Mandatory = $true)]
    [string]$DC2
)

Import-Module ActiveDirectory -ErrorAction SilentlyContinue

$DCList = @($DC1, $DC2)
$Report = [System.Collections.Generic.List[Object]]::new()

foreach ($DC in $DCList) {

    Write-Host "`nChecking $DC ..." -ForegroundColor Cyan

    # Reachability
    $ping = Test-Connection -ComputerName $DC -Count 1 -Quiet

    # DCDiag
    $dcdiag = dcdiag /s:$DC /q
    $dcdiagErrors = if ($dcdiag) { $dcdiag } else { "No errors detected" }

    # Replication
    $repl = repadmin /showrepl $DC /errorsonly
    $replErrors = if ($repl) { $repl } else { "No replication errors" }

    # Replication metadata
    $partners = Get-ADReplicationPartnerMetadata -Target $DC -ErrorAction SilentlyContinue
    $lastRepl = $partners.LastReplicationSuccess | Sort-Object | Select-Object -Last 1

    # Replication failures
    $failures = Get-ADReplicationFailure -Target $DC -ErrorAction SilentlyContinue

    # SYSVOL
    $sysvol = Invoke-Command -ComputerName $DC -ScriptBlock {
        Test-Path "C:\Windows\SYSVOL\sysvol"
    }

    # Critical services
    $criticalServices = "NTDS","DNS","DFSR","Netlogon","KDC"
    $svcStatus = foreach ($svc in $criticalServices) {
        Get-Service -ComputerName $DC -Name $svc | Select Name, Status
    }

    # DNS test
    $dnsTest = dcdiag /test:dns /s:$DC /q

    # FSMO roles
    $fsmo = (Get-ADForest).FSMORoles + (Get-ADDomain).FSMORoles

    # Build report
    $Report.Add([PSCustomObject]@{
        DomainController     = $DC
        Reachable            = $ping
        LastReplication      = $lastRepl
        ReplicationFailures  = $failures.Count
        ReplicationErrors    = $replErrors
        DCDiagErrors         = $dcdiagErrors
        SYSVOL_OK            = $sysvol
        CriticalServices     = $svcStatus
        DNSHealth            = if ($dnsTest) { $dnsTest } else { "DNS OK" }
        FSMO_Roles           = $fsmo -join ", "
    })
}

$Report | Format-List
