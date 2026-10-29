function Get-SharedVSCodeContext {
  <#
  .SYNOPSIS
    Returns an all-or-nothing, read-only SharedVSCode routing plan.
  .DESCRIPTION
    Validates literal workspace paths, registered Git identities, source authority,
    current include origins and required assets before returning any objects.
    Normal behavior is unchanged. Explicit SourceEndProjection retains canonical
    source identity and supplies a separately validated stable Git metadata plan.
    A plan grants no write, migration, source-End or runtime admission.
  .PARAMETER WorkspaceFiles
    Absolute local FileSystem .code-workspace files in one registered checkout.
  .PARAMETER GitRoot
    Absolute parent of the canonical stable SharedVSCode checkout and peers.
    Fixture callers must explicitly supply their owned fixture root.
  .PARAMETER SharedVSCodeRepoName
    Single folder name identifying the stable canonical source.
  .PARAMETER SharedHooksSubPath
    Safe relative descendant path of the selected source hooks directory.
  .PARAMETER CommitTemplateRelativePath
    Safe relative descendant path of the selected source commit template.
  .PARAMETER RequestedTemplateRef
    Optional desired ref without editing the original workspace. Configured
    transitions are held; Normal source identity must remain self-selected.
  .PARAMETER ContextMode
    Normal by default. SourceEndProjection is an explicit source-End intent,
    requiring ExpectedSourceRoot and ProjectionAuthority; it performs no writes.
  .PARAMETER ExpectedSourceRoot
    Exact registered outgoing canonical sprint source root for projection.
  .PARAMETER ProjectionAuthority
    Explicit StableRoot, StableGitDir, CommonGitDir, StableAssetPins containing
    Path/SHA256 bindings and ReceiptCustodyRoot. This grants no execution authority.
  .OUTPUTS
    PSCustomObject[] with the eight legacy properties, OriginalTemplateRef and Plan.
  .EXAMPLE
    Get-SharedVSCodeContext -WorkspaceFiles 'C:/Git/A/A.code-workspace' -GitRoot 'C:/Git'
  .NOTES
    No source/helper loading or configuration mutation. Native framing and all
    required cases must pass separately admitted fixture verification before use.
  .LINK
    https://git-scm.com/docs/git-config
  #>
  [CmdletBinding(SupportsShouldProcess)]
  [OutputType([PSCustomObject[]])]
  param(
    [Parameter(Mandatory)][AllowNull()][AllowEmptyCollection()][string[]]$WorkspaceFiles,
    [string]$GitRoot = 'C:\dropbox\whertzing\GitHub',
    [string]$SharedVSCodeRepoName = 'SharedVSCode',
    [string]$SharedHooksSubPath = '.githooks',
    [string]$CommitTemplateRelativePath = 'GitTemplates\git.commit.template.txt',
    [string]$RequestedTemplateRef,
    [ValidateSet('Normal', 'SourceEndProjection')][string]$ContextMode = 'Normal',
    [string]$ExpectedSourceRoot,
    [object]$ProjectionAuthority
  )
  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    $resolverCmdlet = $PSCmdlet
    $overrideRequested = $PSBoundParameters.ContainsKey('RequestedTemplateRef')
    $comparison = [StringComparison]::OrdinalIgnoreCase
    $watch = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::OrdinalIgnoreCase)
    $watchOrder = [Collections.Generic.List[string]]::new()
    $identityWatch = [Collections.Generic.Dictionary[string, string]]::new([StringComparer]::OrdinalIgnoreCase)
    $projectionRequested = [string]::Equals($ContextMode, 'SourceEndProjection', [StringComparison]::OrdinalIgnoreCase)
    $projectionTrees = [Collections.Generic.Dictionary[string, string]]::new([StringComparer]::OrdinalIgnoreCase)
    $projectionDirectoryPins = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::OrdinalIgnoreCase)
    $projectionConfigWatch = [Collections.Generic.Dictionary[string, string]]::new([StringComparer]::OrdinalIgnoreCase)

    # Function-local implementation details; dot-sourcing this file defines only
    # the public function. None of these helpers execute at module load time.
    function failContext([string]$Code) {
      $record = [Management.Automation.ErrorRecord]::new(
        [InvalidOperationException]::new("SharedVSCodeContext.$Code"),
        "SharedVSCodeContext.$Code", [Management.Automation.ErrorCategory]::InvalidData, $null)
      $resolverCmdlet.ThrowTerminatingError($record)
    }
    function invokeContextLogger([string]$Message) {
      try {
        # Capture both success and continuing error records. A logger can use an
        # explicit -ErrorAction Continue, so an outer try/catch alone is not an
        # error boundary. Never change caller/script/global preferences.
        $records = @(& $logger -FunctionName $fn -ModuleName $mn -Level Debug -Message $Message 2>&1)
        foreach ($record in $records) {
          if ($record -is [Management.Automation.ErrorRecord]) { failContext 'InvalidInput' }
        }
      } catch { failContext 'InvalidInput' }
    }
    function samePath([string]$Left, [string]$Right) {
      return [string]::Equals($Left, $Right, $comparison)
    }
    function safeRelative([string]$Value, [bool]$Single = $false) {
      if ([string]::IsNullOrWhiteSpace($Value) -or $Value -match '[\x00-\x1f:*?\[\]]' -or
        [IO.Path]::IsPathRooted($Value)) { failContext 'UnsafePath' }
      $parts = @($Value.Replace('\', '/').Split('/'))
      if ($Single -and $parts.Count -ne 1) { failContext 'UnsafePath' }
      foreach ($part in $parts) {
        if (!$part -or $part -in @('.', '..') -or $part -match '[. ]$|^(?i:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.|$)') {
          failContext 'UnsafePath'
        }
      }
      return ($parts -join '/')
    }
    function localPath([string]$Value) {
      if ([string]::IsNullOrWhiteSpace($Value) -or $Value -notmatch '^[A-Za-z]:[/\\]' -or
        $Value.Substring(2) -match '[:*?\[\]\x00-\x1f]') { failContext 'UnsafePath' }
      $tail = $Value.Substring(3).Replace('\', '/').TrimEnd('/')
      if ($tail) { $null = safeRelative $tail }
      try { $full = [IO.Path]::GetFullPath($Value).Replace('\', '/').TrimEnd('/') }
      catch { failContext 'UnsafePath' }
      $ancestor = [IO.DirectoryInfo]::new([IO.Path]::GetDirectoryName($full))
      while ($null -ne $ancestor) {
        # ReparsePoint alone is not redirection (Dropbox cloud placeholders).
        # An actual symbolic link/junction target is not an accepted path authority.
        if ($ancestor.Exists -and $null -ne $ancestor.LinkTarget) { failContext 'UnsafePath' }
        $ancestor = $ancestor.Parent
      }
      if ([IO.File]::Exists($full) -and $null -ne ([IO.FileInfo]::new($full)).LinkTarget) { failContext 'UnsafePath' }
      if ([IO.Directory]::Exists($full) -and $null -ne ([IO.DirectoryInfo]::new($full)).LinkTarget) { failContext 'UnsafePath' }
      return $full
    }
    function containedPath([string]$Path, [string]$Root) {
      return (samePath $Path $Root) -or $Path.StartsWith($Root.TrimEnd('/') + '/', $comparison)
    }
    function snapshotFile([string]$Path, [bool]$Required = $true) {
      $pathValue = localPath $Path
      $exists = $false
      try {
        $attributes = [IO.File]::GetAttributes($pathValue)
        if (($attributes -band [IO.FileAttributes]::Directory) -ne 0) { failContext 'UnsafePath' }
        $exists = $true
      } catch [IO.FileNotFoundException] { $exists = $false }
      catch [IO.DirectoryNotFoundException] { $exists = $false }
      catch {
        if ($_.FullyQualifiedErrorId -like 'SharedVSCodeContext.*') { throw }
        failContext 'UnsafePath'
      }
      if ($Required -and !$exists) { failContext 'MissingPrerequisite' }
      $hash = $null
      if ($exists) {
        try { $hash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([IO.File]::ReadAllBytes($pathValue))) }
        catch { failContext 'MissingPrerequisite' }
      }
      $pin = [pscustomobject][ordered]@{ Path = $pathValue; Exists = $exists; Sha256 = $hash }
      if (!$watch.ContainsKey($pathValue)) { $watch.Add($pathValue, $pin); $watchOrder.Add($pathValue) }
      elseif ($watch[$pathValue].Exists -ne $exists -or $watch[$pathValue].Sha256 -cne $hash) { failContext 'ObservationChanged' }
      return $pin
    }
    function readGit([string]$Root, [string[]]$Arguments, [bool]$Optional = $false) {
      $start = [Diagnostics.ProcessStartInfo]::new()
      $start.FileName = $gitExecutable
      $start.UseShellExecute = $false
      $start.CreateNoWindow = $true
      $start.RedirectStandardOutput = $true
      $start.RedirectStandardError = $true
      $start.StandardOutputEncoding = [Text.UTF8Encoding]::new($false, $true)
      foreach ($argValue in @('--no-optional-locks', '-C', $Root) + $Arguments) { $start.ArgumentList.Add($argValue) }
      $child = [Diagnostics.Process]::new()
      $child.StartInfo = $start
      try {
        $null = $child.Start()
        # Drain BOTH streams before waiting (R-34); never leak native output.
        $stdoutTask = $child.StandardOutput.ReadToEndAsync()
        $stderrTask = $child.StandardError.ReadToEndAsync()
        $child.WaitForExit()
        $stdout = $stdoutTask.GetAwaiter().GetResult()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        if ($Optional -and $child.ExitCode -eq 1 -and !$stdout -and !$stderr) { return '' }
        if ($child.ExitCode -ne 0 -or $stderr) { failContext 'NativeReadFailed' }
        return $stdout
      } catch {
        if ($_.FullyQualifiedErrorId -like 'SharedVSCodeContext.*') { throw }
        failContext 'NativeReadFailed'
      } finally { $child.Dispose() }
    }
    function oneGit([string]$Root, [string[]]$Arguments) {
      $raw = readGit $Root $Arguments
      $value = $raw.TrimEnd([char[]]@([char]13, [char]10))
      if (!$value -or $value.Contains([char]10) -or $value.Contains([char]0)) { failContext 'AmbiguousIdentity' }
      return $value
    }
    function registeredIdentity([string]$Root) {
      $rootValue = localPath $Root
      if (![IO.Directory]::Exists($rootValue)) { failContext 'MissingPrerequisite' }
      $inside = oneGit $rootValue @('rev-parse', '--is-inside-work-tree')
      if ($inside -cne 'true') { failContext 'InvalidTargetIdentity' }
      $top = localPath (oneGit $rootValue @('rev-parse', '--show-toplevel'))
      if (!(samePath $rootValue $top)) { failContext 'InvalidTargetIdentity' }
      $dir = localPath (oneGit $rootValue @('rev-parse', '--absolute-git-dir'))
      $common = localPath (oneGit $rootValue @('rev-parse', '--path-format=absolute', '--git-common-dir'))
      $raw = readGit $rootValue @('worktree', 'list', '--porcelain', '-z')
      # -z ends with exactly one empty-record marker. Split adds a trailing
      # empty element of its own, which is excluded from record parsing below.
      $terminalNulCount = $raw.Length - $raw.TrimEnd([char]0).Length
      if ($terminalNulCount -ne 2) { failContext 'AmbiguousIdentity' }
      $records = [Collections.Generic.List[object]]::new()
      $record = $null
      $fields = $raw.Split([char]0)
      for ($fieldIndex = 0; $fieldIndex -lt $fields.Length - 1; $fieldIndex++) {
        $field = $fields[$fieldIndex]
        if (!$field) {
          if ($null -eq $record) { failContext 'AmbiguousIdentity' }
          if (!$record.Bad -and (!$record.Tags.Contains('HEAD') -or ($record.Tags.Contains('branch') -eq $record.Tags.Contains('detached')))) { failContext 'AmbiguousIdentity' }
          $records.Add($record); $record = $null
          continue
        }
        if ($field.StartsWith('worktree ')) {
          if ($null -ne $record) { failContext 'AmbiguousIdentity' }
          $record = [ordered]@{ Path = localPath $field.Substring(9); Bad = $false; Tags = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal) }
        } elseif ($null -eq $record) { failContext 'AmbiguousIdentity' }
        else {
          $tag = $field.Split(' ', 2)[0]
          if (!$record.Tags.Add($tag)) { failContext 'AmbiguousIdentity' }
          if ($field -match '^(?:bare|prunable)(?: |$)') { $record.Bad = $true }
          elseif ($field -notmatch '^(HEAD (?:[0-9a-fA-F]{40}|[0-9a-fA-F]{64})|branch refs/[^\x00]+|detached|locked(?: .*)?)$') { failContext 'AmbiguousIdentity' }
        }
      }
      if ($null -ne $record -or !$records.Count) { failContext 'AmbiguousIdentity' }
      $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
      foreach ($entry in $records) { if (!$seen.Add($entry.Path)) { failContext 'AmbiguousIdentity' } }
      $matches = @($records | Where-Object { samePath $_.Path $top })
      if ($matches.Count -ne 1 -or $matches[0].Bad -or ![IO.Directory]::Exists($dir)) { failContext 'MissingRegistration' }
      $mainRoot = $records[0].Path
      if ($records[0].Bad) { failContext 'MissingRegistration' }
      $mainDir = localPath (oneGit $mainRoot @('rev-parse', '--absolute-git-dir'))
      if (!(samePath $mainDir $common)) { failContext 'AmbiguousIdentity' }
      $linked = !(samePath $dir $common)
      if ($linked -and !(containedPath $dir ($common + '/worktrees'))) { failContext 'AmbiguousIdentity' }
      $fingerprint = "$top|$dir|$common|$raw"
      if ($identityWatch.ContainsKey($rootValue) -and $identityWatch[$rootValue] -cne $fingerprint) { failContext 'ObservationChanged' }
      $identityWatch[$rootValue] = $fingerprint
      return [pscustomobject]@{ TopLevel = $top; GitDir = $dir; CommonDir = $common; IsLinkedWorktree = $linked; MainRoot = $mainRoot; Records = $records.ToArray() }
    }
    function readContextConfig([string]$Root) {
      $pattern = '^(extensions\.worktreeconfig|include\.path|includeif\..*\.path|core\.hookspath|commit\.template)$'
      $raw = readGit $Root @('config', '--includes', '--null', '--show-origin', '--show-scope', '--get-regexp', $pattern) $true
      if (!$raw) { return }
      $parts = $raw.Split([char]0)
      if ($parts[-1] -ne '' -or (($parts.Count - 1) % 3) -ne 0) { failContext 'NativeReadFailed' }
      for ($index = 0; $index -lt $parts.Count - 1; $index += 3) {
        $scopeValue = $parts[$index]
        $origin = $parts[$index + 1]
        $kv = $parts[$index + 2]
        $separator = $kv.IndexOf([char]10)
        if ($scopeValue -notin @('local', 'worktree') -or !$origin.StartsWith('file:') -or $separator -lt 1) { failContext 'UnsafeIncludeRoute' }
        $originValue = $origin.Substring(5)
        if ($originValue -match '^[A-Za-z]:[/\\]') {
          $originPath = localPath $originValue
        } else {
          # Git may report file:.git/config for a main checkout. Resolve that
          # spelling against THIS native -C root, never the PowerShell CWD.
          $relativeOrigin = safeRelative $originValue
          $originPath = localPath ([IO.Path]::Combine($Root, $relativeOrigin))
        }
        $null = snapshotFile $originPath
        $key = $kv.Substring(0, $separator)
        $value = $kv.Substring($separator + 1)
        if ($value.Contains([char]10)) { failContext 'UnsafeIncludeRoute' }
        [pscustomobject]@{ Scope = $scopeValue; OriginPath = $originPath; Key = $key; Value = $value }
      }
    }
    function configValuePath([string]$Value, [string]$Origin) {
      if ($Value -match '^[A-Za-z]:[/\\]') { return (localPath $Value) }
      $relative = safeRelative $Value
      return (localPath ([IO.Path]::Combine([IO.Path]::GetDirectoryName($Origin), $relative)))
    }
    function renderMatches([string]$Target, [string]$Source) {
      $null = snapshotFile $Target
      $null = snapshotFile $Source
      $lf = [string][char]10
      $header = @(
        '# ==================================================================='
        '# GENERATED FILE - DO NOT EDIT DIRECTLY'
        '# Source: SharedVSCode/.gitconfig'
        '# Regenerate using Set-DownstreamSharedVSCodeContext'
        '# ==================================================================='
        ''
      ) -join $lf
      $sourceText = [IO.File]::ReadAllText($Source) -replace '\r\n?', $lf
      $expectedText = $header + $sourceText + $lf
      $actual = [IO.File]::ReadAllBytes($Target)
      $expectedBytes = [Text.UTF8Encoding]::new($false).GetBytes($expectedText)
      return [Linq.Enumerable]::SequenceEqual([byte[]]$actual, [byte[]]$expectedBytes)
    }
    function projectionField([object]$Value, [string]$Name) {
      if ($null -eq $Value) { failContext 'ProjectionAuthorityRequired' }
      if ($Value -is [Collections.IDictionary]) {
        if (!$Value.Contains($Name)) { failContext 'ProjectionAuthorityRequired' }
        return $Value[$Name]
      }
      $property = $Value.PSObject.Properties[$Name]
      if ($null -eq $property) { failContext 'ProjectionAuthorityRequired' }
      return $property.Value
    }
    function projectionPin([string]$Path, [bool]$Required = $true) {
      $pin = snapshotFile $Path $Required
      if ($pin.Exists) { projectionOrdinaryPath $pin.Path $false }
      $length = if ($pin.Exists) { ([IO.FileInfo]::new($pin.Path)).Length } else { $null }
      return [pscustomobject][ordered]@{
        Path = $pin.Path; Exists = [bool]$pin.Exists; Existence = [bool]$pin.Exists; SHA256 = $pin.Sha256; Length = $length
      }
    }
    function projectionOrdinaryPath([string]$Path, [bool]$Directory) {
      $items = @(& $projectionMetadataReader -LiteralPath $Path -Force -ErrorAction Stop)
      if ($items.Count -ne 1 -or ($Directory -and $items[0] -isnot [IO.DirectoryInfo]) -or
        (!$Directory -and $items[0] -isnot [IO.FileInfo])) { failContext 'UnsafePath' }
      $item = $items[0]
      if ($null -eq $item.PSObject.Properties['LinkType']) { failContext 'MissingPrerequisite' }
      if (![string]::IsNullOrEmpty([string]$item.LinkType) -or $null -ne $item.LinkTarget -or
        !(samePath (localPath $item.FullName) $Path)) { failContext 'UnsafePath' }
    }
    function projectionHookFiles([string]$Root) {
      $directory = localPath $Root
      if (![IO.Directory]::Exists($directory)) { failContext 'MissingPrerequisite' }
      projectionOrdinaryPath $directory $true
      $pending = [Collections.Generic.Queue[string]]::new()
      $pending.Enqueue($directory)
      $entries = [Collections.Generic.List[string]]::new()
      $files = [Collections.Generic.List[string]]::new()
      $directories = [Collections.Generic.List[string]]::new()
      while ($pending.Count) {
        foreach ($entry in [IO.Directory]::EnumerateFileSystemEntries($pending.Dequeue())) {
          $path = localPath $entry
          $attributes = [IO.File]::GetAttributes($path)
          if (($attributes -band [IO.FileAttributes]::Directory) -ne 0) {
            if (![IO.Directory]::Exists($path)) { failContext 'UnsafePath' }
            projectionOrdinaryPath $path $true
            $directories.Add($path)
            $entries.Add('D|' + $path); $pending.Enqueue($path)
          } else {
            $null = projectionPin $path
            $entries.Add('F|' + $path); $files.Add($path)
          }
        }
      }
      $entries.Sort([StringComparer]::OrdinalIgnoreCase)
      $files.Sort([StringComparer]::OrdinalIgnoreCase)
      $directories.Sort([StringComparer]::OrdinalIgnoreCase)
      $fingerprint = [string]::Join([string][char]0, $entries.ToArray())
      if ($projectionTrees.ContainsKey($directory) -and
        ![string]::Equals($projectionTrees[$directory], $fingerprint, [StringComparison]::Ordinal)) {
        failContext 'ObservationChanged'
      }
      $projectionTrees[$directory] = $fingerprint
      $filePins = @($files.ToArray() | ForEach-Object {
          $pin = projectionPin $_
          [pscustomobject][ordered]@{ Path = $pin.Path; SHA256 = $pin.SHA256; Length = $pin.Length }
        })
      $directoryPins = @($directories.ToArray() | ForEach-Object { [pscustomobject][ordered]@{ Path = $_ } })
      $projectionDirectoryPins[$directory] = [pscustomobject][ordered]@{ Path = $directory; Exists = $true; Files = $filePins; Directories = $directoryPins }
      return $files.ToArray()
    }
    function projectionRoutes([object[]]$Entries, [bool]$StableView) {
      # Validate both the inactive common main route and the exact active linked
      # route. Included-file/transitive, wildcard and duplicate routes are unsafe.
      $commonRoutes = [Collections.Generic.List[object]]::new()
      $linkedRoutes = [Collections.Generic.List[object]]::new()
      $observed = [Collections.Generic.List[object]]::new()
      foreach ($entry in @($Entries | Where-Object { $_.Key -match '^include(?:if\..+)?\.path$' })) {
        if ($entry.Key -notmatch '^includeif\.(.+)\.path$') { failContext 'UnsafeIncludeRoute' }
        $entryCondition = $Matches[1]
        $includePath = configValuePath $entry.Value $entry.OriginPath
        if (samePath $entry.OriginPath $commonConfig) {
          if (!(samePath $entryCondition $mainCondition) -or !(samePath $includePath $stableCanonical)) { failContext 'UnsafeIncludeRoute' }
          $commonRoutes.Add($entry)
          $applies = $StableView
        } elseif (!$StableView -and (samePath $entry.OriginPath $overlay)) {
          if (!(samePath $entryCondition $condition) -or
            (!(samePath $includePath $assets[0].Path) -and !(samePath $includePath $stableCanonical))) { failContext 'UnsafeIncludeRoute' }
          $linkedRoutes.Add($entry)
          $applies = $true
        } else { failContext 'UnsafeIncludeRoute' }
        $null = snapshotFile $includePath
        $observed.Add([pscustomobject][ordered]@{ Condition = $entryCondition; OriginPath = $entry.OriginPath; TargetPath = $includePath; AppliesToTarget = $applies })
      }
      if ($commonRoutes.Count -ne 1 -or $linkedRoutes.Count -gt 1) { failContext 'UnsafeIncludeRoute' }
      $extensions = @($Entries | Where-Object Key -eq 'extensions.worktreeconfig')
      if ($extensions.Count -ne 1 -or $extensions[0].Value -cne 'true' -or
        !(samePath $extensions[0].OriginPath $commonConfig)) { failContext 'MissingPrerequisite' }
      $hooks = @($Entries | Where-Object Key -eq 'core.hookspath')
      $templates = @($Entries | Where-Object Key -eq 'commit.template')
      $commonHooks = @($hooks | Where-Object { samePath $_.OriginPath $commonConfig })
      $commonTemplates = @($templates | Where-Object { samePath $_.OriginPath $commonConfig })
      if ($commonHooks.Count -ne 1 -or $commonTemplates.Count -ne 1 -or
        !(samePath (configValuePath $commonHooks[0].Value $commonConfig) $stableHooks) -or
        !(samePath (configValuePath $commonTemplates[0].Value $commonConfig) $stableTemplate)) { failContext 'UnsafeIncludeRoute' }
      $activeRoot = $stableRoot
      $activeConfig = $stableCanonical
      $expectedOrigin = $commonConfig
      if (!$StableView -and $linkedRoutes.Count) {
        $activeConfig = configValuePath $linkedRoutes[0].Value $overlay
        $activeRoot = if (samePath $activeConfig $stableCanonical) { $stableRoot } else { $selectedRoot }
        $expectedOrigin = $overlay
        $overlayHooks = @($hooks | Where-Object { samePath $_.OriginPath $overlay })
        $overlayTemplates = @($templates | Where-Object { samePath $_.OriginPath $overlay })
        if ($overlayHooks.Count -ne 1 -or $overlayTemplates.Count -ne 1) { failContext 'UnsafeIncludeRoute' }
        if ([Array]::IndexOf($Entries, $linkedRoutes[0]) -gt [Array]::IndexOf($Entries, $overlayHooks[0]) -or
          [Array]::IndexOf($Entries, $linkedRoutes[0]) -gt [Array]::IndexOf($Entries, $overlayTemplates[0])) { failContext 'UnsafeIncludeRoute' }
      } elseif (!$StableView -and @($Entries | Where-Object {
            (samePath $_.OriginPath $overlay) -and $_.Key -match '^(core\.hookspath|commit\.template|include)'
          }).Count) { failContext 'UnsafeIncludeRoute' }
      foreach ($entry in @($hooks) + @($templates)) {
        if (!(samePath $entry.OriginPath $commonConfig) -and !(samePath $entry.OriginPath $activeConfig) -and
          !(!$StableView -and $linkedRoutes.Count -and (samePath $entry.OriginPath $overlay))) { failContext 'UnsafeIncludeRoute' }
      }
      $lastHook = $hooks[-1]; $lastTemplate = $templates[-1]
      $observedHooks = configValuePath $lastHook.Value $lastHook.OriginPath
      $observedTemplate = configValuePath $lastTemplate.Value $lastTemplate.OriginPath
      if (!(samePath $lastHook.OriginPath $expectedOrigin) -or !(samePath $lastTemplate.OriginPath $expectedOrigin) -or
        !(samePath $observedHooks (localPath ([IO.Path]::Combine($activeRoot, $hookSubpath)))) -or
        !(samePath $observedTemplate (localPath ([IO.Path]::Combine($activeRoot, $templateSubpath))))) { failContext 'UnsafeIncludeRoute' }
      $state = if (!$StableView -and !$linkedRoutes.Count) { 'SafeUnconfiguredLinked' }
               elseif (samePath $activeRoot $stableRoot) { 'AlreadyDesired' } else { 'ProjectionRequired' }
      return [pscustomobject][ordered]@{ CurrentRouteState = $state; Includes = $observed.ToArray(); Hooks = $observedHooks; Template = $observedTemplate }
    }
    function newSourceEndProjection {
      if (!$isSource -or !$target.IsLinkedWorktree -or $role -cne 'CanonicalSourceSprint' -or
        !(samePath $target.TopLevel (localPath $ExpectedSourceRoot)) -or
        (samePath $target.TopLevel $stable.TopLevel) -or !(samePath $stable.MainRoot $stableRoot)) { failContext 'InvalidProjectionTarget' }
      foreach ($binding in @(
          @{ Name = 'StableRoot'; Expected = $stable.TopLevel },
          @{ Name = 'StableGitDir'; Expected = $stable.GitDir },
          @{ Name = 'CommonGitDir'; Expected = $stable.CommonDir })) {
        $value = projectionField $ProjectionAuthority $binding.Name
        if ($value -isnot [string] -or !(samePath (localPath $value) $binding.Expected)) { failContext 'ProjectionAuthorityMismatch' }
      }
      $custodyValue = projectionField $ProjectionAuthority 'ReceiptCustodyRoot'
      if ($custodyValue -isnot [string]) { failContext 'ProjectionAuthorityRequired' }
      $custodyRoot = localPath $custodyValue
      if ($custodyRoot.IndexOf('/_generated/', [StringComparison]::OrdinalIgnoreCase) -lt 0 -or
        ![IO.Directory]::Exists($custodyRoot)) { failContext 'MissingPrerequisite' }
      projectionOrdinaryPath $custodyRoot $true
      $null = projectionHookFiles $hooksPath
      $stableHookFiles = @(projectionHookFiles $stableHooks)
      $expectedAssets = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
      $null = $expectedAssets.Add($stableCanonical); $null = $expectedAssets.Add($stableTemplate)
      foreach ($path in $stableHookFiles) { $null = $expectedAssets.Add($path) }
      $authorityPins = @(projectionField $ProjectionAuthority 'StableAssetPins')
      $stableAssets = [Collections.Generic.List[object]]::new()
      $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
      foreach ($binding in $authorityPins) {
        $pathValue = projectionField $binding 'Path'; $hashValue = projectionField $binding 'SHA256'
        if ($pathValue -isnot [string] -or $hashValue -isnot [string] -or $hashValue -notmatch '^[0-9a-fA-F]{64}\z') { failContext 'ProjectionAuthorityMismatch' }
        $path = localPath $pathValue
        if (!$seen.Add($path) -or (!$expectedAssets.Contains($path) -and !(samePath $path ($stableRoot + '/.gitattributes')))) { failContext 'ProjectionAuthorityMismatch' }
        $pin = projectionPin $path
        if (![string]::Equals($pin.SHA256, $hashValue, [StringComparison]::OrdinalIgnoreCase)) { failContext 'ProjectionAuthorityMismatch' }
        $stableAssets.Add($pin)
      }
      foreach ($path in $expectedAssets) { if (!$seen.Contains($path)) { failContext 'ProjectionAuthorityRequired' } }
      # Optional rendered caches are watched, never selected as projection assets.
      foreach ($path in @(($selectedRoot + '/.gitconfig.shared'), ($stableRoot + '/.gitconfig.shared'), ($stableRoot + '/.gitattributes'))) { $null = snapshotFile $path $false }
      foreach ($path in @(($targetRoot + '/.git'), ($target.GitDir + '/gitdir'), ($target.GitDir + '/commondir'))) { $null = snapshotFile $path }
      $stableConfig = @(readContextConfig $stableRoot)
      $projectionConfigWatch[$stableRoot] = Microsoft.PowerShell.Utility\ConvertTo-Json -InputObject $stableConfig -Depth 6 -Compress
      $null = projectionRoutes $stableConfig $true
      $observed = projectionRoutes $config $false
      $projectionConfigPins = [Collections.Generic.List[object]]::new()
      foreach ($pin in $configPins) {
        # X066 only permits an absent mutation target. Other absent optional
        # metadata is watched internally; fresh resolution detects appearance.
        if ($pin.Exists -or (samePath $pin.Path $overlay)) { $projectionConfigPins.Add((projectionPin $pin.Path (samePath $pin.Path $commonConfig))) }
      }
      $workspacePins = @($unique | ForEach-Object { projectionPin $_ })
      $protectedPins = @($watchOrder.ToArray() | Where-Object { !(samePath $_ $overlay) -and $watch[$_].Exists } | ForEach-Object { projectionPin $_ })
      $projectionPlan = [pscustomobject][ordered]@{
        SchemaVersion = 2; Mode = 'SourceEndProjection'; ContextMode = 'SourceEndProjection'
        ValidationStatus = 'ValidatedReadOnlyPlan'; Role = 'CanonicalSourceSprint'
        Target = [pscustomobject][ordered]@{ TopLevel = $target.TopLevel; GitDir = $target.GitDir; CommonDir = $target.CommonDir; IsLinkedWorktree = $true; RegisteredWorktreePath = $target.TopLevel; WorktreeConfigPath = $overlay; WorktreeConfigEnabled = $true }
        Route = [pscustomobject][ordered]@{ Condition = $condition; ConfigPath = $overlay; IncludeTarget = $stableCanonical; HooksTarget = $stableHooks; TemplateTarget = $stableTemplate; CanRenderConsumerFiles = $false; ExpectedOrder = 'include-before-absolute-hooks-template' }
        Workspaces = $workspacePins; AssetPins = $stableAssets.ToArray(); ConfigPins = $projectionConfigPins.ToArray(); ProtectedPins = $protectedPins
        DirectoryPins = @($projectionDirectoryPins[$hooksPath], $projectionDirectoryPins[$stableHooks])
        CurrentRouteState = $observed.CurrentRouteState; ObservedContext = $observed
        HooksDirectory = $stableHooks
        ReceiptCustodyRoot = $custodyRoot
      }
      return [pscustomobject][ordered]@{ SharedRoot = $stableRoot; GitConfig = $stableCanonical; HooksPath = $stableHooks; CommitTemplate = $stableTemplate; CanRenderConsumerFiles = $false; Plan = $projectionPlan }
    }

    # Refuse implicit logging autoload/sinks and injected native context. The
    # separately admitted fixture harness supplies a non-emitting scoped logger.
    $logger = @(Microsoft.PowerShell.Core\Get-Command -Name Write-PSFMessage -ListImported -CommandType Function -ErrorAction SilentlyContinue)
    if ($logger.Count -eq 0) {
      $logger = @(Microsoft.PowerShell.Core\Get-Command -Name Write-PSFMessage -ListImported -CommandType Cmdlet -ErrorAction SilentlyContinue)
    }
    if ($logger.Count -ne 1) { failContext 'LoggingDependencyUnbound' }
    $logger = $logger[0]
    foreach ($name in @('Where-Object', 'ForEach-Object')) {
      $command = @(Microsoft.PowerShell.Core\Get-Command -Name $name -ListImported -ErrorAction SilentlyContinue)
      if ($command.Count -ne 1 -or $command[0].CommandType -ne 'Cmdlet' -or $command[0].ModuleName -ne 'Microsoft.PowerShell.Core') { failContext 'InvalidInput' }
    }
    foreach ($name in @('ConvertFrom-Json', 'ConvertTo-Json')) {
      $command = @(Microsoft.PowerShell.Core\Get-Command -Name ('Microsoft.PowerShell.Utility\' + $name) -ListImported -ErrorAction SilentlyContinue)
      if ($command.Count -ne 1 -or $command[0].CommandType -ne 'Cmdlet') { failContext 'MissingPrerequisite' }
    }
    foreach ($entry in [Environment]::GetEnvironmentVariables().Keys) {
      if ([string]$entry -match '^(?i:GIT_(?:DIR|WORK_TREE|COMMON_DIR|CONFIG|CONFIG_PARAMETERS|CONFIG_COUNT|CONFIG_KEY_\d+|CONFIG_VALUE_\d+|INDEX_FILE|OBJECT_DIRECTORY|ALTERNATE_OBJECT_DIRECTORIES|NAMESPACE|CEILING_DIRECTORIES))$') {
        failContext 'InvalidInput'
      }
    }
    $gitExecutable = [IO.Path]::Combine([Environment]::GetFolderPath('ProgramFiles'), 'Git', 'cmd', 'git.exe')
    if (![IO.File]::Exists($gitExecutable)) { failContext 'MissingPrerequisite' }
    $rootPath = localPath $GitRoot
    if (![IO.Directory]::Exists($rootPath)) { failContext 'MissingPrerequisite' }
    $repoName = safeRelative $SharedVSCodeRepoName $true
    $hookSubpath = safeRelative $SharedHooksSubPath
    $templateSubpath = safeRelative $CommitTemplateRelativePath
    if ($overrideRequested) { $null = safeRelative $RequestedTemplateRef $true }
    if ($projectionRequested -and ([string]::IsNullOrWhiteSpace($ExpectedSourceRoot) -or $null -eq $ProjectionAuthority)) { failContext 'ProjectionAuthorityRequired' }
    if ($projectionRequested) {
      $metadataCommands = @(Microsoft.PowerShell.Core\Get-Command -Name Microsoft.PowerShell.Management\Get-Item -ListImported -CommandType Cmdlet -ErrorAction SilentlyContinue)
      if ($metadataCommands.Count -ne 1) { failContext 'MissingPrerequisite' }
      $projectionMetadataReader = $metadataCommands[0]
    }
    if (!$WorkspaceFiles.Count) { failContext 'InvalidInput' }
  }
  process {
    try {
      if ($projectionRequested) { invokeContextLogger 'Validating SourceEndProjection read-only context' }
      else { invokeContextLogger 'Validating Normal read-only context' }
      $workspaces = [Collections.Generic.List[object]]::new()
      $unique = [Collections.Generic.List[string]]::new()
      $workspaceSeen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
      $originalRef = $null
      $profileLabel = $null
      $targetRoot = $null
      foreach ($inputFile in $WorkspaceFiles) {
        $workspace = localPath $inputFile
        if (![string]::Equals([IO.Path]::GetExtension($workspace), '.code-workspace', $comparison)) { failContext 'UnsafePath' }
        $null = snapshotFile $workspace
        try { $json = Microsoft.PowerShell.Utility\ConvertFrom-Json -InputObject ([IO.File]::ReadAllText($workspace)) -AsHashtable -NoEnumerate -ErrorAction Stop }
        catch { failContext 'InvalidWorkspaceJson' }
        if ($json -isnot [Collections.IDictionary] -or !$json.Contains('settings') -or $json.settings -isnot [Collections.IDictionary]) { failContext 'MissingWorkspaceSetting' }
        $storedRef = $json.settings['atap.sharedVSCode.templateRef']
        if ($storedRef -isnot [string] -or [string]::IsNullOrWhiteSpace($storedRef)) { failContext 'MissingWorkspaceSetting' }
        $null = safeRelative $storedRef $true
        $profileValue = $json.settings['atap.sharedVSCode.profile']
        if ($null -ne $profileValue -and $profileValue -isnot [string]) { failContext 'InvalidWorkspaceJson' }
        if ([string]::IsNullOrWhiteSpace($profileValue)) { $profileValue = 'default' }
        $parent = localPath ([IO.Path]::GetDirectoryName($workspace))
        if ($null -eq $targetRoot) { $targetRoot = $parent; $originalRef = $storedRef; $profileLabel = $profileValue }
        elseif (!(samePath $targetRoot $parent) -or $originalRef -cne $storedRef -or $profileLabel -cne $profileValue) { failContext 'WorkspaceConflict' }
        if ($workspaceSeen.Add($workspace)) { $unique.Add($workspace) }
        $workspaces.Add([pscustomobject]@{ Path = $workspace })
      }
      $effectiveRef = if ($overrideRequested) { $RequestedTemplateRef } else { $originalRef }
      $stableRoot = localPath ([IO.Path]::Combine($rootPath, $repoName))
      $selectedRoot = if ($effectiveRef -eq 'main') { $stableRoot } else { localPath ([IO.Path]::Combine($rootPath, $effectiveRef)) }
      $target = registeredIdentity $targetRoot
      $stable = registeredIdentity $stableRoot
      $selected = registeredIdentity $selectedRoot
      if ($stable.IsLinkedWorktree -or !(samePath $stable.CommonDir $selected.CommonDir)) { failContext 'SourceAuthorityMismatch' }
      $isSource = samePath $target.CommonDir $stable.CommonDir
      if ($isSource -and !(samePath $target.TopLevel $selected.TopLevel)) { failContext 'SourceSelfSelectionRequired' }
      $role = if ($isSource) { if ($target.IsLinkedWorktree) { 'CanonicalSourceSprint' } else { 'CanonicalSourceStable' } }
              else { if ($target.IsLinkedWorktree) { 'DownstreamSprint' } else { 'DownstreamStable' } }
      $assets = [Collections.Generic.List[object]]::new()
      $assetMap = [ordered]@{ GitConfig = '.gitconfig'; GitAttributes = '.gitattributes'; CommitTemplate = $templateSubpath }
      foreach ($kind in $assetMap.Keys) {
        $pin = snapshotFile ([IO.Path]::Combine($selectedRoot, $assetMap[$kind]))
        $assets.Add([pscustomobject][ordered]@{ Kind = $kind; Path = $pin.Path; Sha256 = $pin.Sha256 })
      }
      $hooksPath = localPath ([IO.Path]::Combine($selectedRoot, $hookSubpath))
      $stableHooks = localPath ([IO.Path]::Combine($stableRoot, $hookSubpath))
      $stableTemplate = localPath ([IO.Path]::Combine($stableRoot, $templateSubpath))
      if (![IO.Directory]::Exists($hooksPath) -or ![IO.Directory]::Exists($stableHooks)) { failContext 'MissingPrerequisite' }
      $null = snapshotFile $stableTemplate
      $stableCanonical = localPath ([IO.Path]::Combine($stableRoot, '.gitconfig'))
      $null = snapshotFile $stableCanonical
      $commonConfig = localPath ($target.CommonDir + '/config')
      $overlay = localPath ($target.GitDir + '/config.worktree')
      $configPins = [Collections.Generic.List[object]]::new()
      $configPins.Add((snapshotFile $commonConfig))
      $configPins.Add((snapshotFile $overlay $false))
      foreach ($authority in @($stable, $selected)) {
        foreach ($authorityConfig in @(($authority.CommonDir + '/config'), ($authority.GitDir + '/config.worktree'))) {
          if (!@($configPins | Where-Object { samePath $_.Path $authorityConfig }).Count) {
            $configPins.Add((snapshotFile $authorityConfig ($authorityConfig.EndsWith('/config'))))
          }
        }
      }
      $config = @(readContextConfig $targetRoot)
      $extension = @($config | Where-Object { $_.Key -eq 'extensions.worktreeconfig' })
      if ($extension.Count -ne 1 -or $extension[0].Value -cne 'true' -or !(samePath $extension[0].OriginPath $commonConfig)) { failContext 'MissingPrerequisite' }
      $mainCondition = 'gitdir/i:' + $target.CommonDir
      $condition = 'gitdir/i:' + $target.GitDir
      if ($projectionRequested) {
        $effectiveGitContext = newSourceEndProjection
        $plan = $effectiveGitContext.Plan
      } else {
      $stableInclude = if ($isSource) { $stableCanonical } else { localPath ($target.MainRoot + '/.gitconfig.shared') }
      $desiredInclude = if ($isSource) { $assets[0].Path } else { localPath ($targetRoot + '/.gitconfig.shared') }
      $null = snapshotFile $stableInclude
      if (!$isSource -and !(renderMatches $stableInclude $stableCanonical)) { failContext 'UnsafeIncludeRoute' }
      $includes = [Collections.Generic.List[object]]::new()
      $commonIncludes = [Collections.Generic.List[object]]::new()
      $targetIncludes = [Collections.Generic.List[object]]::new()
      foreach ($entry in @($config | Where-Object { $_.Key -match '^include(?:if\..+)?\.path$' })) {
        if ($entry.Key -notmatch '^includeif\.(.+)\.path$') { failContext 'UnsafeIncludeRoute' }
        $entryCondition = $Matches[1]
        if (!$entryCondition.StartsWith('gitdir/i:', [StringComparison]::Ordinal)) { failContext 'UnsafeIncludeRoute' }
        $includePath = configValuePath $entry.Value $entry.OriginPath
        if (samePath $entry.OriginPath $commonConfig) {
          if (!(samePath $entryCondition $mainCondition) -or !(samePath $includePath $stableInclude)) { failContext 'UnsafeIncludeRoute' }
          $commonIncludes.Add($entry)
          $applies = !$target.IsLinkedWorktree
        } elseif ($target.IsLinkedWorktree -and (samePath $entry.OriginPath $overlay)) {
          if (!(samePath $entryCondition $condition) -or !(samePath $includePath $desiredInclude)) { failContext 'UnsafeIncludeRoute' }
          $targetIncludes.Add($entry)
          $applies = $true
        } else { failContext 'UnsafeIncludeRoute' }
        if ($applies) { $null = snapshotFile $includePath }
        $includes.Add([pscustomobject][ordered]@{ Condition = $entryCondition; OriginPath = $entry.OriginPath; TargetPath = $includePath; AppliesToTarget = $applies })
      }
      if (!$commonIncludes.Count) { failContext 'MissingPrerequisite' }
      if ($commonIncludes.Count -ne 1 -or $targetIncludes.Count -gt 1) { failContext 'UnsafeIncludeRoute' }
      $hookEntries = @($config | Where-Object { $_.Key -eq 'core.hookspath' })
      $templateEntries = @($config | Where-Object { $_.Key -eq 'commit.template' })
      $commonHooks = @($hookEntries | Where-Object { samePath $_.OriginPath $commonConfig })
      $commonTemplates = @($templateEntries | Where-Object { samePath $_.OriginPath $commonConfig })
      if ($commonHooks.Count -ne 1 -or $commonTemplates.Count -ne 1 -or
        !(samePath (configValuePath $commonHooks[0].Value $commonConfig) $stableHooks) -or
        !(samePath (configValuePath $commonTemplates[0].Value $commonConfig) $stableTemplate)) { failContext 'UnsafeIncludeRoute' }
      # Only approved direct/common, selected overlay and active own include may
      # provide context values. Unknown origins never become managed by resemblance.
      foreach ($entry in @($hookEntries) + @($templateEntries)) {
        $allowed = (samePath $entry.OriginPath $commonConfig) -or
          ($target.IsLinkedWorktree -and (samePath $entry.OriginPath $overlay)) -or
          (samePath $entry.OriginPath $(if ($target.IsLinkedWorktree) { $desiredInclude } else { $stableInclude }))
        if (!$allowed) { failContext 'UnsafeIncludeRoute' }
      }
      $lastHook = $hookEntries[-1]
      $lastTemplate = $templateEntries[-1]
      $observedHook = configValuePath $lastHook.Value $lastHook.OriginPath
      $observedTemplate = configValuePath $lastTemplate.Value $lastTemplate.OriginPath
      $overlayContext = @($config | Where-Object { (samePath $_.OriginPath $overlay) -and $_.Key -match '^(core\.hookspath|commit\.template|include)' })
      $destinations = @()
      if (!$isSource) {
        $destination = snapshotFile $desiredInclude $false
        $destinations = @([pscustomobject][ordered]@{ Path = $destination.Path; Exists = $destination.Exists; Sha256 = $destination.Sha256; Active = (!$target.IsLinkedWorktree -or $targetIncludes.Count -eq 1); Ownership = 'Unasserted' })
      }
      $expectedOrigin = if ($target.IsLinkedWorktree) { $overlay } else { $commonConfig }
      $desiredValues = (samePath $observedHook $hooksPath) -and (samePath $observedTemplate $assets[2].Path)
      $desiredOrigins = (samePath $lastHook.OriginPath $expectedOrigin) -and (samePath $lastTemplate.OriginPath $expectedOrigin)
      if ($target.IsLinkedWorktree -and !$overlayContext.Count -and !$targetIncludes.Count) {
        if (!(samePath $lastHook.OriginPath $commonConfig) -or !(samePath $lastTemplate.OriginPath $commonConfig)) { failContext 'UnsafeIncludeRoute' }
        $state = 'SafeUnconfiguredLinked'
      } else {
        if ($target.IsLinkedWorktree -and ($targetIncludes.Count -ne 1 -or @($overlayContext | Where-Object Key -eq 'core.hookspath').Count -ne 1 -or @($overlayContext | Where-Object Key -eq 'commit.template').Count -ne 1)) { failContext 'UnsafeIncludeRoute' }
        if (!$desiredValues) {
          # A held transition is only an otherwise exact same-authority original
          # context; all other differing values are unknown/unsafe.
          $oldRoot = if ($originalRef -eq 'main') { $stableRoot } else { localPath ([IO.Path]::Combine($rootPath, $originalRef)) }
          $old = registeredIdentity $oldRoot
          if (!(samePath $old.CommonDir $stable.CommonDir) -or
            !(samePath $observedHook (localPath ([IO.Path]::Combine($oldRoot, $hookSubpath)))) -or
            !(samePath $observedTemplate (localPath ([IO.Path]::Combine($oldRoot, $templateSubpath))))) { failContext 'UnsafeIncludeRoute' }
          failContext 'TransitionPlanningHeld'
        }
        if (!$desiredOrigins) { failContext 'UnsafeIncludeRoute' }
        # Require include before the final absolute context overrides.
        $activeIncludeEntry = if ($target.IsLinkedWorktree) { $targetIncludes[0] } else { $commonIncludes[0] }
        if ([Array]::IndexOf($config, $activeIncludeEntry) -gt [Array]::IndexOf($config, $lastHook) -or
          [Array]::IndexOf($config, $activeIncludeEntry) -gt [Array]::IndexOf($config, $lastTemplate)) { failContext 'UnsafeIncludeRoute' }
        if (!$isSource -and !(renderMatches $desiredInclude $assets[0].Path)) { failContext 'UnsafeIncludeRoute' }
        $state = 'AlreadyDesired'
      }
      $workspacePins = @($unique | ForEach-Object { [pscustomobject][ordered]@{ Path = $_; Sha256 = $watch[$_].Sha256 } })
      $plan = [pscustomobject][ordered]@{
        SchemaVersion = 2
        ContextMode = 'Normal'
        ValidationStatus = 'ValidatedReadOnlyPlan'
        WorkspaceGroup = $unique.ToArray()
        WorkspacePins = $workspacePins
        Target = [pscustomobject][ordered]@{ TopLevel = $target.TopLevel; GitDir = $target.GitDir; CommonDir = $target.CommonDir; IsLinkedWorktree = $target.IsLinkedWorktree; RegisteredWorktreePath = $target.TopLevel; WorktreeConfigPath = $overlay; WorktreeConfigEnabled = $true }
        Role = $role
        SelectedAuthority = [pscustomobject][ordered]@{ StableSourceRoot = $stableRoot; SourceRoot = $selectedRoot; SourceGitDir = $selected.GitDir; SourceCommonDir = $selected.CommonDir; TemplateRef = $effectiveRef }
        AssetPins = $assets.ToArray()
        HooksDirectory = $hooksPath
        Route = [pscustomobject][ordered]@{ Condition = $condition; ConfigPath = $expectedOrigin; IncludeTarget = $desiredInclude; HooksTarget = $hooksPath; TemplateTarget = $assets[2].Path; CanRenderConsumerFiles = !$isSource; ExpectedOrder = 'include-before-absolute-hooks-template' }
        ObservedIncludes = $includes.ToArray()
        ConfigPins = $configPins.ToArray()
        CurrentRouteState = $state
        ObservedContext = [pscustomobject][ordered]@{ Includes = $includes.ToArray(); Hooks = [pscustomobject]@{ Value = $observedHook; OriginPath = $lastHook.OriginPath }; Template = [pscustomobject]@{ Value = $observedTemplate; OriginPath = $lastTemplate.OriginPath }; TargetOverridePresent = ($overlayContext.Count -gt 0); BaselineOnly = ($state -eq 'SafeUnconfiguredLinked') }
        DestinationPins = $destinations
      }
      }
      invokeContextLogger 'Rechecking read-only context'
      try {
        foreach ($knownRoot in @($identityWatch.Keys)) { $null = registeredIdentity $knownRoot }
        $freshConfig = @(readContextConfig $targetRoot)
        $beforeConfig = Microsoft.PowerShell.Utility\ConvertTo-Json -InputObject $config -Depth 6 -Compress
        $afterConfig = Microsoft.PowerShell.Utility\ConvertTo-Json -InputObject $freshConfig -Depth 6 -Compress
        if ($beforeConfig -cne $afterConfig) { failContext 'ObservationChanged' }
        if ($projectionRequested) {
          foreach ($knownRoot in @($projectionConfigWatch.Keys)) {
            $observedConfig = @(readContextConfig $knownRoot)
            $fresh = Microsoft.PowerShell.Utility\ConvertTo-Json -InputObject $observedConfig -Depth 6 -Compress
            if (![string]::Equals($projectionConfigWatch[$knownRoot], $fresh, [StringComparison]::Ordinal)) { failContext 'ObservationChanged' }
          }
          foreach ($directory in @($projectionTrees.Keys)) { $null = projectionHookFiles $directory }
          projectionOrdinaryPath $plan.ReceiptCustodyRoot $true
        }
      } catch { failContext 'ObservationChanged' }
      foreach ($knownPath in $watchOrder.ToArray()) {
        # The first snapshot is retained; appearance, disappearance, replacement
        # or a hash/type/path change is never silently accepted as a fresh plan.
        try { $null = snapshotFile $knownPath $false }
        catch { failContext 'ObservationChanged' }
      }
      if (![IO.Directory]::Exists((localPath $hooksPath))) { failContext 'ObservationChanged' }
      if ($projectionRequested) {
        foreach ($pin in @($plan.Workspaces) + @($plan.AssetPins) + @($plan.ProtectedPins) + @($plan.ConfigPins)) {
          if ($pin.Existence) { projectionOrdinaryPath $pin.Path $false }
        }
      }
      $results = [Collections.Generic.List[object]]::new()
      foreach ($workspace in $workspaces) {
        $result = [ordered]@{
          WorkspaceFile = $workspace.Path; TemplateRef = $effectiveRef; Profile = $profileLabel
          SharedRoot = $selectedRoot; GitConfig = $assets[0].Path; GitAttributes = $assets[1].Path
          CommitTemplate = $assets[2].Path; HooksPath = $hooksPath
          OriginalTemplateRef = $originalRef; Plan = $plan
        }
        if ($projectionRequested) {
          $result['ContextMode'] = 'SourceEndProjection'
          $result['CanRenderConsumerFiles'] = $false
          $result['EffectiveGitContext'] = $effectiveGitContext
        }
        $results.Add([pscustomobject]$result)
      }
      # The ONLY success-stream output boundary in the public resolver.
      return $results.ToArray()
    } catch {
      if ($_.FullyQualifiedErrorId -like 'SharedVSCodeContext.*') { throw }
      failContext 'InvalidInput'
    }
  }
  end { }
}
