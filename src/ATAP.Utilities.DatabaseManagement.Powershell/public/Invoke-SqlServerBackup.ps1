<#
.SYNOPSIS
    Performs a SQL Server backup of a specified database to the standard backup location.

.DESCRIPTION
    Backs up a SQL Server database on localhost\Production to
    C:\Dropbox\Backups\utat022\<DatabaseName>\.
    Supports Full and Differential backup types.
    Uses dbaTools for reliable SQL Server backup operations with built-in verification.
    Intended to be called from Cobian Backup jobs on utat022.

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

.PARAMETER BackupRoot
    Root folder under which per-database subdirectories are created.
    Default: 'C:\Dropbox\Backups\utat022'.
    All subdirectories in this tree are backed up automatically via Dropbox sync.

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
    [Parameter(Mandatory = $false, ParameterSetName = 'BitwardenSecretName')]
    [switch] $IntegratedSecurity,

    [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'SqlConnection')]
    [Microsoft.Data.SqlClient.SqlConnection] $SqlConnection,

    [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'BitwardenSecretName')]
    [Alias('BitwardenSecret', 'SecretName')]
    [string] $BitwardenSecretName,

    [Parameter()]
    [hashtable] $Settings,

    [Parameter()]
    [ValidateSet('Full', 'Differential')]
    [string] $BackupType = 'Full',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $BackupRoot = 'C:\Dropbox\Backups\utat022',

    [Parameter()]
    [string] $TemporaryDirectory = $(Join-Path $global:Settings[$global:ConfigRootKeys['FastTempBasePathConfigRootKey']] 'CobianReflectorBackup'),

    [Parameter()]
    [switch] $CompressBackup,

    [Parameter()]
    [switch] $SevenZipCompress

    # SCAFFOLD: multi-machine (Explainer 0022, section 4B)
    # Add -ComputerName [string] parameter (default: 'localhost') to support remote invocation
    # via Invoke-Command. When ComputerName != localhost, wrap PROCESS block body in
    # Invoke-Command -ComputerName $ComputerName -ScriptBlock { ... }.
    # Also add -Environment [ValidateSet('Experimental','Development','Testing','Production')]
    # and derive $SqlInstance from $global:settings[$global:configRootKeys['Database{Env}InstanceConfigRootKey']]
    # instead of accepting it as a raw string. BackupRoot default should then resolve to
    # "C:\Dropbox\Backups\$ComputerName" dynamically.
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

    # Check and populate BackupRoot parameter
    if ([string]::IsNullOrWhiteSpace($BackupRoot)) {
        $BackupRoot = 'C:\Dropbox\Backups\utat022'
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'BackupRoot not specified — defaulting to C:\Dropbox\Backups\utat022.'
    }

    # Check and populate TemporaryDirectory parameter
    if ([string]::IsNullOrWhiteSpace($TemporaryDirectory)) {
        $TemporaryDirectory = Join-Path $global:Settings[$global:ConfigRootKeys['FastTempBasePathConfigRootKey']] 'CobianReflectorBackup'
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "TemporaryDirectory not specified — defaulting to $TemporaryDirectory."
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

    $resolvedSqlConnection = Resolve-DatabaseSqlConnection `
        -OriginalPSBoundParameters $PSBoundParameters `
        -SqlConnection $SqlConnection `
        -BitwardenSecretName $BitwardenSecretName `
        -DatabaseHost $DatabaseHost `
        -InstanceName $SqlInstance `
        -DatabaseName $DatabaseName `
        -ConnectionMethod $ConnectionMethod `
        -CredentialsKey $CredentialsKey `
        -ApplicationName $ApplicationName `
        -UseTrustedConnection:$UseTrustedConnection `
        -IntegratedSecurity:$IntegratedSecurity `
        -Settings $Settings

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

    $resolvedConnectionOwnedByFunction = $PSCmdlet.ParameterSetName -ne 'SqlConnection'

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
