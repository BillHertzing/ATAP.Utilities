<#
.SYNOPSIS
Loads the most recent password-protected Bitwarden Password-Manager backup archive produced by
New-BitwardenBackup and transforms it into a Bitwarden Secrets Manager (BWS) import JSON file.

.DESCRIPTION
This is a one-way migration helper that converts a Password-Manager backup (items produced by
`bw get item`) into the JSON shape accepted by the Bitwarden Secrets Manager importer
(`{ projects: [...], secrets: [...] }`).

Workflow:
  0. Scan GeneratedBasePath for the most recent matching pair of
     bitwarden-backup-atap-utilities-<yyyyMMdd-HHmmss>.7z and .password.txt files.
  1. Read the archive password from the .password.txt file.
  2. Extract the .7z (header-encrypted) archive with 7-Zip using that password and parse the
     contained JSON into the $items array.
  3. Build lookup maps (organizationId->organizationName, folderId->folderName, type->typeName).
  4. Transform every item into a BWS secret and assign it to a project:
       * Secret KEY transform (in order):
           - trim leading/trailing blanks
           - API_Token / ApiKey            -> API_Key   (case-insensitive)
           - EncryptionKeyV1               -> Encryption.Key.V1 (case-insensitive)
           - then replace every '_' and '-' with '.' (runs of '.' collapsed)
       * Project routing (first match wins):
           - name contains 'dbConnectionString' -> CI-Shared
           - name starts with 'AceCommander'     -> AceCommander
           - name contains 'API_Key'             -> CI-Shared
           - otherwise                           -> no project (imported, left unassigned)
       * Secret VALUE is a single bare value (treated as a standard secure note):
           - Login items                 -> compact JSON { username, password }
           - everything else             -> the secure-note body (notes) when present,
             otherwise the primary (first non-empty) custom field. Extra fields are dropped,
             e.g. GitHub keeps only Token (Expiration dropped); a license keeps its notes body.
       * Secret NOTE carries the original Password-Manager typeName ('SecureNote' / 'Login'),
         which satisfies the rule that dbConnectionString secrets are typed SecureNote.
  5. Write bitwarden-import-ATAPUtilities-<yyyyMMdd-HHmmss>.json into GeneratedBasePath.

The two projects CI-Shared and AceCommander are always defined, even if no secret routes to one.

.PARAMETER GeneratedBasePath
Folder holding the backup files and receiving the generated import JSON. Defaults to the
sprint worktree's _generated directory.

.OUTPUTS
System.String
Full path of the generated BWS import JSON file.

.EXAMPLE
Load-BitwardenBackup
Converts the newest backup in the default _generated folder into a BWS import file.

.EXAMPLE
Load-BitwardenBackup -GeneratedBasePath 'C:\Backups' -WhatIf
Shows what would be produced from the newest backup under C:\Backups without writing the file.

.NOTES
AI assisted using Powershell.instructions.md as guidelines
Requires the 7-Zip CLI (`7z`) on PATH. The generated import file contains plaintext secret
values; treat it as sensitive and remove it once the import into Secrets Manager is complete.

.LINK
https://github.com/whertzing/ATAP.Utilities
#>
function Load-BitwardenBackup {
  [CmdletBinding(SupportsShouldProcess = $true)]
  [OutputType([string])]
  param(
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$GeneratedBasePath = 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-100-Sprint-0007-work-items\_generated\'
  )

  begin {
    $fn = 'Load-BitwardenBackup'
    $mn = 'ATAP.Utilities.Security.Powershell'

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn in module $mn"

    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    # Snippet: Check and populate simple parameter - GeneratedBasePath
    if (-not (Test-Path -LiteralPath $GeneratedBasePath)) {
      throw "GeneratedBasePath does not exist: $GeneratedBasePath"
    }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Using GeneratedBasePath: $GeneratedBasePath"

    # Validate external tools on PATH.
    if (-not (Get-Command '7z' -ErrorAction SilentlyContinue)) {
      throw '7-Zip CLI (7z) was not found on PATH. Install 7-Zip and ensure 7z.exe is on PATH.'
    }

    # The projects defined in every generated import file.
    $projectNames = @('CI-Shared', 'AceCommander')

    # Local helper: map Bitwarden numeric item type to display name (mirrors List-BitwardenSecrets).
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

    # Local helper: transform a raw Password-Manager item name into the final BWS secret key.
    $transformKey = {
      param([string]$RawName)
      $n = $RawName.Trim()
      $n = $n -ireplace 'API_Token', 'API_Key'
      $n = $n -ireplace 'ApiKey', 'API_Key'
      $n = $n -ireplace 'EncryptionKeyV1', 'Encryption.Key.V1'
      # Capture the project-routing name (still carries 'API_Key') before the global punctuation swap.
      $routeName = $n
      # Global rule: every '_' or '-' becomes '.', collapse runs of '.', trim leading/trailing '.'.
      $key = ($n -replace '[_-]', '.') -replace '\.{2,}', '.'
      $key = $key.Trim('.')
      [pscustomobject]@{ Key = $key; RouteName = $routeName }
    }

    # Local helper: choose the project for a routed name (first match wins).
    $routeProject = {
      param([string]$RouteName)
      if ($RouteName -imatch 'dbConnectionString') { 'CI-Shared' }
      elseif ($RouteName -imatch '^AceCommander') { 'AceCommander' }
      elseif ($RouteName -imatch 'API_Key') { 'CI-Shared' }
      else { $null }
    }

    # Local helper: extract a single bare secret value from a source item.
    # Login items keep both halves as compact JSON; everything else becomes one scalar value
    # (the secure-note body when present, else the primary/first non-empty custom field).
    $extractValue = {
      param($Item)
      if ($Item.PSObject.Properties['login'] -and $Item.login) {
        $cred = [ordered]@{ }
        if (-not [string]::IsNullOrWhiteSpace($Item.login.username)) { $cred['username'] = $Item.login.username }
        if (-not [string]::IsNullOrWhiteSpace($Item.login.password)) { $cred['password'] = $Item.login.password }
        if ($cred.Count -eq 1) { return [string]($cred.Values | Select-Object -First 1) }
        if ($cred.Count -gt 1) { return ($cred | ConvertTo-Json -Compress -Depth 4) }
      }
      # Secure note (or any non-login): prefer the note body, then the primary custom field.
      if ($Item.PSObject.Properties['notes'] -and -not [string]::IsNullOrWhiteSpace($Item.notes)) {
        return [string]$Item.notes
      }
      if ($Item.PSObject.Properties['fields'] -and $Item.fields) {
        foreach ($f in $Item.fields) {
          if (-not [string]::IsNullOrWhiteSpace($f.value)) { return [string]$f.value }
        }
      }
      return ''
    }
  }

  process {
    $tempDir = $null
    try {
      # Step 0: Locate the most recent backup/password pair.
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Scanning for the most recent backup pair'
      $archive = Get-ChildItem -LiteralPath $GeneratedBasePath -Filter 'bitwarden-backup-atap-utilities-*.7z' -ErrorAction SilentlyContinue |
        Sort-Object -Property LastWriteTime -Descending |
        Select-Object -First 1
      if (-not $archive) {
        throw "No archive found matching 'bitwarden-backup-atap-utilities-*.7z' in $GeneratedBasePath"
      }

      # Prefer the .password.txt that shares the archive's base name; fall back to the newest one.
      # FileInfo.BaseName strips the trailing '.7z', giving 'bitwarden-backup-atap-utilities-<stamp>'.
      $expectedPwPath = Join-Path $archive.DirectoryName ($archive.BaseName + '.password.txt')
      if (Test-Path -LiteralPath $expectedPwPath) {
        $passwordPath = $expectedPwPath
      } else {
        $pwFile = Get-ChildItem -LiteralPath $GeneratedBasePath -Filter 'bitwarden-backup-atap-utilities-*.password.txt' -ErrorAction SilentlyContinue |
          Sort-Object -Property LastWriteTime -Descending |
          Select-Object -First 1
        if (-not $pwFile) {
          throw "No password file found matching 'bitwarden-backup-atap-utilities-*.password.txt' in $GeneratedBasePath"
        }
        $passwordPath = $pwFile.FullName
      }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Backup archive: $($archive.FullName)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Password file:  $passwordPath"

      # Step 1: Read the archive password.
      $password = (Get-Content -LiteralPath $passwordPath -Raw).Trim()
      if ([string]::IsNullOrWhiteSpace($password)) {
        throw "Password file is empty: $passwordPath"
      }

      # Step 2: Extract the archive and parse the backup JSON into $items.
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Extracting backup archive'
      $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "bw-load-$([guid]::NewGuid().ToString('N'))"
      $null = New-Item -ItemType Directory -Path $tempDir -Force

      $sevenZipOutput = & 7z 'x' "-p$password" "-o$tempDir" $archive.FullName '-y' 2>&1
      if ($LASTEXITCODE -ne 0) {
        throw "7z extraction failed with exit code $LASTEXITCODE. Output: $sevenZipOutput"
      }

      $extractedJson = Get-ChildItem -LiteralPath $tempDir -Filter '*.json' -Recurse -ErrorAction SilentlyContinue |
        Select-Object -First 1
      if (-not $extractedJson) {
        throw 'No JSON file was found inside the extracted archive.'
      }
      $items = @(Get-Content -LiteralPath $extractedJson.FullName -Raw | ConvertFrom-Json)
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Parsed $($items.Count) item(s) from the backup"
      if ($items.Count -eq 0) {
        throw 'The backup archive contained no items.'
      }

      # Step 3: Build the lookup maps requested by the contract.
      $organizationMap = @{ }
      $folderMap = @{ }
      $typeMap = @{ }
      foreach ($item in $items) {
        $oid = $item.PSObject.Properties['organizationId']?.Value
        $oname = $item.PSObject.Properties['organizationName']?.Value
        if ($oid -and $oname -and -not $organizationMap.ContainsKey($oid)) { $organizationMap[$oid] = $oname }

        $fid = $item.PSObject.Properties['folderId']?.Value
        $fname = $item.PSObject.Properties['folderName']?.Value
        if ($fid -and $fname -and -not $folderMap.ContainsKey($fid)) { $folderMap[$fid] = $fname }

        $tid = [int]$item.type
        if (-not $typeMap.ContainsKey($tid)) {
          $tname = $item.PSObject.Properties['typeName']?.Value
          if ([string]::IsNullOrWhiteSpace($tname)) { $tname = & $getBwTypeName $tid }
          $typeMap[$tid] = $tname
        }
      }
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Maps built — organizations: $($organizationMap.Count), folders: $($folderMap.Count), types: $($typeMap.Count)"

      # Define the projects and assign each a reference GUID for the import file.
      $projectIdMap = @{ }
      foreach ($p in $projectNames) { $projectIdMap[$p] = [guid]::NewGuid().ToString() }
      $projects = @($projectNames | ForEach-Object { [ordered]@{ id = $projectIdMap[$_]; name = $_ } })

      # Step 4/5: Transform every item into a BWS secret.
      $routeCounts = [ordered]@{ 'CI-Shared' = 0; 'AceCommander' = 0; '(unassigned)' = 0 }
      $outItems = foreach ($item in $items) {
        $t = & $transformKey ([string]$item.name)
        $projectName = & $routeProject $t.RouteName

        $typeName = $typeMap[[int]$item.type]
        $value = & $extractValue $item

        if ($projectName) {
          $projectIds = [string[]]@($projectIdMap[$projectName])
          $routeCounts[$projectName]++
        } else {
          $projectIds = [string[]]@()
          $routeCounts['(unassigned)']++
        }

        [ordered]@{
          id         = [guid]::NewGuid().ToString()
          key        = $t.Key
          value      = $value
          note       = $typeName
          projectIds = $projectIds
        }
      }
      $outItems = @($outItems)

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message (
        "Routed secrets — CI-Shared: $($routeCounts['CI-Shared']), AceCommander: $($routeCounts['AceCommander']), " +
        "unassigned: $($routeCounts['(unassigned)'])")

      # Step n: Assemble the BWS import structure and write it out.
      $importStructure = [ordered]@{
        projects = $projects
        secrets  = $outItems
      }

      $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
      $importFilePath = Join-Path $GeneratedBasePath "bitwarden-import-ATAPUtilities-$timestamp.json"

      if ($PSCmdlet.ShouldProcess($importFilePath, 'Write Bitwarden Secrets Manager import JSON')) {
        $importStructure | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $importFilePath -Encoding utf8
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Created import file: $importFilePath"
      }

      return $importFilePath
    } catch {
      $errorMessage = "Failed to load Bitwarden backup. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw
    } finally {
      # Always remove the unencrypted extracted copy of the backup.
      if ($tempDir -and (Test-Path -LiteralPath $tempDir)) {
        Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Removed temporary extraction directory: $tempDir"
      }
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn in module $mn"
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Function $fn completed"
  }
}
