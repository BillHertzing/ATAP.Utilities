<#
.SYNOPSIS
    Creates five Cobian Reflector application-data backup tasks by directly writing
    to MainList.lst in the exact format confirmed from utat022.

.DESCRIPTION
    Each task is a standard Cobian file-copy task (TaskBackupType 0=Full or 1=Incremental).
    Cobian copies the source directory tree directly to the destination — no script
    invocation or pre-event is used (unlike the SQL backup Dummy tasks in New-CobianSqlJobs.ps1).

    Tasks created (grouped under 'App Data Backups'):
      03:00 Sun    App - ProGet - Full           Full backup of C:\ProgramData\ProGet\
      03:00 Mon-Sat App - ProGet - Incremental   Incremental backup of C:\ProgramData\ProGet\
      03:30 Sun    App - BuildMaster - Full      Full backup of C:\ProgramData\BuildMaster\
      03:30 Mon-Sat App - BuildMaster - Incremental  Incremental of C:\ProgramData\BuildMaster\
      03:50 Sun    App - Cobian Config - Full    Full backup of Cobian Lists\ (MainList.lst itself)

    All destinations are under C:\Dropbox\Backups\utat022\ so Dropbox syncs them offsite.

    Architecture difference from SQL tasks:
      SQL tasks  (New-CobianSqlJobs.ps1) — Dummy (type 3) + pre-event → script invoked
      App tasks  (this script)           — File copy (type 0/1) → no pre-event, direct copy

.PARAMETER ListPath
    Path to Cobian Reflector's MainList.lst. Default: standard install location.

.PARAMETER ProGetDataPath
    Source path for ProGet application data. Default: C:\ProgramData\ProGet\.
    Override only if ProGet was configured with a non-default data directory.

.PARAMETER BuildMasterDataPath
    Source path for BuildMaster application data. Default: C:\ProgramData\BuildMaster\.

.PARAMETER BackupRoot
    Root folder for backup destinations. Per-task subdirectories are created here.
    Default: C:\Dropbox\Backups\utat022\.

.PARAMETER ProGetFullStartTime
    Start time (HH:MM) for the weekly ProGet Full backup (Sunday). Default: 03:00.

.PARAMETER ProGetIncrementalStartTime
    Start time (HH:MM) for the weekly ProGet Incremental backup (Mon-Sat). Default: 03:00.

.PARAMETER BuildMasterFullStartTime
    Start time (HH:MM) for the weekly BuildMaster Full backup (Sunday). Default: 03:30.

.PARAMETER BuildMasterIncrementalStartTime
    Start time (HH:MM) for the weekly BuildMaster Incremental backup (Mon-Sat). Default: 03:30.

.PARAMETER CobianConfigFullStartTime
    Start time (HH:MM) for the weekly Cobian Config Full backup (Sunday). Default: 03:50.

.NOTES
    AI assisted using Powershell.instructions.md as guidelines

    ► Run as Administrator on utat022
    ► Backs up MainList.lst automatically before modifying it
    ► Idempotent — skips tasks that already exist by name

    Confirmed data directories (verified 2026-04-03):
      ProGet      C:\ProgramData\ProGet\       (9.3 MB — Packages\, Extensions\, LocalStorage\)
      BuildMaster C:\ProgramData\BuildMaster\  (~0 MB currently — Extensions\, Temp\)
      Cobian      C:\Program Files\Cobian Reflector\Lists\  (73 KB — MainList.lst)

    Data dirs are NOT under C:\ProgramData\Inedo\ — that directory has only ExtensionCache\
    and SharedConfig\ (the latter is already under Git via ATAP.IAC).

    SCHEDULE NOTE:
    The script uses Weekly schedule (SchSchedule=2) for all tasks, confirmed from
    the live MainList.lst after the Cobian UI updated the SQL tasks to weekly.
    Full tasks          → Weekly, Sunday only (SchDaysOfWeek=0)
    Incremental tasks   → Weekly, Monday-Saturday (SchDaysOfWeek=1..6)
    SchDateAndTime format: 'YYYY-MM-DD HH:MM:SS:' (trailing colon, no milliseconds).
    SchDaysOfWeek repeats per selected day — requires §DuplicatedKeys:True on section.

    COMPRESSION NOTE:
    ProGet sources use TaskCompression=0 (None) because .nupkg files are already
    ZIP-compressed; re-compressing provides minimal gain and wastes CPU.
    BuildMaster and Cobian sources use TaskCompression=2 (7z).

    INCREMENTAL RETENTION NOTE:
    TaskDifferentialCopiesToKeep is used by Cobian to control incremental archive retention
    (same key for both Differential SQL and Incremental file backups — confirmed from the
    existing Hydrus Backup task in MainList.lst).

    See also: _Planning Explainer 0021a — Application Data Backup: ProGet and BuildMaster
              _Planning Explainer 0023 — Cobian Reflector MainList.lst Format
              New-CobianSqlJobs.ps1   — reference for SQL Dummy task creation pattern

    SC refs: SC-0066 (application backups), TASKS.md Task 4.4
#>

#Requires -RunAsAdministrator

param(
  [string]$ListPath                      = 'C:\Program Files\Cobian Reflector\Lists\MainList.lst',
  [string]$ProGetDataPath                = 'C:\ProgramData\ProGet',
  [string]$BuildMasterDataPath           = 'C:\ProgramData\BuildMaster',
  [string]$BackupRoot                    = 'C:\Dropbox\Backups\utat022',
  # Start times (HH:MM) — defaults match the schedule stagger in Explainer 0021a
  [string]$ProGetFullStartTime           = '03:00',
  [string]$ProGetIncrementalStartTime    = '03:00',
  [string]$BuildMasterFullStartTime      = '03:30',
  [string]$BuildMasterIncrementalStartTime = '03:30',
  [string]$CobianConfigFullStartTime     = '03:50'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Encrypted-empty constants taken verbatim from existing MainList.lst
# (represent blank credentials for required SFTP/FTP/proxy sub-sections)
$E1 = '#Cob2#00028STtl5ohYeTQp2nUFQ5pQT0MGcTs=000010'
$E2 = '#Cob2#0002838kVKKCUZXP8aHrszOuGULKbVrQ=000010'
$E3 = '#Cob2#00028nQojpt8RaLw/IsmOaHreGrieGBk=000010'
$E4 = '#Cob2#00028UJSEfJWl87+n3QYnZ9Oh+BsJb3E=000010'
$E5 = '#Cob2#00028keVJTf7x6LatTLPJ3/iBgCY9RfQ=000010'

function ng { [guid]::NewGuid().ToString().ToLower() }

# Returns 'YYYY-MM-DD HH:MM:SS:' for the next occurrence of $dayOfWeek (0=Sun…6=Sat) at $startTime (HH:MM)
function Get-NextWeekdayDateTime {
  param([int]$DayOfWeek, [string]$StartTime)
  $today       = [datetime]::Today
  $daysUntil   = ($DayOfWeek - [int]$today.DayOfWeek + 7) % 7
  if ($daysUntil -eq 0) { $daysUntil = 7 }   # always next occurrence, never today
  $nextDate    = $today.AddDays($daysUntil).ToString('yyyy-MM-dd')
  return "$nextDate ${StartTime}:00:"
}

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

function Sec-Schedule([string]$g, [string]$dt, [int[]]$days) {
  # SchSchedule=2 = Weekly (confirmed from live MainList.lst — SQL tasks updated via UI)
  # SchDaysOfWeek encoding: 0=Sun, 1=Mon, 2=Tue, 3=Wed, 4=Thu, 5=Fri, 6=Sat (confirmed)
  # SchDateAndTime format: 'YYYY-MM-DD HH:MM:SS:' (trailing colon, no ms — confirmed)
  # §DuplicatedKeys:True is required for repeating SchDaysOfWeek entries
  $dateOnly = ($dt -split ' ')[0]
  $dayLines = ($days | ForEach-Object { "SchDaysOfWeek=$_" }) -join "`r`n"
  return @"

<§- $g -§>
§DuplicatedKeys:True
§CaseSensitive:False
§PairSeparator:=
SchSchedule=2
SchDateAndTime=$dt
$dayLines
SchTimer=0
SchTimerLowerLimit=${dateOnly} 00:00:00:
SchTimerUpperLimit=${dateOnly} 23:59:00:
SchUseOrdinaryDaysOfWeek=False
<§§- $g -§§>
"@
}

function Sec-AppTask([string]$g, [hashtable]$j) {
  $tid = ng
  # TaskBackupType: 0=Full, 1=Incremental (not 3=Dummy used by SQL tasks)
  # Full  tasks: TaskFullCopiesToKeep=5, TaskDifferentialCopiesToKeep=0
  # Incr  tasks: TaskFullCopiesToKeep=0, TaskDifferentialCopiesToKeep=6
  $fullKeep = if ($j.BackupType -eq 0) { 5 } else { 0 }
  $diffKeep = if ($j.BackupType -eq 0) { 0 } else { 6 }
  # TaskCompressionLevel: only meaningful when TaskCompression != 0
  $comprLevel = if ($j.Compression -eq 0) { 1 } else { 5 }
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
TaskBackupType=$($j.BackupType)
TaskSource={ *§* $($j.SrcGuid) *§* }
TaskDestination={ *§* $($j.DstGuid) *§* }
TaskSchedule={ *§* $($j.SchGuid) *§* }
TaskPriority=2
TaskFullCopiesToKeep=$fullKeep
TaskDifferentialCopiesToKeep=$diffKeep
TaskForceFullBackupCount=0
TaskFixedFullBackup=False
TaskFixedFullBackupDay=0
TaskCompression=$($j.Compression)
TaskArchiveComment=
TaskEncryptFiles=False
TaskPassPhrase=$E3
TaskPhraseHint=
TaskCompressionLevel=$comprLevel
CompressionMethod=0
SplitArchive=0
SplitSize=524288000
TaskCancelIfPreEventFails=False
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
# BackupType: 0=Full, 1=Incremental
# Compression: 0=None, 2=7z  (None for .nupkg sources — already ZIP-compressed)

$jobs = @(
  @{
    Name        = 'App - ProGet - Full'
    Group       = 'App Data Backups'
    SrcPath     = $ProGetDataPath
    DstSubdir   = 'ProGet-AppData'
    BackupType  = 0
    Compression = 0
    DateTime    = Get-NextWeekdayDateTime 0 $ProGetFullStartTime           # Sunday
    Days        = @(0)
  }
  @{
    Name        = 'App - ProGet - Incremental'
    Group       = 'App Data Backups'
    SrcPath     = $ProGetDataPath
    DstSubdir   = 'ProGet-AppData'
    BackupType  = 1
    Compression = 0
    DateTime    = Get-NextWeekdayDateTime 1 $ProGetIncrementalStartTime    # Monday (first of Mon-Sat)
    Days        = @(1, 2, 3, 4, 5, 6)
  }
  @{
    Name        = 'App - BuildMaster - Full'
    Group       = 'App Data Backups'
    SrcPath     = $BuildMasterDataPath
    DstSubdir   = 'BuildMaster-AppData'
    BackupType  = 0
    Compression = 2
    DateTime    = Get-NextWeekdayDateTime 0 $BuildMasterFullStartTime      # Sunday
    Days        = @(0)
  }
  @{
    Name        = 'App - BuildMaster - Incremental'
    Group       = 'App Data Backups'
    SrcPath     = $BuildMasterDataPath
    DstSubdir   = 'BuildMaster-AppData'
    BackupType  = 1
    Compression = 2
    DateTime    = Get-NextWeekdayDateTime 1 $BuildMasterIncrementalStartTime  # Monday
    Days        = @(1, 2, 3, 4, 5, 6)
  }
  @{
    Name        = 'App - Cobian Config - Full'
    Group       = 'App Data Backups'
    SrcPath     = 'C:\Program Files\Cobian Reflector\Lists'
    DstSubdir   = 'Cobian-Config'
    BackupType  = 0
    Compression = 2
    DateTime    = Get-NextWeekdayDateTime 0 $CobianConfigFullStartTime     # Sunday
    Days        = @(0)
  }
)

# ── Validate ──────────────────────────────────────────────────────────────────
if (-not (Test-Path $ListPath)) { throw "Not found: $ListPath" }
foreach ($j in $jobs) {
  if (-not (Test-Path $j.SrcPath)) {
    Write-Warning "Source path not found (pausing): $($j.SrcPath)"
    $null = Read-Host '  Press ENTER to continue (or Ctrl+C to abort)'
  }
}

Write-Host "`n===== New-CobianAppJobs =====" -ForegroundColor Cyan
Write-Host "List file  : $ListPath"
Write-Host "ProGet src : $ProGetDataPath"
Write-Host "BM src     : $BuildMasterDataPath"
Write-Host "Backup root: $BackupRoot"

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

# ── Read file — detect and preserve native encoding (UTF-16 LE or UTF-8) ─────
$sr = [System.IO.StreamReader]::new($ListPath, $true)   # detectEncodingFromBom=true
$raw = $sr.ReadToEnd()
$fileEncoding = $sr.CurrentEncoding
$sr.Dispose()
Write-Host "File encoding  : $($fileEncoding.EncodingName)"

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
  $destPath = Join-Path $BackupRoot $job.DstSubdir
  if (-not (Test-Path $destPath)) {
    New-Item -ItemType Directory -Path $destPath -Force | Out-Null
    Write-Host "  Created folder: $destPath"
  }

  # Generate all 12 GUIDs for this task's sections
  $tg = ng                                                      # task
  $sg = ng; $ssg = ng; $ssp = ng; $sfg = ng; $sfp = ng         # src path + sftp + proxy + ftp + proxy
  $dg = ng; $dsg = ng; $dsp = ng; $dfg = ng; $dfp = ng         # dst path + sftp + proxy + ftp + proxy
  $schg = ng                                                      # schedule

  $job['SrcGuid'] = $sg
  $job['DstGuid'] = $dg
  $job['SchGuid'] = $schg

  # Root index entry (injected into root section before its closing tag)
  $newRefs.Add("BackupTask={ *§* $tg *§* }")

  # Build the 12 sections for this task
  $null = $newSections.Append((Sec-AppTask $tg $job))
  $null = $newSections.Append((Sec-Path $sg $job.SrcPath $ssg $sfg))
  $null = $newSections.Append((Sec-Sftp $ssg $ssp))
  $null = $newSections.Append((Sec-Proxy $ssp))
  $null = $newSections.Append((Sec-Ftp $sfg $sfp))
  $null = $newSections.Append((Sec-Proxy $sfp))
  $null = $newSections.Append((Sec-Path $dg $destPath $dsg $dfg))
  $null = $newSections.Append((Sec-Sftp $dsg $dsp))
  $null = $newSections.Append((Sec-Proxy $dsp))
  $null = $newSections.Append((Sec-Ftp $dfg $dfp))
  $null = $newSections.Append((Sec-Proxy $dfp))
  $null = $newSections.Append((Sec-Schedule $schg $job.DateTime $job.Days))

  Write-Host "  [+] $($job.Name)" -ForegroundColor Green
}

# ── Inject BackupTask references into root section ────────────────────────────
if ($newRefs.Count -gt 0) {
  $closeTag = "<§§- $rootGuid -§§>"
  $insertion = ($newRefs -join "`r`n") + "`r`n"
  $raw = $raw.Replace($closeTag, $insertion + $closeTag)
}

# ── Append all new sections to end of file ────────────────────────────────────
# Normalize to CRLF: the script file is LF-encoded (VS Code default), so heredoc
# strings use LF only. Cobian requires CRLF in its UTF-16 file. The regex leaves
# existing \r\n pairs untouched and converts bare \n to \r\n.
$newContent = $newSections.ToString() -replace '(?<!\r)\n', "`r`n"
$raw += $newContent

# ── Write file back — preserve original encoding (UTF-16 LE when Cobian UI rewrites) ──
[System.IO.File]::WriteAllText($ListPath, $raw, $fileEncoding)
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
  1. Open Cobian UI — verify five 'App Data Backups' tasks appear.
     Full tasks    → Weekly, Sunday only   (already set by script — verify in UI)
     Incremental   → Weekly, Monday-Saturday (already set by script — verify in UI)
  2. Right-click each Full task  → Run Now — confirm archives appear in Dropbox.

Destination directories:
  C:\Dropbox\Backups\utat022\ProGet-AppData\
  C:\Dropbox\Backups\utat022\BuildMaster-AppData\
  C:\Dropbox\Backups\utat022\Cobian-Config\

Verification:
  Get-ChildItem 'C:\Dropbox\Backups\utat022\ProGet-AppData' | Sort-Object LastWriteTime
  Get-ChildItem 'C:\Dropbox\Backups\utat022\BuildMaster-AppData' | Sort-Object LastWriteTime
  Get-ChildItem 'C:\Dropbox\Backups\utat022\Cobian-Config' | Sort-Object LastWriteTime

Recovery (if tasks do not appear):
  Stop service, copy the .bak_ file back to MainList.lst, restart service.
  See Explainer 0023 — Recovery Procedure.
'@ -ForegroundColor White
