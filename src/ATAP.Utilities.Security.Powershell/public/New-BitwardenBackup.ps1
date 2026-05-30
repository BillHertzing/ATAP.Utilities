<#
.SYNOPSIS
Creates a password-protected 7-Zip archive containing the full secrets data from one or more
Bitwarden folders or organizations.

.DESCRIPTION
Calls List-BitwardenSecrets to enumerate vault items in the requested scope, then fetches the
complete detail (including secret values) for each item via `bw get item`, serialises the
collection to a temporary JSON file, and compresses it into a password-protected .7z archive
under the `_generated/` directory. Header encryption (-mhe=on) is enabled so item names are
also hidden from the archive directory.

If no ArchivePassword is supplied (or an empty string is passed), a cryptographically random
16-character password is generated (mixed-case alphanumeric + punctuation) and written in
plain text to a companion file next to the archive so it can be recorded securely.

Reads the BW_SESSION token from User scope first, then Process scope (R-10).

.PARAMETER RepoRoot
Repository root that contains (or will contain) the _generated/ output directory.
Defaults to the current working directory.

.PARAMETER TargetFolderName
One or more Bitwarden personal-vault folder names to back up.
When both TargetFolderName and TargetOrganizationName are omitted, backs up every item.

.PARAMETER TargetOrganizationName
One or more Bitwarden organization names to back up.
When both TargetFolderName and TargetOrganizationName are omitted, backs up every item.

.PARAMETER ArchivePassword
Password to protect the 7-Zip archive. When omitted or empty a random password is generated
and written alongside the archive in a plain-text .password.txt file.

.PARAMETER TimeoutSeconds
Per-command timeout in seconds for each `bw` invocation. Defaults to 120 seconds.

.OUTPUTS
System.String
Path of the created .7z archive.

.EXAMPLE
New-BitwardenBackup
Backs up the entire vault to _generated/bitwarden-backup-<timestamp>.7z using a generated password.

.EXAMPLE
New-BitwardenBackup -TargetFolderName 'ATAP.Utilities' -ArchivePassword 'MyP@ssw0rd!'
Backs up only items in the ATAP.Utilities org/folder, protected with the supplied password.

.EXAMPLE
New-BitwardenBackup -TargetFolderName 'ATAP.Utilities','AceCommander'
Backs up items from both named folders; generates and saves a random password.

.EXAMPLE
New-BitwardenBackup -TargetOrganizationName 'ATAP.Utilities'
Backs up all items belonging to the ATAP.Utilities organization.

.NOTES
AI assisted using Powershell.instructions.md as guidelines
Requires the Bitwarden CLI (`bw`) on PATH, 7-Zip (`7z`) on PATH, and a valid BW_SESSION
token (User or Process scope).

.LINK
https://github.com/whertzing/ATAP.Utilities
#>
function New-BitwardenBackup {
  [CmdletBinding(SupportsShouldProcess = $true)]
  [OutputType([string])]
  param(
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$RepoRoot,

    [Parameter(Mandatory = $false)]
    [string[]]$TargetFolderName = @(),

    [Parameter(Mandatory = $false)]
    [string[]]$TargetOrganizationName = @(),

    [Parameter(Mandatory = $false)]
    [string]$ArchivePassword = '',

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 3600)]
    [int]$TimeoutSeconds = 120
  )

  begin {
    $fn = 'New-BitwardenBackup'
    $mn = 'ATAP.Utilities.Security.Powershell'

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn in module $mn"

    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    # Snippet: Check and populate simple parameter - RepoRoot
    if (-not $PSBoundParameters.ContainsKey('RepoRoot')) {
      $RepoRoot = (Get-Location).Path
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Using default RepoRoot: $RepoRoot"
    } else {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Using provided RepoRoot: $RepoRoot"
    }

    # Snippet: Check and populate simple parameter - TargetFolderName
    if ($TargetFolderName.Count -eq 0) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'TargetFolderName not specified'
    } else {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Using TargetFolderName(s): $($TargetFolderName -join ', ')"
    }

    # Snippet: Check and populate simple parameter - TargetOrganizationName
    if ($TargetOrganizationName.Count -eq 0) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'TargetOrganizationName not specified'
    } else {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Using TargetOrganizationName(s): $($TargetOrganizationName -join ', ')"
    }

    $noFilters = ($TargetFolderName.Count -eq 0 -and $TargetOrganizationName.Count -eq 0)
    if ($noFilters) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'No filters specified — backing up all items'
    }

    # Snippet: Check and populate simple parameter - ArchivePassword
    $passwordGenerated = $false
    if ([string]::IsNullOrEmpty($ArchivePassword)) {
      # Generate a cryptographically random 16-char password: mixed-case, digits, punctuation.
      $charset = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*()-_=+[]{}|;:,.<>?'
      $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
      $randomBytes = [byte[]]::new(16)
      $rng.GetBytes($randomBytes)
      $ArchivePassword = -join ($randomBytes | ForEach-Object { $charset[$_ % $charset.Length] })
      $rng.Dispose()
      $passwordGenerated = $true
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'ArchivePassword not supplied — generated a random password'
    } else {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Using supplied ArchivePassword'
    }

    # Snippet: Check and populate simple parameter as Type - TimeoutSeconds
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Using TimeoutSeconds: $TimeoutSeconds"

    # Validate external tools on PATH.
    if (-not (Get-Command 'bw' -ErrorAction SilentlyContinue)) {
      throw 'Bitwarden CLI (bw) was not found on PATH. Install it before running this command.'
    }
    if (-not (Get-Command '7z' -ErrorAction SilentlyContinue)) {
      throw '7-Zip CLI (7z) was not found on PATH. Install 7-Zip and ensure 7z.exe is on PATH.'
    }

    # Resolve BW_SESSION per R-10: prefer User scope.
    $bwSession = [System.Environment]::GetEnvironmentVariable('BW_SESSION', 'User')
    if ([string]::IsNullOrWhiteSpace($bwSession)) {
      $bwSession = [System.Environment]::GetEnvironmentVariable('BW_SESSION', 'Process')
    }
    if ([string]::IsNullOrWhiteSpace($bwSession)) {
      throw 'BW_SESSION was not found in User or Process scope. Run LoginScript.ps1 or set $env:BW_SESSION before running this command.'
    }

    # Generated artifacts target (SC-0033).
    $generatedDir = Join-Path $RepoRoot '_generated'
    if (-not (Test-Path -LiteralPath $generatedDir)) {
      if ($PSCmdlet.ShouldProcess($generatedDir, 'Create _generated output directory')) {
        $null = New-Item -ItemType Directory -Path $generatedDir -Force
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Created generated directory: $generatedDir"
      }
    }

    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $scopeSlug = if ($noFilters) {
      'all'
    } else {
      $slugParts = @(
        if ($TargetFolderName.Count -gt 0) { $TargetFolderName | ForEach-Object { $_.ToLower() -replace '[^a-z0-9]', '-' } }
        if ($TargetOrganizationName.Count -gt 0) { $TargetOrganizationName | ForEach-Object { $_.ToLower() -replace '[^a-z0-9]', '-' } }
      )
      $slugParts -join '-and-'
    }
    $archivePath = Join-Path $generatedDir "bitwarden-backup-$scopeSlug-$timestamp.7z"
    $tempJsonPath = Join-Path $generatedDir "bitwarden-backup-$scopeSlug-$timestamp.tmp.json"
    $passwordPath = Join-Path $generatedDir "bitwarden-backup-$scopeSlug-$timestamp.password.txt"

    # Local helper: invoke the Bitwarden CLI with a per-call timeout (same async-read
    # pattern as List-BitwardenSecrets to prevent pipe-buffer deadlock on large output).
    $invokeBw = {
      param(
        [Parameter(Mandatory = $true)] [string[]]$ArgumentList,
        [Parameter(Mandatory = $true)] [int]$Timeout
      )

      $psi = [System.Diagnostics.ProcessStartInfo]::new()
      $psi.FileName = 'bw'
      foreach ($arg in $ArgumentList) {
        [void]$psi.ArgumentList.Add($arg)
      }
      $psi.RedirectStandardOutput = $true
      $psi.RedirectStandardError = $true
      $psi.UseShellExecute = $false
      $psi.CreateNoWindow = $true

      $process = [System.Diagnostics.Process]::new()
      $process.StartInfo = $psi

      try {
        $null = $process.Start()
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit($Timeout * 1000)) {
          try { $process.Kill($true) } catch { }
          throw "Command timed out after $Timeout seconds: bw $($ArgumentList -join ' ')"
        }
        $stdout = $stdoutTask.GetAwaiter().GetResult()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        if ($process.ExitCode -ne 0) {
          throw "bw exited with code $($process.ExitCode). Command: bw $($ArgumentList -join ' '). Error: $stderr"
        }
        return [pscustomobject]@{ StdOut = $stdout; StdErr = $stderr; ExitCode = $process.ExitCode }
      } finally {
        $process.Dispose()
      }
    }
  }

  process {
    try {
      # Step 1: Get the summary item list from List-BitwardenSecrets.
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Retrieving item list from List-BitwardenSecrets'
      $listParams = @{ RepoRoot = $RepoRoot; TimeoutSeconds = $TimeoutSeconds }
      if ($TargetFolderName.Count -gt 0) {
        $listParams['TargetFolderName'] = $TargetFolderName
      }
      if ($TargetOrganizationName.Count -gt 0) {
        $listParams['TargetOrganizationName'] = $TargetOrganizationName
      }
      $summaryItems = List-BitwardenSecrets @listParams
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "List-BitwardenSecrets returned $($summaryItems.Count) item(s)"

      if ($summaryItems.Count -eq 0) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'No items matched the requested scope — nothing to back up'
        return $null
      }

      # Step 2: Fetch full item details (including secret values) for each item.
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Fetching full details for each item'
      $fullItems = foreach ($summary in $summaryItems) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Fetching item: $($summary.Name) ($($summary.ItemId))"
        $result = & $invokeBw -ArgumentList @('get', 'item', $summary.ItemId, '--session', $bwSession) -Timeout $TimeoutSeconds
        $result.StdOut | ConvertFrom-Json
      }
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Fetched $($fullItems.Count) full item(s)"

      # Step 3: Write full items to temp JSON.
      if ($PSCmdlet.ShouldProcess($tempJsonPath, 'Write temporary backup JSON')) {
        $fullItems | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $tempJsonPath -Encoding utf8
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Wrote temporary JSON: $tempJsonPath"
      }

      # Step 4: Compress into password-protected 7-Zip archive.
      # -mhe=on encrypts archive headers so item filenames are also hidden.
      if ($PSCmdlet.ShouldProcess($archivePath, 'Create password-protected 7-Zip archive')) {
        $sevenZipArgs = @('a', "-p$ArchivePassword", '-mhe=on', '-mx=9', $archivePath, $tempJsonPath)
        $sevenZipResult = & 7z @sevenZipArgs
        if ($LASTEXITCODE -ne 0) {
          throw "7z failed with exit code $LASTEXITCODE. Output: $sevenZipResult"
        }
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Created archive: $archivePath"
      }

      # Step 5: If password was generated, write it to a companion file.
      if ($passwordGenerated) {
        if ($PSCmdlet.ShouldProcess($passwordPath, 'Write generated archive password')) {
          Set-Content -LiteralPath $passwordPath -Value $ArchivePassword -Encoding utf8
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Generated password written to: $passwordPath"
        }
      }

      return $archivePath
    } catch {
      $errorMessage = "Failed to create Bitwarden backup. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw
    } finally {
      # Always remove the unencrypted temp JSON regardless of success or failure.
      if (Test-Path -LiteralPath $tempJsonPath) {
        Remove-Item -LiteralPath $tempJsonPath -Force -ErrorAction SilentlyContinue
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Removed temporary JSON: $tempJsonPath"
      }
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving Function $fn in module $mn"
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Function $fn completed"
  }
}
