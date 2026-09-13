function Set-CorpusFileSystemAcl {
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [Parameter(Mandatory = $true, ParameterSetName = 'Apply')]
    [ValidateSet('ImmutableDirectory', 'MutableStaging', 'ImmutableArtifact')]
    [string]$BoundaryKind,

    [Parameter(Mandatory = $true, ParameterSetName = 'Apply')]
    [object]$CaptureIdentity,

    [Parameter(Mandatory = $true, ParameterSetName = 'Apply')]
    [object]$ExpiryIdentity,

    [Parameter(Mandatory = $true, ParameterSetName = 'Restore')]
    [AllowEmptyString()]
    [string]$RestoreSddl,

    [Parameter(Mandatory = $false, ParameterSetName = 'Apply')]
    [switch]$PlanOnly
  )

  begin {
    $fn = 'Set-CorpusFileSystemAcl'
    $mn = 'ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
      -Message 'Beginning corpus filesystem ACL operation.' -Tag 'CorpusAcl'

    $translateIdentity = {
      param([object]$Value, [string]$Name)
      $values = @($Value)
      if ($values.Count -ne 1 -or $null -eq $values[0] -or
          [string]::IsNullOrWhiteSpace([string]$values[0])) {
        throw "$Name must identify exactly one non-blank Windows account."
      }
      try {
        $sid = if ($values[0] -is [System.Security.Principal.SecurityIdentifier]) {
          $values[0]
        } elseif ([string]$values[0] -match '^S-\d(?:-\d+)+$') {
          [System.Security.Principal.SecurityIdentifier]::new([string]$values[0])
        } else {
          ([System.Security.Principal.NTAccount]::new([string]$values[0])).Translate(
            [System.Security.Principal.SecurityIdentifier])
        }
      } catch {
        throw "$Name '$Value' cannot be resolved to a Windows account SID: $($_.Exception.Message)"
      }
      try { [void]$sid.Translate([System.Security.Principal.NTAccount]) }
      catch { throw "$Name '$Value' cannot be resolved to a Windows account: $($_.Exception.Message)" }
      $sid
    }

    $addRule = {
      param(
        [System.Security.AccessControl.FileSystemSecurity]$Security,
        [System.Security.Principal.IdentityReference]$Identity,
        [System.Security.AccessControl.FileSystemRights]$Rights,
        [System.Security.AccessControl.InheritanceFlags]$Inheritance,
        [System.Security.AccessControl.PropagationFlags]$Propagation,
        [System.Security.AccessControl.AccessControlType]$Type =
          [System.Security.AccessControl.AccessControlType]::Allow
      )
      $rule = [System.Security.AccessControl.FileSystemAccessRule]::new(
        $Identity, $Rights, $Inheritance, $Propagation, $Type)
      [void]$Security.AddAccessRule($rule)
    }

    $testSecurityDescriptorEquivalent = {
      param([string]$ExpectedSddl, [string]$ActualSddl)
      $expected = [System.Security.AccessControl.RawSecurityDescriptor]::new($ExpectedSddl)
      $actual = [System.Security.AccessControl.RawSecurityDescriptor]::new($ActualSddl)
      $sidEqual = {
        param($Left, $Right)
        if ($null -eq $Left -or $null -eq $Right) { return $null -eq $Left -and $null -eq $Right }
        $Left.Value -ceq $Right.Value
      }
      $aclEqual = {
        param($Left, $Right)
        if ($null -eq $Left -or $null -eq $Right) { return $null -eq $Left -and $null -eq $Right }
        if ($Left.Count -ne $Right.Count) { return $false }
        for ($aceIndex = 0; $aceIndex -lt $Left.Count; $aceIndex++) {
          if ($Left[$aceIndex].BinaryLength -ne $Right[$aceIndex].BinaryLength) { return $false }
          $leftBytes = [byte[]]::new($Left[$aceIndex].BinaryLength)
          $rightBytes = [byte[]]::new($Right[$aceIndex].BinaryLength)
          $Left[$aceIndex].GetBinaryForm($leftBytes, 0)
          $Right[$aceIndex].GetBinaryForm($rightBytes, 0)
          for ($byteIndex = 0; $byteIndex -lt $leftBytes.Length; $byteIndex++) {
            if ($leftBytes[$byteIndex] -ne $rightBytes[$byteIndex]) { return $false }
          }
        }
        $true
      }
      $kernelNormalizedFlags = [uint32](
        [System.Security.AccessControl.ControlFlags]::DiscretionaryAclAutoInherited -bor
        [System.Security.AccessControl.ControlFlags]::SystemAclAutoInherited)
      $expectedFlags = [uint32]$expected.ControlFlags -band (-bnot $kernelNormalizedFlags)
      $actualFlags = [uint32]$actual.ControlFlags -band (-bnot $kernelNormalizedFlags)
      (& $sidEqual $expected.Owner $actual.Owner) -and
        (& $sidEqual $expected.Group $actual.Group) -and
        $expectedFlags -eq $actualFlags -and
        (& $aclEqual $expected.DiscretionaryAcl $actual.DiscretionaryAcl) -and
        (& $aclEqual $expected.SystemAcl $actual.SystemAcl)
    }
  }

  process {
    if (-not $IsWindows) { throw 'Corpus ACL enforcement is supported only on Windows.' }
    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $itemExists = Test-Path -LiteralPath $fullPath
    $isDirectory = if ($itemExists) {
      (Get-Item -LiteralPath $fullPath -Force -ErrorAction Stop).PSIsContainer
    } else {
      $BoundaryKind -ne 'ImmutableArtifact'
    }
    $aclPath = if ($itemExists) { $fullPath } else { Split-Path -Parent $fullPath }
    if (-not $itemExists -and -not (Test-Path -LiteralPath $aclPath -PathType Container)) {
      throw "ACL validation parent '$aclPath' does not exist."
    }
    $inspectionItem = Get-Item -LiteralPath $aclPath -Force -ErrorAction Stop
    $cursor = if ($inspectionItem.PSIsContainer) { $inspectionItem } else { $inspectionItem.Directory }
    while ($null -ne $cursor) {
      if (($cursor.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "Corpus ACL traversal through reparse point '$($cursor.FullName)' is prohibited."
      }
      $cursor = $cursor.Parent
    }
    if ($itemExists -and
        ($inspectionItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
      throw "Corpus ACL target '$fullPath' is a reparse point."
    }
    $driveFormat = ([System.IO.DriveInfo]::new(
        [System.IO.Path]::GetPathRoot($fullPath))).DriveFormat
    if ($driveFormat -ne 'NTFS') {
      throw "Corpus ACL target '$fullPath' is on unsupported filesystem '$driveFormat'."
    }
    $before = Get-Acl -LiteralPath $aclPath -ErrorAction Stop
    if ($PSCmdlet.ParameterSetName -eq 'Restore') {
      if (-not $itemExists) { throw "Cannot restore ACL because '$fullPath' does not exist." }
      $restored = if ($isDirectory) {
        [System.Security.AccessControl.DirectorySecurity]::new()
      } else {
        [System.Security.AccessControl.FileSecurity]::new()
      }
      $restored.SetSecurityDescriptorSddlForm($RestoreSddl,
        [System.Security.AccessControl.AccessControlSections]::All)
      if ($PSCmdlet.ShouldProcess($fullPath, 'Restore exact captured corpus ACL')) {
        Set-Acl -LiteralPath $fullPath -AclObject $restored -ErrorAction Stop
      }
      $after = if ($WhatIfPreference) { $before } else {
        Get-Acl -LiteralPath $fullPath -ErrorAction Stop
      }
      $afterSddl = $after.GetSecurityDescriptorSddlForm(
        [System.Security.AccessControl.AccessControlSections]::All)
      if (-not $WhatIfPreference -and
          -not (& $testSecurityDescriptorEquivalent $RestoreSddl $afterSddl)) {
        throw "Exact SDDL restore verification failed for '$fullPath'."
      }
      return [pscustomobject][ordered]@{
        Path = $fullPath; BoundaryKind = 'Restore'; Planned = $true
        Applied = -not $WhatIfPreference; BeforeOwner = $before.Owner
        BeforeSddl = $before.GetSecurityDescriptorSddlForm(
          [System.Security.AccessControl.AccessControlSections]::All)
        AfterOwner = $after.Owner; AfterSddl = $afterSddl; Verified = -not $WhatIfPreference
      }
    }

    $captureSid = & $translateIdentity $CaptureIdentity 'CaptureIdentity'
    $expirySid = & $translateIdentity $ExpiryIdentity 'ExpiryIdentity'
    $systemSid = [System.Security.Principal.SecurityIdentifier]::new(
      [System.Security.Principal.WellKnownSidType]::LocalSystemSid, $null)
    $adminSid = [System.Security.Principal.SecurityIdentifier]::new(
      [System.Security.Principal.WellKnownSidType]::BuiltinAdministratorsSid, $null)
    $unsafeSids = @(
      [System.Security.Principal.SecurityIdentifier]::new(
        [System.Security.Principal.WellKnownSidType]::WorldSid, $null).Value,
      [System.Security.Principal.SecurityIdentifier]::new(
        [System.Security.Principal.WellKnownSidType]::AuthenticatedUserSid, $null).Value,
      [System.Security.Principal.SecurityIdentifier]::new(
        [System.Security.Principal.WellKnownSidType]::BuiltinUsersSid, $null).Value,
      $systemSid.Value, $adminSid.Value
    )
    if ($captureSid.Value -in $unsafeSids) {
      throw "CaptureIdentity resolves to unsafe or privileged SID '$($captureSid.Value)'."
    }
    if ($expirySid.Value -in $unsafeSids) {
      throw "ExpiryIdentity resolves to unsafe or privileged SID '$($expirySid.Value)'."
    }
    if ($captureSid.Value -eq $expirySid.Value) {
      throw 'CaptureIdentity and ExpiryIdentity must resolve to distinct accounts.'
    }

    $security = if ($isDirectory) {
      [System.Security.AccessControl.DirectorySecurity]::new()
    } else {
      [System.Security.AccessControl.FileSecurity]::new()
    }
    $security.SetAccessRuleProtection($true, $false)
    $security.SetOwner($adminSid)
    $ciOi = [System.Security.AccessControl.InheritanceFlags]::ContainerInherit -bor
      [System.Security.AccessControl.InheritanceFlags]::ObjectInherit
    $recoveryInheritance = if ($isDirectory) { $ciOi } else {
      [System.Security.AccessControl.InheritanceFlags]::None
    }
    & $addRule $security $systemSid 'FullControl' $recoveryInheritance 'None'
    & $addRule $security $adminSid 'FullControl' $recoveryInheritance 'None'
    & $addRule $security $expirySid 'FullControl' $recoveryInheritance 'None'
    if ($BoundaryKind -eq 'MutableStaging') {
      & $addRule $security $captureSid 'Modify' $ciOi 'None'
    } elseif ($BoundaryKind -eq 'ImmutableDirectory') {
      & $addRule $security $captureSid 'ReadAndExecute' $ciOi 'None'
      & $addRule $security $captureSid `
        ([System.Security.AccessControl.FileSystemRights]::CreateFiles -bor
          [System.Security.AccessControl.FileSystemRights]::CreateDirectories) `
        ([System.Security.AccessControl.InheritanceFlags]::ContainerInherit) 'None'
    } else {
      $artifactDeniedRights = [System.Security.AccessControl.FileSystemRights]::WriteData -bor
        [System.Security.AccessControl.FileSystemRights]::AppendData -bor
        [System.Security.AccessControl.FileSystemRights]::WriteAttributes -bor
        [System.Security.AccessControl.FileSystemRights]::WriteExtendedAttributes -bor
        [System.Security.AccessControl.FileSystemRights]::Delete -bor
        [System.Security.AccessControl.FileSystemRights]::DeleteSubdirectoriesAndFiles -bor
        [System.Security.AccessControl.FileSystemRights]::ChangePermissions -bor
        [System.Security.AccessControl.FileSystemRights]::TakeOwnership
      & $addRule $security $captureSid $artifactDeniedRights 'None' 'None' 'Deny'
      & $addRule $security $captureSid 'ReadAndExecute' 'None' 'None'
    }
    $desiredSddl = $security.GetSecurityDescriptorSddlForm(
      [System.Security.AccessControl.AccessControlSections]::All)
    $beforeSddl = $before.GetSecurityDescriptorSddlForm(
      [System.Security.AccessControl.AccessControlSections]::All)
    $applied = $false
    try {
      if (-not $PlanOnly -and $PSCmdlet.ShouldProcess($fullPath, "Apply $BoundaryKind corpus ACL")) {
        if (-not $itemExists) { throw "Cannot apply ACL because '$fullPath' does not exist." }
        Set-Acl -LiteralPath $fullPath -AclObject $security -ErrorAction Stop
        $applied = $true
      }
      $after = if ($applied) { Get-Acl -LiteralPath $fullPath -ErrorAction Stop } else { $before }
      $afterSddl = if ($applied) {
        $after.GetSecurityDescriptorSddlForm([System.Security.AccessControl.AccessControlSections]::All)
      } else { $null }
      if ($applied) {
        $afterOwnerSid = ([System.Security.Principal.NTAccount]::new($after.Owner)).Translate(
          [System.Security.Principal.SecurityIdentifier]).Value
        if (-not $after.AreAccessRulesProtected -or $afterOwnerSid -ne $adminSid.Value) {
          throw "Applied ACL structural verification failed for '$fullPath'."
        }
        $rules = @($after.GetAccessRules($true, $true,
            [System.Security.Principal.SecurityIdentifier]))
        $captureRules = @($rules | Where-Object IdentityReference -EQ $captureSid)
        $captureAllowRules = @($captureRules | Where-Object AccessControlType -EQ 'Allow')
        $immutableArtifactDangerousRights = [System.Security.AccessControl.FileSystemRights]::WriteData -bor
          [System.Security.AccessControl.FileSystemRights]::AppendData -bor
          [System.Security.AccessControl.FileSystemRights]::WriteAttributes -bor
          [System.Security.AccessControl.FileSystemRights]::WriteExtendedAttributes -bor
          [System.Security.AccessControl.FileSystemRights]::Delete -bor
          [System.Security.AccessControl.FileSystemRights]::DeleteSubdirectoriesAndFiles -bor
          [System.Security.AccessControl.FileSystemRights]::ChangePermissions -bor
          [System.Security.AccessControl.FileSystemRights]::TakeOwnership
        $captureDangerous = @($captureAllowRules | Where-Object {
            ($_.FileSystemRights -band ([System.Security.AccessControl.FileSystemRights]::Delete -bor
                [System.Security.AccessControl.FileSystemRights]::DeleteSubdirectoriesAndFiles -bor
                [System.Security.AccessControl.FileSystemRights]::ChangePermissions -bor
                [System.Security.AccessControl.FileSystemRights]::TakeOwnership)) -ne 0
          })
        if ($BoundaryKind -ne 'MutableStaging' -and $captureDangerous.Count -ne 0) {
          throw "Immutable ACL verification found dangerous capture rights on '$fullPath'."
        }
        if ($BoundaryKind -eq 'ImmutableArtifact' -and
            @($captureAllowRules | Where-Object {
                ($_.FileSystemRights -band $immutableArtifactDangerousRights) -ne 0
              }).Count -ne 0) {
          throw "Immutable artifact ACL verification found capture write rights on '$fullPath'."
        }
        if ($BoundaryKind -eq 'ImmutableArtifact') {
          $captureDenyRules = @($captureRules | Where-Object AccessControlType -EQ 'Deny')
          $deniedRights = [System.Security.AccessControl.FileSystemRights]0
          foreach ($denyRule in $captureDenyRules) { $deniedRights = $deniedRights -bor $denyRule.FileSystemRights }
          if (($deniedRights -band $immutableArtifactDangerousRights) -ne
              $immutableArtifactDangerousRights) {
            throw "Immutable artifact ACL verification found an incomplete capture deny rule on '$fullPath'."
          }
        }
        foreach ($recoverySid in @($systemSid, $adminSid, $expirySid)) {
          $recoveryRules = @($rules | Where-Object {
              $_.IdentityReference -eq $recoverySid -and
              ($_.FileSystemRights -band [System.Security.AccessControl.FileSystemRights]::FullControl) -eq
                [System.Security.AccessControl.FileSystemRights]::FullControl
            })
          if ($recoveryRules.Count -eq 0) {
            throw "ACL verification found no FullControl recovery rule for '$($recoverySid.Value)'."
          }
        }
      }
    } catch {
      $applyError = $_.Exception.Message
      if ($applied) {
        try {
          $rollbackSecurity = if ($isDirectory) {
            [System.Security.AccessControl.DirectorySecurity]::new()
          } else {
            [System.Security.AccessControl.FileSecurity]::new()
          }
          $rollbackSecurity.SetSecurityDescriptorSddlForm($beforeSddl,
            [System.Security.AccessControl.AccessControlSections]::All)
          Set-Acl -LiteralPath $fullPath -AclObject $rollbackSecurity -ErrorAction Stop
        } catch {
          throw "$applyError Automatic exact-SDDL rollback also failed: $($_.Exception.Message)"
        }
      }
      throw $applyError
    }
    [pscustomobject][ordered]@{
      Path = $fullPath; BoundaryKind = $BoundaryKind; Planned = $true; Applied = $applied
      CaptureSid = $captureSid.Value; ExpirySid = $expirySid.Value
      BeforeOwner = $before.Owner; BeforeSddl = $beforeSddl
      DesiredOwner = $adminSid.Value; DesiredSddl = $desiredSddl
      AfterOwner = if ($applied) { $after.Owner } else { $null }
      AfterSddl = $afterSddl; Verified = $applied
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
      -Message 'Finished corpus filesystem ACL operation.' -Tag 'CorpusAcl'
  }
}
