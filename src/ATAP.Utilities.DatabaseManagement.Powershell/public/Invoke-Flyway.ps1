function Invoke-Flyway {
  <#
  .SYNOPSIS
  Generates Flyway manifest placeholder environment variables, then runs flyway $FlywayCommand.

  .DESCRIPTION
  Computes SHA256 hashes for specified migration/repeatable SQL files under -SqlDir, builds a comma‑separated
  (VALUES …) list for insertion (ManifestValues), and exports these plus package / git metadata into environment
  variables using Flyway's placeholder naming convention (FLYWAY_PLACEHOLDERS_*). After exporting, it invokes
  'flyway $FlywayCommand'

  Exported environment variables:
    FLYWAY_PLACEHOLDERS_MANIFESTVALUES
    FLYWAY_PLACEHOLDERS_PACKAGENAME
    FLYWAY_PLACEHOLDERS_PACKAGEVERSION
    FLYWAY_PLACEHOLDERS_GITTAG
    FLYWAY_PLACEHOLDERS_GITCOMMIT
    FLYWAY_PROD_BUILDSETS_USER
    FLYWAY_PROD_BUILDSETS_PWD

  .PARAMETER SqlDir
  Directory containing Flyway SQL scripts (default .\sql).

  .PARAMETER Files
  File names (relative to -SqlDir) to include in the manifest values list.

  .PARAMETER LoginName
  The SQL/Login name to create or ensure (passed to the CreateBuildSetsLoginAndUser.sql script via sqlcmd variables).

  .PARAMETER LoginPasswordEnvVar
  Name of the environment variable holding the password for the login. Its value is injected via the sqlcmd variable $(BuildSetsloginPassword).

  .PARAMETER PackageName
  Logical package/component name.

  .PARAMETER PackageVersion
  Version string for the package.

  .PARAMETER ConfigPath
  Path to flyway.conf (used for flyway -configFiles argument only; not parsed here).

  .PARAMETER GitTag
  Optional explicit Git tag (otherwise discovered).

  .PARAMETER GitCommit
  Optional explicit Git commit (otherwise discovered).

  .PARAMETER FlywayPath
  Executable or path for the flyway CLI (default 'flyway').

  .PARAMETER FlywayAdditionalArgs
  Additional raw arguments passed to flyway before the 'FlywayCommand' verb (e.g. '-X').

  .OUTPUTS
  PSCustomObject summarizing placeholders and (optionally) flyway execution result.

  .EXAMPLE
  Invoke-Flyway -PackageName BuildSets.Functions -PackageVersion 0.0.00008 -Files (Get-ChildItem .\sql -Filter 'V*__*.sql').Name

  .EXAMPLE
  Invoke-Flyway -PackageName BuildSets.Functions -PackageVersion 0.0.00008 -Files V00.01.000010__Init.sql

  .NOTES
  AI assisted using Powershell.instructions.md as guidelines
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
  param(
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$DatabaseName,

    [Parameter(Mandatory = $true, Position = 1, ValueFromPipelineByPropertyName = $true)]
    [ValidateSet('Production', 'Testing', 'Development', 'Experimental')]
    [string]$Environment,

    [Parameter(Mandatory = $false)]
    [string]$DatabaseHost,

    [Parameter(Mandatory = $false)]
    [ValidateSet('tcp', 'np', 'lpc')]
    [string]$ConnectionMethod,

    [Parameter(Mandatory = $false)]
    [ValidateSet('Production', 'Testing', 'Development', 'SQLEXPRESS')]
    [string]$SqlInstance,

    [Parameter(Mandatory = $false)]
    [bool]$UseNamedLogin = $false,

    [Parameter(Mandatory = $false)]
    [string]$LoginName ,

    [Parameter(Mandatory = $false)]
    #[Securestring]$LoginPasswordVaultKey,
    [string]$LoginPasswordVaultKey,

    # Flyway command selector
    [Parameter(Mandatory = $false)]
    [ValidateSet('validate', 'migrate', 'check -dryrun')]
    [string]$FlywayCommand = 'validate',
    [Parameter(Mandatory = $false)]
    [string]$SqlDir = '.\sql',
    [Parameter(Mandatory = $false)]
    [string[]]$Files,
    [Parameter(Mandatory = $false)]
    [string]$PackageName,
    [Parameter(Mandatory = $false)]
    [string]$PackageVersion,

    [string]$ConfigPath = '.\flyway.toml',
    [string]$GitTag,
    [string]$GitCommit,
    [string]$FlywayPath = 'flyway',
    [string[]]$FlywayAdditionalArgs
  )

  BEGIN {
    Write-PSFMessage -FunctionName 'Invoke-Flyway' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level Debug -Message 'Entering function Invoke-Flyway'
    $script:errors = [System.Collections.Generic.List[string]]::new()
    $script:success = $false

    function Get-Env([string]$key) {
      [Environment]::GetEnvironmentVariable($key, 'Process')
    }

    function Test-Blank([string]$s) { [string]::IsNullOrWhiteSpace($s) }

    function Resolve-FromSettings([string]$db, [string]$env, [string]$leafKey) {
      if ($settings.ContainsKey($global:configRootKeys['DatabasesCollectionConfigRootKey'])) {
        $root = $settings[$global:configRootKeys['DatabasesCollectionConfigRootKey']]
        if ($root.ContainsKey($db) -and $root[$db].ContainsKey($env) -and $root[$db][$env].ContainsKey($leafKey)) {
          $val = $root[$db][$env][$leafKey]
          if (-not (Test-Blank $val)) { return $val }
        }
      }
      return $null
    }

    function Test-WindowsLoginName {
      param([string]$Name)
      return ($Name -match '[\\@]')
    }

    function Get-GitMeta {
      param([string]$StartDir)
      $git = Get-Command git -ErrorAction SilentlyContinue
      if (-not $git) { return @{ Tag = '(no-git)'; Commit = '(no-git)' } }
      $tag = $null; try { $tag = (git -C $StartDir describe --tags --abbrev=0 2>$null).Trim() } catch {}
      if (-not $tag) { $tag = '(untagged)' }
      $commit = (git -C $StartDir rev-parse --short HEAD 2>$null).Trim(); if (-not $commit) { $commit = '(no-commit)' }
      @{ Tag = $tag; Commit = $commit }
    }

    # --- Environment: param -> env -> $global:settings[$global:configRootKeys['EnvironmentConfigRootKey']] -> throw
    if (Test-Blank $Environment) {
      # Try environment variable first (e.g., via a configured key like 'EnvironmentConfigRootKey')
      $envVal = Get-Env $global:configRootKeys['EnvironmentConfigRootKey']
      if (Test-Blank $envVal) {
        # Then try global settings at the top level: $global:settings[$global:configRootKeys['EnvironmentConfigRootKey']]
        $setVal = $null
        if ($null -ne $global:settings -and $global:settings.ContainsKey($global:configRootKeys['EnvironmentConfigRootKey'])) {
          $setVal = $global:settings[$global:configRootKeys['EnvironmentConfigRootKey']]
        }

        if (Test-Blank $setVal) {
          $errorMessage = "Environment not found via parameter, env '$($global:configRootKeys['EnvironmentConfigRootKey'])', or global settings['Environment']."
          Write-PSFMessage -FunctionName 'Invoke-Flyway' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level Error -Message $errorMessage -Tag 'Validation', 'Error'
          throw $errorMessage
        }
        else {
          $Environment = $setVal
        }
      }
      else {
        $Environment = $envVal
      }
    }
    # Normalize to one of the allowed values (case-insensitive) and hard-validate
    # ToDO: convert to an enum,
    $allowedEnvs = 'Production', 'Testing', 'Development', 'Experimental'
    $match = $allowedEnvs | Where-Object { $_.ToLowerInvariant() -eq $Environment.ToString().ToLowerInvariant() }

    if ($null -ne $match) {
      # Snap to canonical casing from $allowedEnvs
      $Environment = $match
    }
    else {
      $errorMessage = "Environment '$Environment' must be one of: $($allowedEnvs -join ', ')."
      Write-PSFMessage -FunctionName 'Invoke-Flyway' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level Error -Message $errorMessage -Tag 'Validation', 'Error'
      throw $errorMessage
    }

    # --- DatabaseHost: param -> env -> settings -> throw
    if (Test-Blank $DatabaseHost) {
      $dbh = 'Database' + $DatabaseName + $Environment + 'DatabaseHostConfigRootKey'
      $envVal = Get-Env $global:configRootKeys[$dbh]
      if (Test-Blank $envVal) {
        $setVal = Resolve-FromSettings -db $DatabaseName -env $Environment -leafKey 'DatabaseHost'
        if (Test-Blank $setVal) {
          $errorMessage = "DatabaseHost not found via parameter, env '$($global:configRootKeys[$dbh])', or settings for '$DatabaseName'/'$Environment'."
          Write-PSFMessage -FunctionName 'Invoke-Flyway' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level Error -Message $errorMessage -Tag 'Validation', 'Error'
          throw $errorMessage
        }
        else { $DatabaseHost = $setVal }
      }
      else { $DatabaseHost = $envVal }
    }

    # --- ConnectionMethod: param -> env -> settings -> throw
    if (Test-Blank $ConnectionMethod) {
      $envVal = Get-Env $global:configRootKeys['ConnectionMethodConfigRootKey']
      if (Test-Blank $envVal) {
        $setVal = Resolve-FromSettings -db $DatabaseName -env $Environment -leafKey 'ConnectionMethod'
        if (Test-Blank $setVal) {
          $errorMessage = "ConnectionMethod not found via parameter, env '$($global:configRootKeys['ConnectionMethodConfigRootKey'])', or settings for '$DatabaseName'/'$Environment'."
          Write-PSFMessage -FunctionName 'Invoke-Flyway' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level Error -Message $errorMessage -Tag 'Validation', 'Error'
          throw $errorMessage
        }
        else { $ConnectionMethod = $setVal }
      }
      else { $ConnectionMethod = $envVal }
    }

    # Normalize and hard-validate (defensive; complements [ValidateSet()])
    $ConnectionMethod = $ConnectionMethod.ToString().ToLowerInvariant()
    if ('tcp', 'np', 'lpc' -notcontains $ConnectionMethod) {
      $errorMessage = "ConnectionMethod '$ConnectionMethod' must be one of: tcp, np, lpc."
      Write-PSFMessage -FunctionName 'Invoke-Flyway' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level Error -Message $errorMessage -Tag 'Validation', 'Error'
      throw $errorMessage
    }

    # --- SqlInstance: param -> env -> settings -> throw
    if (Test-Blank $SqlInstance) {
      $envVal = Get-Env $global:configRootKeys['SqlInstanceConfigRootKey']
      if (Test-Blank $envVal) {
        $setVal = Resolve-FromSettings -db $DatabaseName -env $Environment -leafKey 'SqlInstance'
        if (Test-Blank $setVal) {
          $errorMessage = "SqlInstance not found via parameter, env '$($global:configRootKeys['SqlInstanceConfigRootKey'])', or settings for '$DatabaseName'/'$Environment'."
          Write-PSFMessage -FunctionName 'Invoke-Flyway' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level Error -Message $errorMessage -Tag 'Validation', 'Error'
          throw $errorMessage
        }
        else { $SqlInstance = $setVal }
      }
      else { $SqlInstance = $envVal }
    }

    try {
      if ([string]::IsNullOrWhiteSpace($SqlDir)) { throw 'SqlDir is null or empty.' }
      if (-not (Test-Path -Path $SqlDir)) { throw "SqlDir not found: $SqlDir" }
    }
    catch {
      $msg = "SqlDir validation failed. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName 'Invoke-Flyway' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level Error -Message $msg -Tag 'Validation', 'Error'
      $script:errors.Add($msg) | Out-Null; throw
    }

    if ($UseNamedLogin) {
      # LoginName: param -> env -> settings -> throw
      if (Test-Blank $LoginName) {
        $envVal = Get-Env $global:configRootKeys['LoginNameConfigRootKey']
        if (Test-Blank $envVal) {
          $setVal = Resolve-FromSettings -db $DatabaseName -env $Environment -leafKey 'LoginName'
          if (Test-Blank $setVal) {
            $errorMessage = "UseNamedLogin is true but LoginName is not provided and was not found via env '$($global:configRootKeys['LoginNameConfigRootKey'])' or settings."
            Write-PSFMessage -FunctionName 'Invoke-Flyway' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level Error -Message $errorMessage -Tag 'Validation', 'Error'
            throw $errorMessage
          }
          else { $LoginName = $setVal }
        }
        else { $LoginName = $envVal }
      }

      # If SQL login, require LoginPasswordVaultKey; if Windows login, it's optional/ignored
      if (-not (Is-WindowsLoginName $LoginName)) {
        if (Test-Blank $LoginPasswordVaultKey) {
          $envVal = Get-Env $global:configRootKeys['LoginPasswordVaultKeyConfigRootKey']
          if (Test-Blank $envVal) {
            $setVal = Resolve-FromSettings -db $DatabaseName -env $Environment -leafKey $global:configRootKeys['LoginPasswordVaultKeyConfigRootKey']
            if (Test-Blank $setVal) {
              $errorMessage = "UseNamedLogin is true and LoginName '$LoginName' appears to be a SQL login, but LoginPasswordVaultKey was not provided and was not found via env '$($global:configRootKeys['LoginPasswordVaultKeyConfigRootKey'])' or settings."
              Write-PSFMessage -FunctionName 'Invoke-Flyway' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level Error -Message $errorMessage -Tag 'Validation', 'Error'
              throw $errorMessage
            }
            else { $LoginPasswordVaultKey = $setVal }
          }
          else { $LoginPasswordVaultKey = $envVal }
        }
      }
      else {
        Write-PSFMessage -FunctionName 'Invoke-Flyway' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level Verbose -Message "LoginName '$LoginName' detected as Windows principal; LoginPasswordVaultKey not required."
      }

      # Lookup LoginPassword (temporary clear text lookup)
      # [SecureString]$loginPassword = $null
      [string]$loginPassword = $null
      if (-not $global:VaultData.ContainsKey($LoginPasswordVaultKey)) {
        $errorMessage = "LoginPasswordVaultKey '$LoginPasswordVaultKey' not found in vault."
        Write-PSFMessage -FunctionName 'Invoke-Flyway' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level Error -Message $errorMessage -Tag 'Validation', 'Error'
        throw $errorMessage
      }
      else {
        if (-not (Test-Blank $global:VaultData[$LoginPasswordVaultKey])) {
          # [SecureString]$loginPassword = $global:VaultData[$LoginPasswordVaultKey]
          $loginPassword = $global:VaultData[$LoginPasswordVaultKey]
        }
        else {
          $errorMessage = "LoginPasswordVaultKey '$LoginPasswordVaultKey' has blank value in vault."
          Write-PSFMessage -FunctionName 'Invoke-Flyway' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level Error -Message $errorMessage -Tag 'Validation', 'Error'
          throw $errorMessage
        }
      }
      else {
        # If $UseNamedLogin is false, then LoginName and LoginPasswordVaultKey should not be present
        $LoginName = $null
        $LoginPasswordVaultKey = $null
      }
    }
    # ParameterValidation snippet (templated) for ConfigPath
    try {
      if ([string]::IsNullOrWhiteSpace($ConfigPath)) { throw 'ConfigPath is null or empty.' }
      if (-not (Test-Path -Path $ConfigPath)) { throw "ConfigPath not found: $ConfigPath" }
    }
    catch {
      $msg = "ConfigPath validation failed. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName 'Invoke-Flyway' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level Error -Message $msg -Tag 'Validation', 'Error'
      $script:errors.Add($msg) | Out-Null; throw
    }

    # ParameterValidation snippet (templated) for PackageName
    try {
      if ([string]::IsNullOrWhiteSpace($PackageName)) { throw 'PackageName is null or empty.' }
    }
    catch {
      $msg = "PackageName validation failed. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName 'Invoke-Flyway' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level Error -Message $msg -Tag 'Validation', 'Error'
      $script:errors.Add($msg) | Out-Null; throw
    }

    # ParameterValidation snippet (templated) for PackageVersion
    try {
      if ([string]::IsNullOrWhiteSpace($PackageVersion)) { throw 'PackageVersion is null or empty.' }
    }
    catch {
      $msg = "PackageVersion validation failed. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName 'Invoke-Flyway' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level Error -Message $msg -Tag 'Validation', 'Error'
      $script:errors.Add($msg) | Out-Null; throw
    }

    # Git metadata
    try {
      $gitMeta = Get-GitMeta -StartDir (Resolve-Path .)
      if (-not $GitTag) { $GitTag = $gitMeta.Tag }
      if (-not $GitCommit) { $GitCommit = $gitMeta.Commit }
    }
    catch {
      $msg = "Failed obtaining git metadata. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName 'Invoke-Flyway' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level Warning -Message $msg
      $script:errors.Add($msg) | Out-Null
    }

    # Build manifest values list
    $values = @()
    try {
      foreach ($name in $Files) {
        $full = Join-Path $SqlDir $name
        if (-not (Test-Path $full)) { throw "File not found: $full" }
        $sha = (Get-FileHash -Path $full -Algorithm SHA256).Hash.ToLower()
        $type = if ($name -like 'R__*') { 'R' } elseif ($name -like 'V*__*') { 'V' } else { 'R' }
        $fileNameSql = ($name -replace "'", "''")
        $values += "(N'$fileNameSql', '$type', N'$sha')"
      }
    }
    catch {
      $msg = "Failed hashing files. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName 'Invoke-Flyway' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level Error -Message $msg
      $script:errors.Add($msg) | Out-Null
      throw
    }
    $valuesList = ($values -join ',')

    # Decide authentication mode and set env for Flyway/JDBC
    $isIntegrated = $false
    $flywayUser = ''
    $flywayPwd = ''

    if (-not $UseNamedLogin) {
      # Always integrated when not using a named SQL login
      $isIntegrated = $true
    }
    else {
      if (Test-WindowsLoginName $LoginName) {
        # Windows principal: integrated auth (Flyway uses the current process identity)
        $isIntegrated = $true
      }
      else {
        # SQL-auth login
        $isIntegrated = $false
        $flywayUser = $LoginName
        $flywayPwd = $loginPassword   # from your vault lookup
      }
    }

    # TLS defaults (adjust to your policy)
    $env:FLYWAY_ENCRYPT = 'false'
    $env:FLYWAY_TRUSTSERVERCERT = 'true'
    $env:FLYWAY_INTEGRATED = $(if ($isIntegrated) { 'true' } else { 'false' })
    $env:FLYWAY_DB_USER = $flywayUser
    $env:FLYWAY_DB_PASSWORD = $flywayPwd
  }

  PROCESS {
    # Export environment variables (Flyway placeholder form)
    Write-PSFMessage -FunctionName 'Invoke-Flyway' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level Debug -Message 'Exporting Flyway placeholder environment variables'
    $env:FLYWAY_PLACEHOLDERS_MANIFESTVALUES = $valuesList
    $env:FLYWAY_PLACEHOLDERS_PACKAGENAME = $PackageName
    $env:FLYWAY_PLACEHOLDERS_PACKAGEVERSION = $PackageVersion
    $env:FLYWAY_PLACEHOLDERS_GITTAG = $GitTag
    $env:FLYWAY_PLACEHOLDERS_GITCOMMIT = $GitCommit
    #$env:FLYWAY_PROD_BUILDSETS_USER = $LoginName
    # Lookup LoginPassword (temporary clear text lookup) with new key order
    [string]$loginPassword = ''
    if (-not [string]::IsNullOrWhiteSpace($global:VaultData.ContainsKey($LoginPasswordVaultKey))) {
      # [SecureString]$loginPassword = $global:VaultData[$LoginPasswordVaultKey]
      $loginPassword = $global:VaultData[$LoginPasswordVaultKey]
    }
    else {
      $errorMessage = "LoginPasswordVaultKey '$LoginPasswordVaultKey' not found in vault."
      Write-PSFMessage -FunctionName 'Invoke-Flyway' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level Error -Message $errorMessage -Tag 'Validation', 'Error'
      throw $errorMessage
    }

    Write-PSFMessage -FunctionName 'Invoke-Flyway' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level Important -Message "Prepared placeholders for Package=$PackageName Version=$PackageVersion Tag=$GitTag Commit=$GitCommit Files=$($Files.Count)"

    $message = (Get-ChildItem Env: | Where-Object { $_.Name -notlike 'Path' -and ($_.Name -like '*flyway*' -or $_.Value -like '*flyway*') } | Format-Table Name, Value ) -join "`r`n"

    Write-PSFMessage -FunctionName 'Invoke-Flyway' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level Important -Message $message

    $flywayParams = @("-configFiles=$ConfigPath", "-environment=$Environment")
    if ($FlywayAdditionalArgs) { $flywayParams += $FlywayAdditionalArgs }
    $flywayParams += $FlywayCommand

    if ($PSCmdlet.ShouldProcess($ConfigPath, "flyway $FlywayCommand [$Environment]")) {
      try {
        Write-PSFMessage -FunctionName 'Invoke-Flyway' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level Debug -Message "Calling flyway with args: $($flywayParams -join ' ')"
        & $FlywayPath @flywayParams
        $exit = $LASTEXITCODE
        if ($exit -ne 0) { throw "flyway exited with code $exit" }
        Write-PSFMessage -FunctionName 'Invoke-Flyway' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level Debug -Message "Successfully returned from flyway $FlywayCommand"
        $script:success = $true
      }
      catch {
        $msg = "flyway $FlywayCommand failed. Exception: $($_.Exception.Message)"
        Write-PSFMessage -FunctionName 'Invoke-Flyway' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level Error -Message $msg
        if ($_.Exception.StackTrace) { Write-PSFMessage -FunctionName 'Invoke-Flyway' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level Debug -Message "StackTrace: $($_.Exception.StackTrace)" }
        $script:errors.Add($msg) | Out-Null
        throw
      }
      finally {
        Write-PSFMessage -FunctionName 'Invoke-Flyway' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level Debug -Message "Finished flyway $FlywayCommand attempt"
      }
    }
  }

  END {
    $summary = [PSCustomObject]@{
      PackageName    = $PackageName
      PackageVersion = $PackageVersion
      GitTag         = $GitTag
      GitCommit      = $GitCommit
      FileCount      = $Files.Count
      ManifestValues = $env:FLYWAY_PLACEHOLDERS_MANIFESTVALUES
      FlywayCommand  = $FlywayCommand
      Success        = ($script:errors.Count -eq 0 -and $script:success)
      Errors         = $script:errors.ToArray()
      TimestampUTC   = (Get-Date).ToUniversalTime()
    }
    $level = if ($summary.Success) { 'Important' } else { 'Error' }
    Write-PSFMessage -FunctionName 'Invoke-Flyway' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level $level -Message ("Manifest variables generation {0}" -f ($(if ($summary.Success) { 'succeeded' } else { 'failed' })))
    if (-not $summary.Success) { Write-PSFMessage -FunctionName 'Invoke-Flyway' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level Error -Message ("Errors:`n" + ($summary.Errors -join [Environment]::NewLine)) }
    Write-PSFMessage -FunctionName 'Invoke-Flyway' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level Debug -Message 'Leaving function Invoke-Flyway'
    return $summary
  }
}
