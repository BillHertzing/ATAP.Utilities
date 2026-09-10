<#
.SYNOPSIS
    Performs a SQL Server backup of a specified database to the standard backup location.

.DESCRIPTION
    Backs up a SQL Server database to the host's publication subtree,
    <DatabaseBackupPublicationRoot>\<lowercase-hostname>\<DatabaseName>\.
    Supports Full and Differential backup types.
    Uses dbaTools for reliable SQL Server backup operations with built-in verification.
    Intended to be called from a scheduler (Windows Task Scheduler today) on any ATAP host.

    No filesystem root is hardcoded. Every root is resolved through Get-PVal from
    $global:Settings keyed by $global:ConfigRootKeys:
        LocalDBsRootPathConfigRootKey                 -> instance-local staging root (C:/LocalDBs)
        DatabaseBackupPublicationRootConfigRootKey    -> off-host publication root (C:/Dropbox/Backups)
        FastTempBasePathConfigRootKey                 -> fast staging scratch
    The host namespace is derived from ComputerName (lowercased), so UTAT022 publishes
    under .../utat022 and UTAT01 under .../utat01 with no per-host edits.
    If a required root cannot be resolved the function throws rather than guessing a path.

    Backup file naming convention:
        <DatabaseName>_FULL_yyyyMMdd_HHmmss.bak   (weekly full)
        <DatabaseName>_DIFF_yyyyMMdd_HHmmss.bak   (nightly differential)

.PARAMETER DatabaseName
    The name of the database to back up. Validated against known databases on the instance.
    Typical values: 'ProGet', 'BuildMaster'.

.PARAMETER BackupType
    The type of backup to perform. Must be 'Full' or 'Differential'. Default: 'Full'.
    A Differential backup requires at least one prior Full backup on the same instance.

.PARAMETER SqlInstance
    The SQL Server instance to connect to. Default: 'localhost\Production'.
    Override when calling from a remote host or in testing.

.PARAMETER ComputerName
    Host namespace for the publication subtree. Default: the lowercased name of the
    machine this runs on ($env:COMPUTERNAME), resolved through Get-PVal.

.PARAMETER DatabaseBackupPublicationRoot
    Off-host publication root. Resolved through Get-PVal from
    $global:Settings[$global:ConfigRootKeys['DatabaseBackupPublicationRootConfigRootKey']],
    canonically 'C:/Dropbox/Backups'. Throws if it cannot be resolved; never guessed.
    SQL Server never writes directly into this tree.

.PARAMETER LocalDBsRoot
    Instance-local staging root. Resolved through Get-PVal from
    $global:Settings[$global:ConfigRootKeys['LocalDBsRootPathConfigRootKey']],
    canonically 'C:/LocalDBs'. Per-instance staging is
    <LocalDBsRoot>/<INSTANCE>/Backup/<Database>/. Throws if it cannot be resolved.

.PARAMETER BackupRoot
    Root folder under which per-database subdirectories are created.
    Default: <DatabaseBackupPublicationRoot>/<lowercase ComputerName>, so on UTAT022 this
    resolves to 'C:/Dropbox/Backups/utat022' and on UTAT01 to 'C:/Dropbox/Backups/utat01'
    with no per-host edit. All subdirectories in this tree sync offsite via Dropbox.

.PARAMETER TemporaryDirectory
    Staging directory to which the .bak file is written during the backup operation.
    Once the backup and verification are complete, the file is moved from this directory
    to the per-database subdirectory under BackupRoot.
    Writing first to a fast local temp drive (e.g. a RAM disk or NVMe scratch volume)
    reduces I/O contention on the Dropbox-synced backup destination.
    Default: <FastTempBasePath>\CobianReflectorBackup  (resolved from
    $global:Settings[$global:ConfigRootKeys['FastTempBasePathConfigRootKey']]).

.PARAMETER CompressBackup
    When specified, enables SQL Server native backup compression.
    Omit (default) for SQL Server Express Edition, which does not support compression.
    Standard and Enterprise editions support compression and benefit from smaller .bak files.
    Mutually exclusive with -SevenZipCompress.

.PARAMETER SevenZipCompress
    When specified, the uncompressed .bak written to the staging directory is compressed
    with 7-Zip (LZMA2, level 5) to produce a .bak.7z archive before it is moved to
    BackupRoot.  Use this on SQL Server Express Edition, which does not support native
    backup compression.  Requires 7z.exe to be in PATH or installed under
    'C:\Program Files\7-Zip\7z.exe'.
    Mutually exclusive with -CompressBackup.

.OUTPUTS
    [PSCustomObject] with properties:
        Success    [bool]     – $true on success, $false on failure
        BackupFile [string]   – full path of the .bak file written
        Duration   [timespan] – elapsed time for the backup operation
        SizeMB     [double]   – compressed size of the .bak file in megabytes (null on failure)
        Message    [string]   – human-readable result or error message

.EXAMPLE
    .\Invoke-SqlServerBackup.ps1 -DatabaseName 'ProGet' -BackupType 'Full'

    Performs a weekly full backup of the ProGet database to
    C:\Dropbox\Backups\utat022\ProGet\ProGet_FULL_20260327_020000.bak

.EXAMPLE
    .\Invoke-SqlServerBackup.ps1 -DatabaseName 'BuildMaster' -BackupType 'Differential'

    Performs a nightly differential backup of the BuildMaster database to
    C:\Dropbox\Backups\utat022\BuildMaster\BuildMaster_DIFF_20260327_030000.bak

.EXAMPLE
    .\Invoke-SqlServerBackup.ps1 -DatabaseName 'ProGet' -BackupType 'Full' -SevenZipCompress

    Performs a full backup of the ProGet database on SQL Server Express Edition.
    The raw .bak is written to the staging directory, compressed with 7-Zip (LZMA2,
    level 5), and the resulting archive is moved to the final destination:
    C:\Dropbox\Backups\utat022\ProGet\ProGet_FULL_20260402_020000.bak.7z

.EXAMPLE
    .\Invoke-SqlServerBackup.ps1 -DatabaseName 'BuildMaster' -BackupType 'Differential' -SevenZipCompress

    Performs a nightly differential backup of the BuildMaster database on Express Edition
    and compresses the result with 7-Zip:
    C:\Dropbox\Backups\utat022\BuildMaster\BuildMaster_DIFF_20260402_030000.bak.7z

.EXAMPLE
    .\Invoke-SqlServerBackup.ps1 -DatabaseName 'ProGet' -BackupType 'Full' -WhatIf

    Dry run — shows what would be backed up without executing.

.NOTES
    AI assisted using Powershell.instructions.md as guidelines

    Host:         utat022
    SQL instance: localhost\Production
    Requires:     dbaTools module (Install-Module dbaTools -Scope AllUsers)
    Run as:       An account with db_backupoperator (or db_owner) on the target database.
                  NetworkService works if UTAT022$ has the required SQL Server role.
    SC refs:      SC-0066 (application backups), SC-0067 (SQL database backups)
    See also:     _Planning Explainer 0021 — SQL Server Backup Jobs: ProGet and BuildMaster
                  _Planning Explainer 0022 — Backup & CI Database Evolution, Gaps, and Instructions

.LINK
    https://docs.dbatools.io/Backup-DbaDatabase
#>
function Invoke-SqlServerBackup {
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'CredentialsKey',
    Justification = 'CredentialsKey is a vault lookup key name, not a credential')]
  [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'ConnectionParts')]
  param(
    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [string] $DatabaseName,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParts')]
    [Alias('HostName', 'ServerInstance')]
    [string] $DatabaseHost,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParts')]
    [Alias('InstanceName')]
    [string] $SqlInstance = 'localhost\Production',

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParts')]
    [string] $ConnectionMethod,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParts')]
    [string] $CredentialsKey,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParts')]
    [string] $ApplicationName,

    [Parameter(Mandatory = $false, ParameterSetName = 'ConnectionParts')]
    [switch] $UseTrustedConnection,

    [Parameter(Mandatory = $false, ParameterSetName = 'ConnectionParts')]
    [Parameter(Mandatory = $false, ParameterSetName = 'DBConnectionStringSecretName')]
    [switch] $IntegratedSecurity,

    [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'SqlConnection')]
    [Microsoft.Data.SqlClient.SqlConnection] $SqlConnection,

    [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'DBConnectionStringSecretName')]
    [Alias('DBConnectionStringSecret', 'SecretName', 'BitwardenSecretName', 'BitwardenSecret')]
    [string] $DBConnectionStringSecretName,

    [Parameter()]
    [hashtable] $Settings,

    [Parameter()]
    [ValidateSet('Full', 'Differential')]
    [string] $BackupType = 'Full',

    # Host namespace for published backups. Defaults to the lowercase name of the
    # machine this runs on, so UTAT022 and UTAT01 each publish under their own subtree
    # without either host hardcoding the other's name.
    [Parameter()]
    [string] $ComputerName,

    # Off-host publication root. Resolved from
    # $global:Settings[$global:ConfigRootKeys['DatabaseBackupPublicationRootConfigRootKey']]
    # (canonically 'C:/Dropbox/Backups'). Never hardcoded.
    [Parameter()]
    [string] $DatabaseBackupPublicationRoot,

    # Instance-local root beneath which SQL Server writes backups. Resolved from
    # $global:Settings[$global:ConfigRootKeys['LocalDBsRootPathConfigRootKey']]
    # (canonically 'C:/LocalDBs'). Never hardcoded.
    [Parameter()]
    [string] $LocalDBsRoot,

    # Final per-database publication directory. Derived as
    # <DatabaseBackupPublicationRoot>/<lowercase ComputerName>/ when not supplied.
    [Parameter()]
    [string] $BackupRoot,

    [Parameter()]
    [string] $TemporaryDirectory,

    [Parameter()]
    [switch] $CompressBackup,

    [Parameter()]
    [switch] $SevenZipCompress

    # SCAFFOLD: multi-machine (Explainer 0022, section 4B)
    # The path half of this scaffold is implemented (Task 15.192): ComputerName,
    # DatabaseBackupPublicationRoot and LocalDBsRoot are resolved through Get-PVal from
    # $global:Settings/$global:ConfigRootKeys, so BackupRoot derives per host.
    # Still outstanding: add -ComputerName remote invocation via Invoke-Command (wrap the
    # PROCESS block body when ComputerName is not the local machine), and add
    # -Environment [ValidateSet('Production','QA','Integration','Development','Experimental')]
    # deriving $SqlInstance from the 5-tier settings rather than a raw string.
)

begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.IAC.BackupManagement'

    if ($CompressBackup.IsPresent -and $SevenZipCompress.IsPresent) {
        $msg = 'CompressBackup and SevenZipCompress are mutually exclusive.'
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
        throw $msg
    }

    # Check and populate BackupType parameter
    if ([string]::IsNullOrWhiteSpace($BackupType)) {
        $BackupType = 'Full'
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'BackupType not specified — defaulting to Full.'
    }

    # ------------------------------------------------------------------------
    # Path resolution (Task 15.192).
    # Every root below comes from $global:Settings keyed by $global:ConfigRootKeys and
    # is populated through Get-PVal. No filesystem root is hardcoded here, so the same
    # function runs unchanged on UTAT022, UTAT01, and any future host.
    # ------------------------------------------------------------------------
    $effectiveSettings = if ($PSBoundParameters.ContainsKey('Settings') -and $Settings) { $Settings } else { $global:Settings }

    # Host namespace for the publication subtree. Lowercased per the policy, which
    # requires backups from UTAT022 to land under .../utat022 and UTAT01 under .../utat01.
    $ComputerName = Get-PVal -ParameterName 'ComputerName' -originalPSBoundParameters $PSBoundParameters -DefaultValue $env:COMPUTERNAME -AllowMissing
    if ([string]::IsNullOrWhiteSpace($ComputerName)) { $ComputerName = $env:COMPUTERNAME }
    $ComputerName = $ComputerName.ToLowerInvariant()

    # Instance-local staging root, e.g. C:/LocalDBs. Per-instance staging is
    # <LocalDBsRoot>/<INSTANCE>/Backup/<Database>/ and SQL writes only beneath it.
    $localDBsRootKey = $global:ConfigRootKeys['LocalDBsRootPathConfigRootKey']
    $localDBsRootDefault = if ($localDBsRootKey -and $effectiveSettings -and $effectiveSettings.ContainsKey($localDBsRootKey)) { $effectiveSettings[$localDBsRootKey] } else { $null }
    $LocalDBsRoot = Get-PVal -ParameterName 'LocalDBsRoot' -originalPSBoundParameters $PSBoundParameters -DefaultValue $localDBsRootDefault -AllowMissing
    if ([string]::IsNullOrWhiteSpace($LocalDBsRoot)) {
        $msg = "LocalDBsRoot could not be resolved. Set the '$($global:ConfigRootKeys['LocalDBsRootPathConfigRootKey'])' host setting (ATAP.IAC Windows/HostSettings.ps1) or pass -LocalDBsRoot explicitly. Refusing to guess a filesystem root for database backups."
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
        throw $msg
    }

    # Off-host publication root, e.g. C:/Dropbox/Backups. SQL never writes here directly;
    # only the verified post-success publisher moves completed artifacts into it.
    $publicationRootKey = $global:ConfigRootKeys['DatabaseBackupPublicationRootConfigRootKey']
    $publicationRootDefault = if ($publicationRootKey -and $effectiveSettings -and $effectiveSettings.ContainsKey($publicationRootKey)) { $effectiveSettings[$publicationRootKey] } else { $null }
    $DatabaseBackupPublicationRoot = Get-PVal -ParameterName 'DatabaseBackupPublicationRoot' -originalPSBoundParameters $PSBoundParameters -DefaultValue $publicationRootDefault -AllowMissing
    if ([string]::IsNullOrWhiteSpace($DatabaseBackupPublicationRoot)) {
        $msg = "DatabaseBackupPublicationRoot could not be resolved. Set the '$($global:ConfigRootKeys['DatabaseBackupPublicationRootConfigRootKey'])' host setting (ATAP.IAC Windows/HostSettings.ps1) or pass -DatabaseBackupPublicationRoot explicitly. Refusing to guess a filesystem root for database backups."
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
        throw $msg
    }

    # BackupRoot is the per-host publication subtree unless the caller overrides it.
    $BackupRoot = Get-PVal -ParameterName 'BackupRoot' -originalPSBoundParameters $PSBoundParameters -DefaultValue (Join-Path $DatabaseBackupPublicationRoot $ComputerName) -AllowMissing
    if ([string]::IsNullOrWhiteSpace($BackupRoot)) {
        $BackupRoot = Join-Path $DatabaseBackupPublicationRoot $ComputerName
    }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Resolved LocalDBsRoot=[$LocalDBsRoot] DatabaseBackupPublicationRoot=[$DatabaseBackupPublicationRoot] ComputerName=[$ComputerName] BackupRoot=[$BackupRoot]."

    # Check and populate TemporaryDirectory parameter
    $fastTempKey = $global:ConfigRootKeys['FastTempBasePathConfigRootKey']
    $fastTempDefault = if ($fastTempKey -and $effectiveSettings -and $effectiveSettings.ContainsKey($fastTempKey)) { Join-Path $effectiveSettings[$fastTempKey] 'CobianReflectorBackup' } else { $null }
    $TemporaryDirectory = Get-PVal -ParameterName 'TemporaryDirectory' -originalPSBoundParameters $PSBoundParameters -DefaultValue $fastTempDefault -AllowMissing
    if ([string]::IsNullOrWhiteSpace($TemporaryDirectory)) {
        $msg = "TemporaryDirectory could not be resolved. Set the '$fastTempKey' host setting or pass -TemporaryDirectory explicitly."
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
        throw $msg
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Backup starting: [$BackupType] of [$DatabaseName] on [$SqlInstance] → [$BackupRoot] (via temp: [$TemporaryDirectory])."

    # Ensure dbaTools is available
    if (-not (Get-Module -Name 'dbatools' -ListAvailable)) {
        $msg = 'dbaTools module is not installed. Run: Install-Module dbaTools -Scope AllUsers'
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
        throw $msg
    }
    Import-Module dbatools -ErrorAction Stop

    if (-not (Get-Command -Name 'Resolve-DatabaseSqlConnection' -CommandType Function -ErrorAction SilentlyContinue)) {
        . (Join-Path $PSScriptRoot 'Resolve-DatabaseSqlConnection.ps1')
    }

    if ($PSCmdlet.ParameterSetName -eq 'ConnectionParts' -and [string]::IsNullOrWhiteSpace($DatabaseHost) -and -not [string]::IsNullOrWhiteSpace($SqlInstance)) {
        $instanceParts = $SqlInstance -split '\\', 2
        $DatabaseHost = $instanceParts[0]
        if ($instanceParts.Count -gt 1) {
            $SqlInstance = $instanceParts[1]
        } else {
            $SqlInstance = $null
        }
    }

    # The split above is authoritative, so the resolver must be handed a COPY of the bound
    # parameters with the raw -SqlInstance removed. Resolve-DatabaseSqlConnection declares
    # [Alias('SqlInstance')] on its -InstanceName parameter and, when -InstanceName arrives
    # empty, re-reads the caller's original bound value through that alias. That silently
    # undoes the split and composes DataSource as "<host>\<original>", e.g.
    #   -SqlInstance 'localhost,50020'   -> 'localhost,50020\localhost,50020'
    #   -SqlInstance 'localhost\PRODUCTION' -> 'localhost\localhost\PRODUCTION'
    # The first still opens because SqlClient honours the ,port and ignores the bogus
    # instance; the second does not resolve at all. Verified 2026-09-10 (Task 15.192.f).
    $resolverBoundParameters = @{}
    foreach ($key in $PSBoundParameters.Keys) { $resolverBoundParameters[$key] = $PSBoundParameters[$key] }
    foreach ($stale in @('SqlInstance', 'InstanceName', 'DatabaseHost')) {
        if ($resolverBoundParameters.ContainsKey($stale)) { [void]$resolverBoundParameters.Remove($stale) }
    }
    if (-not [string]::IsNullOrWhiteSpace($SqlInstance)) { $resolverBoundParameters['InstanceName'] = $SqlInstance }
    if (-not [string]::IsNullOrWhiteSpace($DatabaseHost)) { $resolverBoundParameters['DatabaseHost'] = $DatabaseHost }

    $resolution = Resolve-DatabaseSqlConnection `
        -OriginalPSBoundParameters $resolverBoundParameters `
        -SqlConnection $SqlConnection `
        -DBConnectionStringSecretName $DBConnectionStringSecretName `
        -DatabaseHost $DatabaseHost `
        -InstanceName $SqlInstance `
        -DatabaseName $DatabaseName `
        -ConnectionMethod $ConnectionMethod `
        -CredentialsKey $CredentialsKey `
        -ApplicationName $ApplicationName `
        -UseTrustedConnection:$UseTrustedConnection `
        -IntegratedSecurity:$IntegratedSecurity `
        -Settings $Settings

    $resolvedSqlConnection = $resolution.Connection
    $resolvedConnectionOwnedByFunction = -not [bool]$resolution.IsCallerOwned

    $resolvedConnectionStringBuilder = [Microsoft.Data.SqlClient.SqlConnectionStringBuilder]::new($resolvedSqlConnection.ConnectionString)
    $SqlInstance = $resolvedConnectionStringBuilder.DataSource
    if ([string]::IsNullOrWhiteSpace($DatabaseName)) {
        $DatabaseName = if (-not [string]::IsNullOrWhiteSpace($resolvedConnectionStringBuilder.InitialCatalog)) {
            $resolvedConnectionStringBuilder.InitialCatalog
        } else {
            $resolvedSqlConnection.Database
        }
    }

    if ([string]::IsNullOrWhiteSpace($DatabaseName)) {
        $msg = 'DatabaseName is required, either as a parameter or as Initial Catalog in the resolved connection string.'
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
        throw $msg
    }

    # Locate 7-Zip when requested
    if ($SevenZipCompress.IsPresent) {
        $sevenZipExe = (Get-Command '7z' -ErrorAction SilentlyContinue)?.Source
        if (-not $sevenZipExe) {
            $sevenZipExe = 'C:\Program Files\7-Zip\7z.exe'
        }
        if (-not (Test-Path $sevenZipExe)) {
            $msg = '7-Zip executable not found. Install from https://www.7-zip.org or ensure 7z.exe is in PATH.'
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
            throw $msg
        }
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "7-Zip found: $sevenZipExe"
    }

    # SCAFFOLD: dbatools-config (Explainer 0022, section 4B / inconsistency C-04)
    # ATAP.Utilities database scripts set these before every dbaTools call; this script does not.
    # Add:
    #   Set-DbatoolsConfig -FullName 'sql.connection.trustcert' -Value $true
    #   Set-DbatoolsConfig -FullName 'sql.connection.encrypt'   -Value $false
    # or make them parameters so callers can control TLS policy per environment.

    # Build per-database backup subdirectory (final destination)
    $backupDir = Join-Path $BackupRoot $DatabaseName
    if (-not (Test-Path $backupDir)) {
        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Created backup directory: $backupDir"
    }

    # Build per-database temp staging subdirectory
    $tempDir = Join-Path $TemporaryDirectory $DatabaseName
    if (-not (Test-Path $tempDir)) {
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Created temp staging directory: $tempDir"
    }

    $timestamp = (Get-Date).ToString('yyyyMMdd_HHmmss')
    $typeCode = if ($BackupType -eq 'Full') { 'FULL' } else { 'DIFF' }
    $backupFileName = "${DatabaseName}_${typeCode}_${timestamp}.bak"
    $tempFilePath = Join-Path $tempDir $backupFileName
    # Final file in the backup directory: .bak.7z when using 7-Zip, .bak otherwise
    $finalFileName = if ($SevenZipCompress.IsPresent) { "$backupFileName.7z" } else { $backupFileName }
    $backupFilePath = Join-Path $backupDir $finalFileName

    $startTime = Get-Date
}

process {
    try {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Initiating $BackupType backup → $tempFilePath (staging), then → $backupFilePath"

        $backupParams = @{
            SqlInstance     = $SqlInstance
            Database        = $DatabaseName
            Path            = $tempDir
            FilePath        = $backupFileName
            Type            = $BackupType
            CompressBackup  = $CompressBackup.IsPresent
            Verify          = $true
            EnableException = $true
        }

        if ($PSCmdlet.ShouldProcess("$SqlInstance / $DatabaseName", "$BackupType backup to $tempFilePath then move to $backupFilePath")) {
            $result = Backup-DbaDatabase @backupParams
            $duration = (Get-Date) - $startTime

            # Backup-DbaDatabase does not throw when no database matches; it returns null/empty
            # and emits a warning. Detect this and surface a clear error.
            if (-not $result) {
                throw "Database '$DatabaseName' was not found on [$SqlInstance] or no databases matched the backup request. Verify the database name and that the SQL Server instance is reachable."
            }

            # Verify the .bak file was actually written to the staging directory
            if (-not (Test-Path $tempFilePath)) {
                throw "Backup-DbaDatabase reported success but the expected staging file was not created: $tempFilePath"
            }

            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Backup written to temp in $($duration.TotalSeconds.ToString('F1'))s — $tempFilePath"

            if ($SevenZipCompress.IsPresent) {
                # Compress to .bak.7z in the temp directory, then discard the raw .bak
                $tempZipPath = "$tempFilePath.7z"
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Compressing with 7-Zip: $tempFilePath → $tempZipPath"
                & $sevenZipExe a -mx=5 "$tempZipPath" "$tempFilePath" | Out-Null
                if ($LASTEXITCODE -ne 0) {
                    throw "7-Zip compression failed (exit $LASTEXITCODE) for: $tempFilePath"
                }
                Remove-Item -Path $tempFilePath -Force -ErrorAction Stop
                Move-Item -Path $tempZipPath -Destination $backupFilePath -Force -ErrorAction Stop
            } else {
                Move-Item -Path $tempFilePath -Destination $backupFilePath -Force -ErrorAction Stop
            }
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Backup at final destination: $backupFilePath"

            # Measure the actual file that landed in the backup directory
            $sizeMB = [math]::Round((Get-Item $backupFilePath).Length / 1MB, 2)

            # SCAFFOLD: retention (Explainer 0022, section 4F)
            # After a successful Full backup, invoke Invoke-BackupPrune.ps1 (to be written)
            # to delete .bak files older than -FullRetentionDays (default 90) and
            # differential files older than -DiffRetentionDays (default 14).
            # Example call (uncomment when Invoke-BackupPrune.ps1 exists):
            # if ($BackupType -eq 'Full') {
            #     & (Join-Path $PSScriptRoot 'Invoke-BackupPrune.ps1') `
            #         -BackupRoot $BackupRoot -DatabaseName $DatabaseName `
            #         -FullRetentionDays 90 -DiffRetentionDays 14
            # }

            # SCAFFOLD: test-data (Explainer 0022, section 4D)
            # Production backup (this script) is NOT the mechanism for test data management.
            # Test database provisioning (seed / reset / teardown) belongs in
            # Invoke-TestDatabaseProvision.ps1 (to be written) in this same directory.
            # That script restores a named golden-image .bak, optionally runs Flyway migrate,
            # and returns a connection string for the CI test run.

            [PSCustomObject]@{
                Success    = $true
                BackupFile = $backupFilePath
                Duration   = $duration
                SizeMB     = $sizeMB
                Message    = 'Backup completed successfully.'
            }
        }
    } catch {
        $errMsg = "Backup FAILED for [$DatabaseName] on [$SqlInstance]: $_"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errMsg

        [PSCustomObject]@{
            Success    = $false
            BackupFile = 'N/A NOT CREATED'
            Duration   = (Get-Date) - $startTime
            SizeMB     = $null
            Message    = $errMsg
        }
        throw
    } finally {
        if ($resolvedConnectionOwnedByFunction -and $null -ne $resolvedSqlConnection) {
            $resolvedSqlConnection.Dispose()
        }
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Invoke-SqlServerBackup finished for [$DatabaseName] ($BackupType)."
    }
}
}
