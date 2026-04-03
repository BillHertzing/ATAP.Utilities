<#
.SYNOPSIS
    Creates four Cobian Reflector SQL backup Dummy tasks (with pre-events) by
    directly writing to MainList.lst in the exact format confirmed from utat022.

.DESCRIPTION
    Each task is a Cobian Dummy task (TaskBackupType=3) that fires a pre-event
    which runs Invoke-SqlServerBackup.ps1 via pwsh.exe. Cobian acts as both
    scheduler and executor — no Windows Task Scheduler involvement.

    Architecture:
      01:50  Cobian Dummy task fires pre-event:
               pwsh.exe -NonInteractive -File Invoke-SqlServerBackup.ps1
                         -DatabaseName ProGet -BackupType Full -SevenZipCompress
               → .bak.7z → C:\Dropbox\Backups\utat022\ProGet\

      02:20  Cobian Dummy task fires pre-event:
               pwsh.exe -NonInteractive -File Invoke-SqlServerBackup.ps1
                         -DatabaseName BuildMaster -BackupType Full -SevenZipCompress
               → .bak.7z → C:\Dropbox\Backups\utat022\BuildMaster\

.NOTES
    ► Run as Administrator on utat022
    ► Backs up MainList.lst automatically before modifying it
    ► Idempotent — skips tasks that already exist by name

    SCHEDULE NOTE:
    The script uses Daily schedule for all four tasks (format confirmed from
    existing Hydrus Backup task). After running, open the Cobian UI and
    manually change:
      Full tasks        → Weekly, Sunday only
      Differential tasks → Weekly, Monday–Saturday
    The UI will write the correct day-of-week keys automatically.
#>

#Requires -RunAsAdministrator

param(
  [string]$ListPath = 'C:\Program Files\Cobian Reflector\Lists\MainList.lst',
  [string]$ScriptPath = 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-94-sprint-0004-work-items\src\ATAP.Utilities.DatabaseManagement.Powershell\public\Invoke-SqlServerBackup.ps1',
  #  [string]$ScriptPath = 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.DatabaseManagement.Powershell\public\Invoke-SqlServerBackup.ps1',
  [string]$BackupRoot = 'C:\Dropbox\Backups\utat022',
  [string]$PwshExe = 'C:\Program Files\PowerShell\7\pwsh.exe'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Encrypted-empty constants taken verbatim from existing MainList.lst
# (represent unused/blank credentials for required SFTP/FTP/proxy sub-sections)
$E1 = '#Cob2#00028STtl5ohYeTQp2nUFQ5pQT0MGcTs=000010'
$E2 = '#Cob2#0002838kVKKCUZXP8aHrszOuGULKbVrQ=000010'
$E3 = '#Cob2#00028nQojpt8RaLw/IsmOaHreGrieGBk=000010'
$E4 = '#Cob2#00028UJSEfJWl87+n3QYnZ9Oh+BsJb3E=000010'
$E5 = '#Cob2#00028keVJTf7x6LatTLPJ3/iBgCY9RfQ=000010'

function ng { [guid]::NewGuid().ToString().ToLower() }

# ── Section builders (exact format confirmed from MainList.lst on utat022) ────

function Sec-Proxy([string]$g) {
  return @"

<§- $g -§>
§DuplicatedKeys:False
§CaseSensitive:False
§PairSeparator:=
ProxyHost=
ProxyPort=1080
ProxyUserName=
ProxyPassword=$E5
ProxyNullAuthEnabled=False
ProxyPassAuthEnabled=False
ProxyPublicAddress=
ProxyKindFtp=1
<§§- $g -§§>
"@
}

function Sec-Sftp([string]$g, [string]$p) {
  return @"

<§- $g -§>
§DuplicatedKeys:False
§CaseSensitive:False
§PairSeparator:=
SftpProtocol=3
SftpHost=
SftpPort=22
SftpUserName=
SftpPassword=$E1
SftpInitialDirectory=/
SftpAuthenticationType=3
SftpClientPrivateKey=
SftpClientPrivateKeyPassword=$E2
SftpEncoding=65001
SftpModeZ=False
SftpDefaultPermissions=0777
SftpBandWidthLimit=-1
SftpParsingCulture=
SftpKeepAliveIdle=True
SftpKeepAlivePeriodS=30
SftpKeepAliveTransfer=False
SftpParallelTransferMode=True
SftpPreferredCipherAlgorithms=255
SftpPreferredCompressionAlgorithms=3
SftpPreferredHostKeyAlgorithms=127
SftpPreferredKeyExchangeMethods=255
SftpPreferredMACAlgorithms=63
SftpProxy={ *§* $p *§* }
SftpRetryAuthentication=True
SftpRetryCount=3
SftpRetryDelay=5000
SftpSendInitialWindowAdjust=True
SftpCompatibility=0
SftpServerValidation=0
SftpKnownHostFile=
SftpSSHMaxPacketSize=32700
SftpSSHMaxQueuedReadRequests=32
SftpSSHWindowSize=1048575
SftpStrictReturnCodes=False
SftpTCPBufferSize=-1
SftpTimeout=120000
SftpTransferBufferSize=32700
SftpUMask=0022
<§§- $g -§§>
"@
}

function Sec-Ftp([string]$g, [string]$p) {
  return @"

<§- $g -§>
§DuplicatedKeys:False
§CaseSensitive:False
§PairSeparator:=
FtpProtocol=0
FtpHost=
FtpPort=21
FtpUserName=
FtpPassword=$E1
FtpPassive=True
FtpInitialDirectory=/
FtpCommandEncoding=1252
FtpAccount=
FtpMinPort=1024
FtpMaxPort=5000
FtpAutoFeatures=True
FtpAutoFeaturesBug=False
FtpUseBOM=False
FtpAutoFeaturesBeforeLogin=True
FtoAutoPassiveIp=True
FtpAutoSecure=True
FtpCipherSuits=2147483647
FtpClientCert=
FtpClientKeys=
FtpClientKeysPassword=$E2
FtpModeZ=False
FtpForceExt=False
FtpIntegrityCheck=False
FtpKeepAliveI=True
FtpKeelAlivePeriod=30
FtpKeepAliveTransfer=False
FtpMaxSllVersion=2
FtpMinSllVersion=2
FtpBandwidthLimit=-1
FtpParsingCulture=
FtpProxy={ *§* $p *§* }
FtpPublicIp=
FtpRetryCount=3
FtpRetryDelay=5000
FtpServerCommonName=
FtpCompatibility=0
FtpServerValidation=0
FtpServerValidationCertificate=
FtpShowHiddenFiles=False
FtpStrictReturnCodes=False
FtpSynchronizePassiveConnections=False
FtpTCPBufferSize=-1
FtpTimeDifference=0
FtpTimeout=120000
FtpTransferBufferSize=32700
FtpUseClientHelloExtension=True
FtpUseSessionResumption=True
FtpUseUnencryptedCommands=False
FtpUseUnencryptedData=False
<§§- $g -§§>
"@
}

function Sec-Path([string]$g, [string]$path, [string]$sftp, [string]$ftp) {
  # SDKind=1 = local/UNC path (confirmed from existing file)
  return @"

<§- $g -§>
§DuplicatedKeys:False
§CaseSensitive:False
§PairSeparator:=
SDKind=1
SDPath=$path
SDSftp={ *§* $sftp *§* }
SDFtp={ *§* $ftp *§* }
<§§- $g -§§>
"@
}

function Sec-Schedule([string]$g, [string]$dt) {
  # SchSchedule=1 = Daily (confirmed from existing Hydrus Backup task)
  # Change to Weekly via Cobian UI after running this script
  $dateOnly = ($dt -split ' ')[0]
  return @"

<§- $g -§>
§DuplicatedKeys:True
§CaseSensitive:False
§PairSeparator:=
SchSchedule=1
SchDateAndTime=$dt
SchTimer=0
SchTimerLowerLimit=${dateOnly} 00:00:00:
SchTimerUpperLimit=${dateOnly} 23:59:00:
SchUseOrdinaryDaysOfWeek=False
<§§- $g -§§>
"@
}

function Sec-PreEvent([string]$g, [string]$exe, [string]$params) {
  # BEEventType=2 = Execute and wait (confirmed from Cobian UI test task)
  # BEParameter1 = executable path, BEParameter2 = argument string
  return @"

<§- $g -§>
§DuplicatedKeys:False
§CaseSensitive:False
§PairSeparator:=
BEEventType=2
BEArgument=
BEParameter1=$exe
BEParameter2=$params
BEParameter3=
<§§- $g -§§>
"@
}

function Sec-Task([string]$g, [hashtable]$j) {
  $tid = ng
  return @"

<§- $g -§>
§DuplicatedKeys:True
§CaseSensitive:False
§PairSeparator:=
TaskId=$tid
TaskName=$($j.Name)
TaskGroup=$($j.Group)
TaskEnabled=True
TaskIncludeSubdirectories=True
TaskSeparatedBackups=True
TaskUseFileAttributes=True
TaskUseVolumeShadowCopies=False
TaskBackupType=3
TaskDestination={ *§* $($j.DstGuid) *§* }
TaskSchedule={ *§* $($j.SchGuid) *§* }
TaskPriority=2
TaskFullCopiesToKeep=7
TaskDifferentialCopiesToKeep=6
TaskForceFullBackupCount=0
TaskFixedFullBackup=False
TaskFixedFullBackupDay=0
TaskCompression=0
TaskArchiveComment=
TaskEncryptFiles=False
TaskPassPhrase=$E3
TaskPhraseHint=
TaskCompressionLevel=1
CompressionMethod=0
SplitArchive=0
SplitSize=524288000
TaskPreBackupEvents={ *§* $($j.EvtGuid) *§* }
TaskCancelIfPreEventFails=True
TaskDoNotExecutePostEventsIfError=False
TaskMirror=False
TaskUseAbsolutePaths=False
TaskAlwaysCreateTopDirectory=True
TaskClearArchiveAttributes=True
TaskIncludeBackupTypeInName=False
TaskIgnoreEmptyDirectories=True
TaskImpersonate=False
TaskCancelIfImpersonationFails=False
TaskImpersonationUserName=
TaskImpersonationDomain=.
TaskImpersonationPassword=$E4
<§§- $g -§§>
"@
}

# ── Job definitions ───────────────────────────────────────────────────────────

$jobs = @(
  @{ Name = 'SQL - ProGet - Full'; Group = 'SQL Server Backups'; Database = 'ProGet'; BackupType = 'Full'; DateTime = '2026-04-05 01:50:00:000' }
  @{ Name = 'SQL - ProGet - Differential'; Group = 'SQL Server Backups'; Database = 'ProGet'; BackupType = 'Differential'; DateTime = '2026-04-06 01:50:00:000' }
  @{ Name = 'SQL - BuildMaster - Full'; Group = 'SQL Server Backups'; Database = 'BuildMaster'; BackupType = 'Full'; DateTime = '2026-04-05 02:20:00:000' }
  @{ Name = 'SQL - BuildMaster - Differential'; Group = 'SQL Server Backups'; Database = 'BuildMaster'; BackupType = 'Differential'; DateTime = '2026-04-06 02:20:00:000' }
)

# ── Validate ──────────────────────────────────────────────────────────────────
if (-not (Test-Path $ListPath)) { throw "Not found: $ListPath" }
if (-not (Test-Path $ScriptPath)) { throw "Not found: $ScriptPath" }
if (-not (Test-Path $PwshExe)) { Write-Warning "pwsh.exe not found at: $PwshExe — Cobian may fail to launch the pre-event" }

Write-Host "`n===== New-CobianSqlJobs =====" -ForegroundColor Cyan
Write-Host "List file  : $ListPath"
Write-Host "Script path: $ScriptPath"
Write-Host "Backup root: $BackupRoot"
Write-Host "pwsh.exe   : $PwshExe"

# ── Stop Cobian service ───────────────────────────────────────────────────────
$svc = Get-Service -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -like '*Cobian*' -or $_.DisplayName -like '*Cobian*' } |
  Select-Object -First 1

if ($svc) {
  Write-Host "`nStopping: $($svc.Name) ..."
  Stop-Service -Name $svc.Name -Force
  $svc.WaitForStatus('Stopped', '00:00:30')
  Write-Host '  Stopped.' -ForegroundColor Yellow
} else {
  Write-Warning 'Cobian service not found. Ensure the Cobian engine is closed before continuing.'
  $null = Read-Host 'Press ENTER to continue (or Ctrl+C to abort)'
}

# ── Backup existing file ──────────────────────────────────────────────────────
$bak = "$ListPath.bak_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
Copy-Item $ListPath $bak
Write-Host "Backup        : $bak" -ForegroundColor Green

# ── Read file as single string ────────────────────────────────────────────────
$raw = [System.IO.File]::ReadAllText($ListPath, [System.Text.Encoding]::UTF8)

# ── Find root section GUID (always the first section in the file) ─────────────
if ($raw -notmatch '<§- ([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}) -§>') {
  throw "Cannot find root section GUID in $ListPath"
}
$rootGuid = $Matches[1]
Write-Host "Root GUID     : $rootGuid"

# ── Find existing task names (idempotency) ────────────────────────────────────
$existingNames = @(
  [regex]::Matches($raw, '(?m)^TaskName=(.+)$') |
    ForEach-Object { $_.Groups[1].Value.Trim() }
)
Write-Host "Existing tasks: $($existingNames.Count)"
$existingNames | ForEach-Object { Write-Host "  - $_" }

# ── Build new sections ────────────────────────────────────────────────────────
$newRefs = [System.Collections.Generic.List[string]]::new()
$newSections = [System.Text.StringBuilder]::new()

foreach ($job in $jobs) {

  if ($existingNames -contains $job.Name) {
    Write-Warning "Skipping (already exists): $($job.Name)"
    continue
  }

  # Ensure backup destination folder exists
  $destPath = Join-Path $BackupRoot $job.Database
  if (-not (Test-Path $destPath)) {
    New-Item -ItemType Directory -Path $destPath -Force | Out-Null
    Write-Host "  Created folder: $destPath"
  }

  # Generate all 8 GUIDs for this task's sections
  $tg = ng                                                   # task section
  $evtg = ng                                                   # pre-event section
  $dg = ng; $dsg = ng; $dsp = ng; $dfg = ng; $dfp = ng      # dest + sftp/ftp
  $schg = ng                                                   # schedule

  $job['EvtGuid'] = $evtg
  $job['DstGuid'] = $dg
  $job['SchGuid'] = $schg

  # Pre-event argument string passed to pwsh.exe
  $psArgs = "-NonInteractive -File `"$ScriptPath`" -DatabaseName $($job.Database) -BackupType $($job.BackupType) -SevenZipCompress"

  # Root index entry (injected into root section before its closing tag)
  $newRefs.Add("BackupTask={ *§* $tg *§* }")

  # Build the 8 sections for this task
  $null = $newSections.Append((Sec-Task $tg $job))
  $null = $newSections.Append((Sec-PreEvent $evtg $PwshExe $psArgs))
  $null = $newSections.Append((Sec-Path $dg $destPath $dsg $dfg))
  $null = $newSections.Append((Sec-Sftp $dsg $dsp))
  $null = $newSections.Append((Sec-Proxy $dsp))
  $null = $newSections.Append((Sec-Ftp $dfg $dfp))
  $null = $newSections.Append((Sec-Proxy $dfp))
  $null = $newSections.Append((Sec-Schedule $schg $job.DateTime))

  Write-Host "  [+] $($job.Name)" -ForegroundColor Green
}

# ── Inject BackupTask references into root section ────────────────────────────
if ($newRefs.Count -gt 0) {
  $closeTag = "<§§- $rootGuid -§§>"
  $insertion = ($newRefs -join "`r`n") + "`r`n"
  $raw = $raw.Replace($closeTag, $insertion + $closeTag)
}

# ── Append all new sections to end of file ────────────────────────────────────
$raw += $newSections.ToString()

# ── Write file back (UTF-8, no BOM) ──────────────────────────────────────────
[System.IO.File]::WriteAllText($ListPath, $raw, [System.Text.Encoding]::UTF8)
Write-Host "`nSaved: $ListPath" -ForegroundColor Cyan

# ── Restart Cobian service ────────────────────────────────────────────────────
if ($svc) {
  Write-Host "Starting: $($svc.Name) ..."
  Start-Service -Name $svc.Name
  $svc.WaitForStatus('Running', '00:00:30')
  Write-Host '  Running.' -ForegroundColor Green
}

Write-Host @'

===== Done =====
Next steps:
  1. Open Cobian UI — verify four 'SQL Server Backups' tasks appear.
  2. For each Full task         → change schedule to Weekly, Sunday only.
  3. For each Differential task → change schedule to Weekly, Monday-Saturday.

Verification:
  - Let a task fire, then check C:\Dropbox\Backups\utat022\{Database}\ for .bak.7z
  - If the pre-event fails, Cobian will abort and log it in Cobian History.

Recovery (if tasks don't appear):
  Stop service, copy the .bak_ file back to MainList.lst, restart service.
'@ -ForegroundColor White
