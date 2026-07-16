<#
.SYNOPSIS
Lists Bitwarden vault items in the specified folder and writes the inventory to the `_generated/` directory.

.DESCRIPTION
Uses the Bitwarden CLI (`bw`) to enumerate folders and items in the authenticated vault, filters items
to the target folder (default 'ATAP.Utilities'), and writes both JSON and CSV inventories to the
`_generated/` directory at the supplied repository root. Reads the `BW_SESSION` token from the
User-scope environment variable first (as set by `LoginScript.ps1`), then falls back to Process scope,
matching the agent-shell rule from `.claude/Rules/Bitwarden.md` (R-10).

.PARAMETER RepoRoot
Repository root path that contains (or will contain) the `_generated/` output directory.
When omitted, defaults to the current working directory.

.PARAMETER TargetFolderName
One or more Bitwarden personal-vault folder names whose items should be enumerated.
When both TargetFolderName and TargetOrganizationName are omitted, all items are returned.

.PARAMETER TargetOrganizationName
One or more Bitwarden organization names whose items should be enumerated.
When both TargetFolderName and TargetOrganizationName are omitted, all items are returned.

.PARAMETER TimeoutSeconds
Per-command timeout in seconds for each `bw` invocation. Defaults to 120 seconds.

.OUTPUTS
System.Management.Automation.PSCustomObject[]
Returns the array of matching item descriptors (Name, FolderName, Folder, Organization, Type, TypeId, ItemId, RevisionDate)
and writes the same data to the `_generated/` output files.

.EXAMPLE
List-BitwardenSecrets
Lists items in the 'ATAP.Utilities' Bitwarden folder under the current directory's `_generated/` folder.

.EXAMPLE
List-BitwardenSecrets -RepoRoot 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities' -TargetFolderName 'ATAP.Utilities'
Lists items in the specified folder and writes outputs under the given repository root.

.EXAMPLE
List-BitwardenSecrets -TargetFolderName 'ATAP.Utilities','AceCommander'
Lists items from both the 'ATAP.Utilities' and 'AceCommander' folders/organizations.

.NOTES
AI assisted using Powershell.instructions.md as guidelines
Requires the Bitwarden CLI (`bw`) on PATH and a valid `BW_SESSION` token (User or Process scope).

.LINK
https://github.com/whertzing/ATAP.Utilities
#>
function List-BitwardenSecrets {
  [CmdletBinding(SupportsShouldProcess = $true)]
  [OutputType([System.Management.Automation.PSCustomObject[]])]
  param(
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$RepoRoot,

    [Parameter(Mandatory = $false)]
    [string[]]$TargetFolderName = @(),

    [Parameter(Mandatory = $false)]
    [string[]]$TargetOrganizationName = @(),

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 3600)]
    [int]$TimeoutSeconds = 120
  )

  begin {
    $fn = 'List-BitwardenSecrets'
    $mn = 'ATAP.Utilities.Security.Secrets.PowerShell'

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
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'No filters specified — returning all items from all folders and organizations'
    }

    # Snippet: Check and populate simple parameter as Type - TimeoutSeconds
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Using TimeoutSeconds: $TimeoutSeconds"

    # Resolve BW_SESSION per .claude/Rules/Bitwarden.md (R-10): prefer User scope.
    $bwSession = [System.Environment]::GetEnvironmentVariable('BW_SESSION', 'User')
    if ([string]::IsNullOrWhiteSpace($bwSession)) {
      $bwSession = [System.Environment]::GetEnvironmentVariable('BW_SESSION', 'Process')
    }
    if ([string]::IsNullOrWhiteSpace($bwSession)) {
      $errorMessage = 'BW_SESSION was not found in User or Process scope. Run LoginScript.ps1 or set $env:BW_SESSION for the current pwsh process before running this script.'
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw $errorMessage
    }

    # Generated artifacts target (SC-0033): always write under <RepoRoot>/_generated.
    $generatedDir = Join-Path $RepoRoot '_generated'
    if (-not (Test-Path -LiteralPath $generatedDir)) {
      if ($PSCmdlet.ShouldProcess($generatedDir, 'Create _generated output directory')) {
        $null = New-Item -ItemType Directory -Path $generatedDir -Force
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Created generated directory: $generatedDir"
      }
    }

    $fileBaseName = if ($noFilters) {
      'bitwarden-all-items'
    } else {
      $slugParts = @(
        if ($TargetFolderName.Count -gt 0) { $TargetFolderName | ForEach-Object { $_.ToLower() -replace '[^a-z0-9]', '-' } }
        if ($TargetOrganizationName.Count -gt 0) { $TargetOrganizationName | ForEach-Object { $_.ToLower() -replace '[^a-z0-9]', '-' } }
      )
      "bitwarden-$($slugParts -join '-and-')-items"
    }
    $jsonPath = Join-Path $generatedDir "$fileBaseName.json"
    $csvPath = Join-Path $generatedDir "$fileBaseName.csv"

    # Local helper: invoke the Bitwarden CLI with a per-call timeout.
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
        # Begin async reads immediately to prevent stdout/stderr pipe-buffer deadlock.
        # If ReadToEnd() is called after WaitForExit(), a large payload (e.g. 'bw list items')
        # fills the pipe buffer and blocks the process before it can exit, causing a hang.
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
        return [pscustomobject]@{
          StdOut   = $stdout
          StdErr   = $stderr
          ExitCode = $process.ExitCode
        }
      } finally {
        $process.Dispose()
      }
    }

    # Local helper: map Bitwarden numeric item type to display name.
    $getBwTypeName = {
      param([int]$Type)
      switch ($Type) {
        1 { 'Login' }
        2 { 'SecureNote' }
        3 { 'Card' }
        4 { 'Identity' }
        default { "Unknown($Type)" }
      }
    }
  }

  process {
    # Snippet: Try-Catch-Finally
    try {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Running 'bw sync'"
      $syncResult = & $invokeBw -ArgumentList @('sync', '--session', $bwSession) -Timeout $TimeoutSeconds
      if (-not [string]::IsNullOrWhiteSpace($syncResult.StdOut)) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message $syncResult.StdOut.Trim()
      }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Loading folders from Bitwarden vault'
      $foldersJson = & $invokeBw -ArgumentList @('list', 'folders', '--session', $bwSession) -Timeout $TimeoutSeconds
      $folders = @($foldersJson.StdOut | ConvertFrom-Json)

      $folderMap = @{ }
      foreach ($folder in $folders) {
        if ($null -ne $folder.id) {
          $folderMap[$folder.id] = $folder.name
        }
      }
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Loaded $($folderMap.Count) folder(s)"

      # Build organization id→name map so items owned by an organization can be matched
      # by org name in addition to (or instead of) personal-vault folder name.
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Loading organizations from Bitwarden vault'
      $orgsJson = & $invokeBw -ArgumentList @('list', 'organizations', '--session', $bwSession) -Timeout $TimeoutSeconds
      $orgs = @($orgsJson.StdOut | ConvertFrom-Json)
      $orgMap = @{ }
      foreach ($org in $orgs) {
        if ($null -ne $org.id) {
          $orgMap[$org.id] = $org.name
        }
      }
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Loaded $($orgMap.Count) organization(s)"

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Loading items from Bitwarden vault'
      $itemsJson = & $invokeBw -ArgumentList @('list', 'items', '--session', $bwSession) -Timeout $TimeoutSeconds
      $items = @($itemsJson.StdOut | ConvertFrom-Json)
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Loaded $($items.Count) item(s) from vault"

      $matchingItems = foreach ($item in $items) {
        # Resolve personal-vault folder name (may be absent for org items).
        $fid = $item.PSObject.Properties['folderId']?.Value
        $folderName = if ($fid -and $folderMap.ContainsKey($fid)) {
          $folderMap[$fid]
        } else {
          ''
        }

        # Resolve organization name (absent for personal-vault items).
        $oid = $item.PSObject.Properties['organizationId']?.Value
        $orgName = if ($oid -and $orgMap.ContainsKey($oid)) {
          $orgMap[$oid]
        } else {
          ''
        }

        # Match if no filters specified (return all), or folder name is in TargetFolderName,
        # or org name is in TargetOrganizationName.
        if ($noFilters -or
          ($TargetFolderName.Count -gt 0 -and $TargetFolderName -contains $folderName) -or
          ($TargetOrganizationName.Count -gt 0 -and $TargetOrganizationName -contains $orgName)) {
          [pscustomobject]@{
            Name         = $item.name
            FolderName   = $folderName
            Folder       = if ($folderName) { $folderName } else { $orgName }
            Organization = $orgName
            Type         = & $getBwTypeName ([int]$item.type)
            TypeId       = [int]$item.type
            ItemId       = $item.id
            RevisionDate = $item.revisionDate
          }
        }
      }

      $results = @($matchingItems | Sort-Object Folder, Name)
      $scopeLabelParts = @()
      if ($TargetFolderName.Count -gt 0) { $scopeLabelParts += "folder(s): '$($TargetFolderName -join "', "")'" }
      if ($TargetOrganizationName.Count -gt 0) { $scopeLabelParts += "organization(s): '$($TargetOrganizationName -join "', "")'" }
      $scopeLabel = if ($scopeLabelParts.Count -eq 0) { 'all folders/organizations' } else { $scopeLabelParts -join '; ' }
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Secrets/items found in $($scopeLabel): $($results.Count)"

      if ($PSCmdlet.ShouldProcess($jsonPath, 'Write Bitwarden inventory JSON')) {
        $results |
          ConvertTo-Json -Depth 5 |
          Set-Content -LiteralPath $jsonPath -Encoding utf8
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Wrote JSON inventory: $jsonPath"
      }

      if ($PSCmdlet.ShouldProcess($csvPath, 'Write Bitwarden inventory CSV')) {
        $results |
          Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding utf8
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Wrote CSV inventory: $csvPath"
      }

      return $results
    } catch {
      $errorMessage = "Failed to list Bitwarden secrets for $($scopeLabel ?? 'all folders/organizations'). Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      # ToDo: accumulate the errors; potentially add to 'Problems'
      throw # the unadorned throw will throw the $_ exception and keep the stack trace intact
    } finally {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving Function $fn in module $mn"
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Function $fn completed"
  }
}
