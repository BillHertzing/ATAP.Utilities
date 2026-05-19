<#
.SYNOPSIS
    Creates five Cobian Reflector application-data backup tasks by directly writing
    to MainList.lst in the exact format confirmed from utat022.

.DESCRIPTION
    Each task is a standard Cobian file-copy task (TaskBackupType 0=Full or 1=Incremental).
    Cobian copies the source directory tree directly to the destination — no script
    invocation or pre-event is used (unlike the SQL backup Dummy tasks in New-CobianSqlJobs).

    Tasks created (grouped under 'App Data Backups'):
      03:00 Sun     App - ProGet - Full             Full backup of C:\ProgramData\ProGet\
      03:00 Mon-Sat App - ProGet - Incremental      Incremental backup of C:\ProgramData\ProGet\
      03:30 Sun     App - BuildMaster - Full        Full backup of C:\ProgramData\BuildMaster\
      03:30 Mon-Sat App - BuildMaster - Incremental Incremental of C:\ProgramData\BuildMaster\
      03:50 Sun     App - Cobian Config - Full      Full backup of Cobian Lists\ (MainList.lst itself)

    All destinations are under C:\Dropbox\Backups\utat022\ so Dropbox syncs them offsite.

    Architecture difference from SQL tasks:
      SQL tasks (New-CobianSqlJobs) — Dummy (type 3) + pre-event → script invoked
      App tasks (this cmdlet)       — File copy (type 0/1) → no pre-event, direct copy

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

.OUTPUTS
    [void]

.EXAMPLE
    New-CobianAppJobs
    # Create all five tasks using default paths and start times.

.EXAMPLE
    New-CobianAppJobs -ProGetFullStartTime '04:00' -WhatIf
    # Preview changes without writing to MainList.lst.

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
    Uses Weekly schedule (SchSchedule=2) for all tasks, confirmed from live MainList.lst.
    Full tasks        → Weekly, Sunday only (SchDaysOfWeek=0)
    Incremental tasks → Weekly, Monday-Saturday (SchDaysOfWeek=1..6)
    SchDateAndTime format: 'YYYY-MM-DD HH:MM:SS:' (trailing colon, no milliseconds).
    SchDaysOfWeek repeats per selected day — requires §DuplicatedKeys:True on section.

    COMPRESSION NOTE:
    ProGet sources use TaskCompression=0 (None) because .nupkg files are already
    ZIP-compressed; re-compressing provides minimal gain and wastes CPU.
    BuildMaster and Cobian sources use TaskCompression=2 (7z).

    INCREMENTAL RETENTION NOTE:
    TaskDifferentialCopiesToKeep controls incremental archive retention
    (same key for both Differential SQL and Incremental file backups).

    See also: _Planning Explainer 0021a — Application Data Backup: ProGet and BuildMaster
              _Planning Explainer 0023 — Cobian Reflector MainList.lst Format
              New-CobianSqlJobs — reference for SQL Dummy task creation pattern

    SC refs: SC-0066 (application backups), TASKS.md Task 4.4

.LINK
    https://github.com/whertzing/ATAP.Utilities
#>
function New-CobianAppJobs {
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
  [OutputType([void])]
  param(
    [Parameter(Mandatory = $false)]
    [string] $ListPath = 'C:\Program Files\Cobian Reflector\Lists\MainList.lst',

    [Parameter(Mandatory = $false)]
    [string] $ProGetDataPath = 'C:\ProgramData\ProGet',

    [Parameter(Mandatory = $false)]
    [string] $BuildMasterDataPath = 'C:\ProgramData\BuildMaster',

    [Parameter(Mandatory = $false)]
    [string] $BackupRoot = 'C:\Dropbox\Backups\utat022',

    [Parameter(Mandatory = $false)]
    [string] $ProGetFullStartTime = '03:00',

    [Parameter(Mandatory = $false)]
    [string] $ProGetIncrementalStartTime = '03:00',

    [Parameter(Mandatory = $false)]
    [string] $BuildMasterFullStartTime = '03:30',

    [Parameter(Mandatory = $false)]
    [string] $BuildMasterIncrementalStartTime = '03:30',

    [Parameter(Mandatory = $false)]
    [string] $CobianConfigFullStartTime = '03:50'
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = $MyInvocation.MyCommand.ModuleName

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Entering function'

    # Load Helpers
    try {
      # ToDo: Remove this when packaging works
      if (-not (Get-Command -Name 'Get-ParameterValueFromNeoConfigurationRoot' -CommandType Function -ErrorAction SilentlyContinue)) {
        . "C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Powershell\public\Get-ParameterValueFromNeoConfigurationRoot.ps1"
      }
    }
    catch {
      $errorMessage = "Failed to load Get-ParameterValueFromNeoConfigurationRoot function. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw
    }

    $principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
      throw "$fn must be run from an elevated PowerShell session because it updates Cobian Reflector task files."
    }

    # Check and populate simple parameter (snippet: CheckAndPopulateSimpleParameter, param: ListPath)
    $ListPath = Get-PVal -ParameterName ListPath -originalPSBoundParameters $PSBoundParameters -dottedPath ListPath -DefaultValue $ListPath

    # Check and populate simple parameter (snippet: CheckAndPopulateSimpleParameter, param: ProGetDataPath)
    $ProGetDataPath = Get-PVal -ParameterName ProGetDataPath -originalPSBoundParameters $PSBoundParameters -dottedPath ProGetDataPath -DefaultValue $ProGetDataPath

    # Check and populate simple parameter (snippet: CheckAndPopulateSimpleParameter, param: BuildMasterDataPath)
    $BuildMasterDataPath = Get-PVal -ParameterName BuildMasterDataPath -originalPSBoundParameters $PSBoundParameters -dottedPath BuildMasterDataPath -DefaultValue $BuildMasterDataPath

    # Check and populate simple parameter (snippet: CheckAndPopulateSimpleParameter, param: BackupRoot)
    $BackupRoot = Get-PVal -ParameterName BackupRoot -originalPSBoundParameters $PSBoundParameters -dottedPath BackupRoot -DefaultValue $BackupRoot

    # Check and populate simple parameter (snippet: CheckAndPopulateSimpleParameter, param: ProGetFullStartTime)
    $ProGetFullStartTime = Get-PVal -ParameterName ProGetFullStartTime -originalPSBoundParameters $PSBoundParameters -dottedPath ProGetFullStartTime -DefaultValue $ProGetFullStartTime

    # Check and populate simple parameter (snippet: CheckAndPopulateSimpleParameter, param: ProGetIncrementalStartTime)
    $ProGetIncrementalStartTime = Get-PVal -ParameterName ProGetIncrementalStartTime -originalPSBoundParameters $PSBoundParameters -dottedPath ProGetIncrementalStartTime -DefaultValue $ProGetIncrementalStartTime

    # Check and populate simple parameter (snippet: CheckAndPopulateSimpleParameter, param: BuildMasterFullStartTime)
    $BuildMasterFullStartTime = Get-PVal -ParameterName BuildMasterFullStartTime -originalPSBoundParameters $PSBoundParameters -dottedPath BuildMasterFullStartTime -DefaultValue $BuildMasterFullStartTime

    # Check and populate simple parameter (snippet: CheckAndPopulateSimpleParameter, param: BuildMasterIncrementalStartTime)
    $BuildMasterIncrementalStartTime = Get-PVal -ParameterName BuildMasterIncrementalStartTime -originalPSBoundParameters $PSBoundParameters -dottedPath BuildMasterIncrementalStartTime -DefaultValue $BuildMasterIncrementalStartTime

    # Check and populate simple parameter (snippet: CheckAndPopulateSimpleParameter, param: CobianConfigFullStartTime)
    $CobianConfigFullStartTime = Get-PVal -ParameterName CobianConfigFullStartTime -originalPSBoundParameters $PSBoundParameters -dottedPath CobianConfigFullStartTime -DefaultValue $CobianConfigFullStartTime

    # ── Encrypted-empty constants (verbatim from existing MainList.lst) ────────────
    # Represent blank credentials for required SFTP/FTP/proxy sub-sections.
    $E1 = '#Cob2#00028STtl5ohYeTQp2nUFQ5pQT0MGcTs=000010'
    $E2 = '#Cob2#0002838kVKKCUZXP8aHrszOuGULKbVrQ=000010'
    $E3 = '#Cob2#00028nQojpt8RaLw/IsmOaHreGrieGBk=000010'
    $E4 = '#Cob2#00028UJSEfJWl87+n3QYnZ9Oh+BsJb3E=000010'
    $E5 = '#Cob2#00028keVJTf7x6LatTLPJ3/iBgCY9RfQ=000010'

    # ── Private helpers ────────────────────────────────────────────────────────────

    function ng { [guid]::NewGuid().ToString().ToLower() }

    # Returns 'YYYY-MM-DD HH:MM:SS:' for the next occurrence of $DayOfWeek at $StartTime.
    function getNextWeekdayDateTime {
      param([int]$DayOfWeek, [string]$StartTime)
      $today     = [datetime]::Today
      $daysUntil = ($DayOfWeek - [int]$today.DayOfWeek + 7) % 7
      if ($daysUntil -eq 0) { $daysUntil = 7 }   # always next occurrence, never today
      $nextDate  = $today.AddDays($daysUntil).ToString('yyyy-MM-dd')
      return "$nextDate ${StartTime}:00:"
    }

    function buildProxySection([string]$g) {
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

    function buildSftpSection([string]$g, [string]$p) {
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

    function buildFtpSection([string]$g, [string]$p) {
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

    function buildPathSection([string]$g, [string]$path, [string]$sftp, [string]$ftp) {
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

    function buildScheduleSection([string]$g, [string]$dt, [int[]]$days) {
      # SchSchedule=2 = Weekly (confirmed from live MainList.lst)
      # SchDaysOfWeek: 0=Sun 1=Mon 2=Tue 3=Wed 4=Thu 5=Fri 6=Sat
      # §DuplicatedKeys:True required for repeating SchDaysOfWeek entries
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

    function buildAppTaskSection([string]$g, [hashtable]$j) {
      $tid = ng
      # TaskBackupType: 0=Full, 1=Incremental (not 3=Dummy used by SQL tasks)
      $fullKeep  = if ($j.BackupType -eq 0) { 5 } else { 0 }
      $diffKeep  = if ($j.BackupType -eq 0) { 0 } else { 6 }
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
  }

  process {
    try {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "New-CobianAppJobs  ListPath='$ListPath'  ProGetSrc='$ProGetDataPath'  BMSrc='$BuildMasterDataPath'  BackupRoot='$BackupRoot'"

      # ── Job definitions ──────────────────────────────────────────────────────────
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
          DateTime    = getNextWeekdayDateTime 0 $ProGetFullStartTime
          Days        = @(0)
        }
        @{
          Name        = 'App - ProGet - Incremental'
          Group       = 'App Data Backups'
          SrcPath     = $ProGetDataPath
          DstSubdir   = 'ProGet-AppData'
          BackupType  = 1
          Compression = 0
          DateTime    = getNextWeekdayDateTime 1 $ProGetIncrementalStartTime
          Days        = @(1, 2, 3, 4, 5, 6)
        }
        @{
          Name        = 'App - BuildMaster - Full'
          Group       = 'App Data Backups'
          SrcPath     = $BuildMasterDataPath
          DstSubdir   = 'BuildMaster-AppData'
          BackupType  = 0
          Compression = 2
          DateTime    = getNextWeekdayDateTime 0 $BuildMasterFullStartTime
          Days        = @(0)
        }
        @{
          Name        = 'App - BuildMaster - Incremental'
          Group       = 'App Data Backups'
          SrcPath     = $BuildMasterDataPath
          DstSubdir   = 'BuildMaster-AppData'
          BackupType  = 1
          Compression = 2
          DateTime    = getNextWeekdayDateTime 1 $BuildMasterIncrementalStartTime
          Days        = @(1, 2, 3, 4, 5, 6)
        }
        @{
          Name        = 'App - Cobian Config - Full'
          Group       = 'App Data Backups'
          SrcPath     = 'C:\Program Files\Cobian Reflector\Lists'
          DstSubdir   = 'Cobian-Config'
          BackupType  = 0
          Compression = 2
          DateTime    = getNextWeekdayDateTime 0 $CobianConfigFullStartTime
          Days        = @(0)
        }
      )

      # ── Validate ─────────────────────────────────────────────────────────────────
      if (-not (Test-Path $ListPath)) { throw "List file not found: $ListPath" }

      foreach ($j in $jobs) {
        if (-not (Test-Path $j.SrcPath)) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Tag 'Warning' -Message "Source path not found: $($j.SrcPath)"
          if (-not $PSCmdlet.ShouldContinue("Source path '$($j.SrcPath)' does not exist.", 'Continue anyway?')) {
            throw "Aborted by user — source path missing: $($j.SrcPath)"
          }
        }
      }

      # ── Stop Cobian service ───────────────────────────────────────────────────────
      $svc = Get-Service -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like '*Cobian*' -or $_.DisplayName -like '*Cobian*' } |
        Select-Object -First 1

      if ($svc) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Stopping service: $($svc.Name)..."
        if ($PSCmdlet.ShouldProcess($svc.Name, 'Stop Cobian service')) {
          Stop-Service -Name $svc.Name -Force
          $svc.WaitForStatus('Stopped', '00:00:30')
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Service stopped: $($svc.Name)"
        }
      } else {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Tag 'Warning' -Message 'Cobian service not found. Ensure the Cobian engine is closed before continuing.'
        if (-not $PSCmdlet.ShouldContinue('Cobian service not found.', 'Continue anyway?')) {
          throw 'Aborted by user — Cobian service not found.'
        }
      }

      # ── Backup existing file ──────────────────────────────────────────────────────
      $bak = "$ListPath.bak_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
      if ($PSCmdlet.ShouldProcess($bak, "Backup MainList.lst")) {
        Copy-Item $ListPath $bak
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Backup created: $bak"
      }

      # ── Read file — detect and preserve native encoding ───────────────────────────
      $sr           = [System.IO.StreamReader]::new($ListPath, $true)
      $raw          = $sr.ReadToEnd()
      $fileEncoding = $sr.CurrentEncoding
      $sr.Dispose()
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "File encoding: $($fileEncoding.EncodingName)"

      # ── Find root section GUID ────────────────────────────────────────────────────
      if ($raw -notmatch '<§- ([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}) -§>') {
        throw "Cannot find root section GUID in $ListPath"
      }
      $rootGuid = $Matches[1]
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Root GUID: $rootGuid"

      # ── Find existing task names (idempotency) ────────────────────────────────────
      $existingNames = @(
        [regex]::Matches($raw, '(?m)^TaskName=(.+)$') |
          ForEach-Object { $_.Groups[1].Value.Trim() }
      )
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Existing tasks ($($existingNames.Count)): $($existingNames -join ', ')"

      # ── Build new sections ────────────────────────────────────────────────────────
      $newRefs     = [System.Collections.Generic.List[string]]::new()
      $newSections = [System.Text.StringBuilder]::new()

      foreach ($job in $jobs) {
        if ($existingNames -contains $job.Name) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Tag 'Warning' -Message "Skipping (already exists): $($job.Name)"
          continue
        }

        $destPath = Join-Path $BackupRoot $job.DstSubdir
        if (-not (Test-Path $destPath)) {
          New-Item -ItemType Directory -Path $destPath -Force | Out-Null
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Created destination folder: $destPath"
        }

        # Generate all 12 GUIDs for this task's sections
        $tg  = ng
        $sg  = ng; $ssg = ng; $ssp = ng; $sfg = ng; $sfp = ng
        $dg  = ng; $dsg = ng; $dsp = ng; $dfg = ng; $dfp = ng
        $schg = ng

        $job['SrcGuid'] = $sg
        $job['DstGuid'] = $dg
        $job['SchGuid'] = $schg

        $newRefs.Add("BackupTask={ *§* $tg *§* }")

        $null = $newSections.Append((buildAppTaskSection  $tg   $job))
        $null = $newSections.Append((buildPathSection     $sg   $job.SrcPath $ssg $sfg))
        $null = $newSections.Append((buildSftpSection     $ssg  $ssp))
        $null = $newSections.Append((buildProxySection    $ssp))
        $null = $newSections.Append((buildFtpSection      $sfg  $sfp))
        $null = $newSections.Append((buildProxySection    $sfp))
        $null = $newSections.Append((buildPathSection     $dg   $destPath $dsg $dfg))
        $null = $newSections.Append((buildSftpSection     $dsg  $dsp))
        $null = $newSections.Append((buildProxySection    $dsp))
        $null = $newSections.Append((buildFtpSection      $dfg  $dfp))
        $null = $newSections.Append((buildProxySection    $dfp))
        $null = $newSections.Append((buildScheduleSection $schg $job.DateTime $job.Days))

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "[+] $($job.Name)"
      }

      # ── Inject BackupTask references into root section ────────────────────────────
      if ($newRefs.Count -gt 0 -and $PSCmdlet.ShouldProcess($ListPath, 'Inject task references and append sections')) {
        $closeTag  = "<§§- $rootGuid -§§>"
        $insertion = ($newRefs -join "`r`n") + "`r`n"
        $raw       = $raw.Replace($closeTag, $insertion + $closeTag)

        # Normalize bare LF to CRLF before appending (Cobian requires CRLF in its file)
        $newContent = $newSections.ToString() -replace '(?<!\r)\n', "`r`n"
        $raw += $newContent

        [System.IO.File]::WriteAllText($ListPath, $raw, $fileEncoding)
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Saved: $ListPath"
      }

      # ── Restart Cobian service ────────────────────────────────────────────────────
      if ($svc -and $PSCmdlet.ShouldProcess($svc.Name, 'Start Cobian service')) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Starting service: $($svc.Name)..."
        Start-Service -Name $svc.Name
        $svc.WaitForStatus('Running', '00:00:30')
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Service running: $($svc.Name)"
      }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'Done. Next steps: (1) Open Cobian UI — verify five App Data Backups tasks appear; schedules are Weekly/Sunday (Full) and Weekly/Mon-Sat (Incremental). (2) Right-click each Full task → Run Now — confirm archives appear under Dropbox. Recovery: stop service, copy the .bak_ file back to MainList.lst, restart service. See Explainer 0023.'
    }
    catch {
      $errorMessage = "New-CobianAppJobs failed. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Leaving function'
  }
}
