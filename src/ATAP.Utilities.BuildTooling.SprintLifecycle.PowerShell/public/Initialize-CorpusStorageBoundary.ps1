function Initialize-CorpusStorageBoundary {
  <#
  .SYNOPSIS
    Provisions the immutable corpus roots and mutable gather-record staging ACL boundary.

  .DESCRIPTION
    Validates three absolute, disjoint NTFS roots on one volume, rejects reparse traversal,
    creates only a missing leaf directory whose parent already exists, and applies protected
    Windows ACLs. Immutable roots grant the capture identity create-and-read rights without
    modification or deletion; staging grants capture Modify. SYSTEM, Administrators, and
    the expiry identity retain recovery or expiry FullControl. A partial failure restores
    exact captured SDDL and removes only empty leaf directories created by this invocation.

  .PARAMETER CorpusAIConversationPath
    Immutable conversation root, or the exact CorpusAIConversationPath setting when omitted.

  .PARAMETER CorpusGatherRecordsPath
    Immutable gather-record root, or the exact CorpusGatherRecordsPath setting when omitted.

  .PARAMETER CorpusGatherRecordsStagingPath
    Mutable staging root, or the exact CorpusGatherRecordsStagingPath setting when omitted.

  .PARAMETER CaptureIdentity
    One explicit, resolvable, non-privileged Windows account allowed to capture content.

  .PARAMETER ExpiryIdentity
    A distinct explicit Windows account authorized to expire sealed content.

  .OUTPUTS
    PSCustomObject containing validation, per-root before/after SDDL, and rollback results.

  .EXAMPLE
    Initialize-CorpusStorageBoundary -CorpusAIConversationPath 'D:\Artifacts\CorpusAIConversation' `
      -CorpusGatherRecordsPath 'D:\Artifacts\CorpusGatherRecords' `
      -CorpusGatherRecordsStagingPath 'D:\Artifacts\CorpusGatherRecordsStaging' `
      -CaptureIdentity 'CONTOSO\CorpusCapture' -ExpiryIdentity 'CONTOSO\CorpusExpiry'

  .NOTES
    Task 15.191.c ACL boundary. Live host application remains a separate HITL gate,
    including validation of the actual caller's privileges and effective access. This
    function does not invent or grant a separate sealer identity.

  .LINK
    Corpus-AI-Conversation-Durability-Decision-Packet.md#153-sealing-and-acl-boundary
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory = $false)][AllowNull()][AllowEmptyString()][object]$CorpusAIConversationPath,
    [Parameter(Mandatory = $false)][AllowNull()][AllowEmptyString()][object]$CorpusGatherRecordsPath,
    [Parameter(Mandatory = $false)][AllowNull()][AllowEmptyString()][object]$CorpusGatherRecordsStagingPath,
    [Parameter(Mandatory = $true)][AllowNull()][AllowEmptyString()][object]$CaptureIdentity,
    [Parameter(Mandatory = $true)][AllowNull()][AllowEmptyString()][object]$ExpiryIdentity
  )

  begin {
    $fn = 'Initialize-CorpusStorageBoundary'
    $mn = 'ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
      -Message 'Beginning corpus storage boundary initialization.' -Tag 'CorpusAcl'

    if (-not (Get-Command Set-CorpusFileSystemAcl -ErrorAction SilentlyContinue)) {
      . (Join-Path (Split-Path -Parent $PSScriptRoot) 'private\Set-CorpusFileSystemAcl.ps1')
    }
    $resolveRoot = {
      param([string]$Name, [object]$Value, [bool]$Bound)
      if (-not $Bound) {
        if (-not (Get-Command Get-PVal -ErrorAction SilentlyContinue)) {
          throw "Get-PVal is unavailable, so $Name cannot be resolved."
        }
        $Value = Get-PVal -ParameterName $Name -originalPSBoundParameters @{} -dottedPath $Name
      }
      $values = @($Value)
      if ($values.Count -ne 1) { throw "$Name must resolve to exactly one path." }
      $text = if ($null -eq $values[0]) { $null } else { [string]$values[0] }
      if ([string]::IsNullOrWhiteSpace($text) -or -not [System.IO.Path]::IsPathFullyQualified($text)) {
        throw "$Name must resolve to one non-blank absolute path."
      }
      [System.IO.Path]::GetFullPath($text).TrimEnd('\', '/')
    }
    $hasReparse = { param($Item) ($Item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 }
  }

  process {
    $result = [ordered]@{ Ok = $false; WhatIf = [bool]$WhatIfPreference; Roots = @(); Rollback = @(); Failure = $null }
    $applied = [System.Collections.Generic.List[object]]::new()
    try {
      if (-not $IsWindows) { throw 'Corpus ACL provisioning is supported only on Windows.' }
      $specifications = @(
        [pscustomobject]@{ Name='CorpusAIConversationPath'; Value=$CorpusAIConversationPath; Kind='ImmutableDirectory' },
        [pscustomobject]@{ Name='CorpusGatherRecordsPath'; Value=$CorpusGatherRecordsPath; Kind='ImmutableDirectory' },
        [pscustomobject]@{ Name='CorpusGatherRecordsStagingPath'; Value=$CorpusGatherRecordsStagingPath; Kind='MutableStaging' }
      )
      foreach ($specification in $specifications) {
        $specification | Add-Member NoteProperty Path (& $resolveRoot $specification.Name $specification.Value `
            $PSBoundParameters.ContainsKey($specification.Name))
      }
      $volumeRoots = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase)
      foreach ($specification in $specifications) {
        $volumeRoot = [IO.Path]::GetPathRoot($specification.Path)
        if ([string]::IsNullOrWhiteSpace($volumeRoot)) {
          throw "Corpus root '$($specification.Path)' has no resolvable volume root."
        }
        [void]$volumeRoots.Add($volumeRoot)
      }
      if ($volumeRoots.Count -ne 1) {
        throw 'Corpus roots must reside on one volume so gather-record sealing can use an atomic move.'
      }
      for ($i = 0; $i -lt $specifications.Count; $i++) {
        for ($j = $i + 1; $j -lt $specifications.Count; $j++) {
          $relative = [IO.Path]::GetRelativePath($specifications[$i].Path, $specifications[$j].Path)
          $reverse = [IO.Path]::GetRelativePath($specifications[$j].Path, $specifications[$i].Path)
          if ($relative -eq '.' -or (-not [IO.Path]::IsPathFullyQualified($relative) -and
              $relative -ne '..' -and -not $relative.StartsWith("..$([IO.Path]::DirectorySeparatorChar)")) -or
              (-not [IO.Path]::IsPathFullyQualified($reverse) -and $reverse -ne '..' -and
              -not $reverse.StartsWith("..$([IO.Path]::DirectorySeparatorChar)"))) {
            throw "Corpus roots overlap: '$($specifications[$i].Path)' and '$($specifications[$j].Path)'."
          }
        }
      }
      foreach ($specification in $specifications) {
        $parent = Split-Path -Parent $specification.Path
        if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
          throw "Parent '$parent' must exist; only the corpus leaf is created."
        }
        $cursor = Get-Item -LiteralPath $parent -Force -ErrorAction Stop
        while ($null -ne $cursor) {
          if (& $hasReparse $cursor) { throw "Reparse traversal is prohibited at '$($cursor.FullName)'." }
          $cursor = $cursor.Parent
        }
        $driveFormat = ([IO.DriveInfo]::new([IO.Path]::GetPathRoot($specification.Path))).DriveFormat
        if ($driveFormat -ne 'NTFS') { throw "Root '$($specification.Path)' is on unsupported filesystem '$driveFormat'." }
        if (Test-Path -LiteralPath $specification.Path) {
          $leaf = Get-Item -LiteralPath $specification.Path -Force -ErrorAction Stop
          if (-not $leaf.PSIsContainer) { throw "Root '$($specification.Path)' is not a directory." }
          if (& $hasReparse $leaf) { throw "Corpus root '$($specification.Path)' is a reparse point." }
        }
        $plan = Set-CorpusFileSystemAcl -Path $specification.Path -BoundaryKind $specification.Kind `
          -CaptureIdentity $CaptureIdentity -ExpiryIdentity $ExpiryIdentity -PlanOnly -Confirm:$false
        $result.Roots += [pscustomobject][ordered]@{
          Name=$specification.Name; Path=$specification.Path; BoundaryKind=$specification.Kind
          ExistedBefore=(Test-Path -LiteralPath $specification.Path); Created=$false
          BeforeOwner=if (Test-Path -LiteralPath $specification.Path) { (Get-Acl -LiteralPath $specification.Path).Owner } else { $null }
          BeforeSddl=if (Test-Path -LiteralPath $specification.Path) { (Get-Acl -LiteralPath $specification.Path).Sddl } else { $null }
          DesiredSddl=$plan.DesiredSddl; AfterOwner=$null; AfterSddl=$null; Verified=$false
        }
      }
      if (-not $PSCmdlet.ShouldProcess(($specifications.Path -join ', '), 'Provision corpus storage ACL boundary')) {
        $result.Ok = $true
        return [pscustomobject]$result
      }
      foreach ($rootResult in $result.Roots) {
        if (-not $rootResult.ExistedBefore) {
          [IO.Directory]::CreateDirectory($rootResult.Path) | Out-Null
          $rootResult.Created = $true
          $createdAcl = Get-Acl -LiteralPath $rootResult.Path -ErrorAction Stop
          $rootResult.BeforeOwner = $createdAcl.Owner
          $rootResult.BeforeSddl = $createdAcl.GetSecurityDescriptorSddlForm(
            [System.Security.AccessControl.AccessControlSections]::All)
        }
        $applied.Add($rootResult)
        $aclResult = Set-CorpusFileSystemAcl -Path $rootResult.Path -BoundaryKind $rootResult.BoundaryKind `
          -CaptureIdentity $CaptureIdentity -ExpiryIdentity $ExpiryIdentity -Confirm:$false
        $rootResult.AfterOwner = $aclResult.AfterOwner
        $rootResult.AfterSddl = $aclResult.AfterSddl
        $rootResult.Verified = $aclResult.Verified
      }
      $result.Ok = $true
    } catch {
      $result.Failure = [pscustomobject][ordered]@{ Code='acl-boundary-failed'; Message=$_.Exception.Message }
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $_.Exception.Message -Tag 'CorpusAcl'
      foreach ($rootResult in @($applied | Select-Object -Last 100) | Sort-Object Path -Descending) {
        $rollback = [ordered]@{ Path=$rootResult.Path; Restored=$false; RemovedCreatedEmpty=$false; Error=$null }
        try {
          if ($rootResult.Created) {
            if (-not [string]::IsNullOrWhiteSpace($rootResult.BeforeSddl)) {
              Set-CorpusFileSystemAcl -Path $rootResult.Path -RestoreSddl $rootResult.BeforeSddl `
                -Confirm:$false | Out-Null
            }
            if ((Get-ChildItem -LiteralPath $rootResult.Path -Force -ErrorAction Stop).Count -eq 0) {
              [IO.Directory]::Delete($rootResult.Path, $false)
              $rollback.RemovedCreatedEmpty = $true
            } else { throw 'Newly created root is not empty; refusing removal.' }
          } else {
            Set-CorpusFileSystemAcl -Path $rootResult.Path -RestoreSddl $rootResult.BeforeSddl -Confirm:$false | Out-Null
            $rollback.Restored = $true
          }
        } catch { $rollback.Error = $_.Exception.Message }
        $result.Rollback += [pscustomobject]$rollback
      }
    }
    [pscustomobject]$result
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
      -Message 'Finished corpus storage boundary initialization.' -Tag 'CorpusAcl'
  }
}
