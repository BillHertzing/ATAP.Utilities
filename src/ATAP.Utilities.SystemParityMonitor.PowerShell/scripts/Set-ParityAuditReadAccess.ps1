function Invoke-ParityPermissionNativeCommand {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet('icacls.exe', 'sqlcmd.exe')]
    [string] $FilePath,

    [Parameter(Mandatory)]
    [AllowEmptyCollection()]
    [string[]] $ArgumentList
  )

  begin {
    $fn = 'Invoke-ParityPermissionNativeCommand'
    $mn = 'ATAP.Utilities.SystemParityMonitor.PowerShell'
  }

  process {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Invoking permission tool '$FilePath' with $($ArgumentList.Count) metadata arguments."
    $output = @(& $FilePath @ArgumentList 2>&1)
    [pscustomobject]@{
      ExitCode = $LASTEXITCODE
      Output   = @($output | ForEach-Object { $_.ToString() })
    }
  }

  end {}
}

function Grant-ParityWmiCimv2ReadAccess {
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
  param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]{0,62}$')]
    [string] $ComputerName,

    [Parameter(Mandatory)]
    [ValidatePattern('^[A-Za-z0-9._-]+\\[A-Za-z0-9._$-]+$')]
    [string] $AccountName
  )

  begin {
    $fn = 'Grant-ParityWmiCimv2ReadAccess'
    $mn = 'ATAP.Utilities.SystemParityMonitor.PowerShell'
    $namespace = 'root\cimv2'
    [uint32] $requiredAccessMask = 0x21 # WBEM_ENABLE (1) + WBEM_REMOTE_ACCESS (32)
  }

  process {
    $security = Get-CimInstance -ComputerName $ComputerName -Namespace $namespace -ClassName '__SystemSecurity' -ErrorAction Stop
    $descriptorResult = Invoke-CimMethod -InputObject $security -MethodName 'GetSecurityDescriptor' -ErrorAction Stop
    if ($descriptorResult.ReturnValue -ne 0 -or $null -eq $descriptorResult.Descriptor) {
      throw "Unable to read the WMI namespace security descriptor for '$namespace' on '$ComputerName'."
    }

    $sid = ([System.Security.Principal.NTAccount] $AccountName).Translate([System.Security.Principal.SecurityIdentifier])
    $sidBytes = [byte[]]::new($sid.BinaryLength)
    $sid.GetBinaryForm($sidBytes, 0)
    $existingAce = @($descriptorResult.Descriptor.DACL | Where-Object {
        $null -ne $_.Trustee -and
        $null -ne $_.Trustee.SID -and
        ([Convert]::ToBase64String([byte[]] $_.Trustee.SID) -eq [Convert]::ToBase64String($sidBytes)) -and
        (($_.AccessMask -band $requiredAccessMask) -eq $requiredAccessMask) -and
        $_.AceType -eq 0
      })

    if ($existingAce.Count -eq 0 -and $PSCmdlet.ShouldProcess("$ComputerName\$namespace", "Add WMI enable and remote-enable ACE for $AccountName")) {
      $trustee = New-CimInstance -ClientOnly -Namespace $namespace -ClassName 'Win32_Trustee' -Property @{
        Domain = $AccountName.Split('\', 2)[0]
        Name   = $AccountName.Split('\', 2)[1]
        SID    = $sidBytes
      }
      $ace = New-CimInstance -ClientOnly -Namespace $namespace -ClassName 'Win32_ACE' -Property @{
        AccessMask = $requiredAccessMask
        AceFlags   = [uint32] 0
        AceType    = [uint32] 0
        Trustee    = $trustee
      }
      $descriptorResult.Descriptor.DACL = @($descriptorResult.Descriptor.DACL) + $ace
      $setResult = Invoke-CimMethod -InputObject $security -MethodName 'SetSecurityDescriptor' -Arguments @{ Descriptor = $descriptorResult.Descriptor } -ErrorAction Stop
      if ($setResult.ReturnValue -ne 0) {
        throw "WMI SetSecurityDescriptor failed for '$namespace' on '$ComputerName' with return code $($setResult.ReturnValue)."
      }
    }

    $verificationResult = Invoke-CimMethod -InputObject $security -MethodName 'GetSecurityDescriptor' -ErrorAction Stop
    if ($verificationResult.ReturnValue -ne 0 -or $null -eq $verificationResult.Descriptor) {
      throw "Unable to verify the WMI namespace security descriptor for '$namespace' on '$ComputerName'."
    }
    $verifiedAce = @($verificationResult.Descriptor.DACL | Where-Object {
        $null -ne $_.Trustee -and
        $null -ne $_.Trustee.SID -and
        ([Convert]::ToBase64String([byte[]] $_.Trustee.SID) -eq [Convert]::ToBase64String($sidBytes)) -and
        (($_.AccessMask -band $requiredAccessMask) -eq $requiredAccessMask) -and
        $_.AceType -eq 0
      })
    if (-not $WhatIfPreference -and $verifiedAce.Count -eq 0) {
      throw "WMI read access verification failed for '$AccountName' on '$ComputerName\$namespace'."
    }

    [pscustomobject]@{
      Surface   = 'WMI'
      Target    = "$ComputerName\$namespace"
      Account   = $AccountName
      Access    = 'Enable,RemoteEnable'
      Compliant = ($verifiedAce.Count -gt 0)
      Changed   = ($existingAce.Count -eq 0 -and -not $WhatIfPreference)
    }
  }

  end {}
}

function Set-ParityAuditReadAccess {
  <#
  .SYNOPSIS
  Adds the approved read-only permissions used by the parity audit identity.

  .DESCRIPTION
  Applies additive filesystem, SQL Server, SQL Agent metadata, and optionally WMI
  namespace grants. Inputs are restricted to the approved surfaces. The function
  does not accept or log credentials. WMI mutation requires the separate
  EnableWmiGrant switch as well as ShouldProcess approval. Run this function
  locally on each target host through a separately approved execution boundary;
  filesystem ACLs, account SID translation, and WMI namespace security are local.
  FQDN aliases are rejected because this function has no authoritative DNS/domain
  identity proof.
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
  param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]{0,62}$')]
    [string] $ComputerName,

    [Parameter(Mandatory)]
    [ValidatePattern('^[A-Za-z0-9._-]+\\[A-Za-z0-9._$-]+$')]
    [string] $AccountName,

    [Parameter(Mandatory)]
    [ValidatePattern('^[A-Za-z0-9._-]+$')]
    [string] $UserName,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string[]] $SqlInstanceNames,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $ChocolateyPath,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $LocalDatabasesPath,

    [Parameter(Mandatory)]
    [AllowEmptyCollection()]
    [object[]] $PackageManagerProfiles,

    [switch] $EnableWmiGrant
  )

  begin {
    $fn = 'Set-ParityAuditReadAccess'
    $mn = 'ATAP.Utilities.SystemParityMonitor.PowerShell'
    $localComputerName = [System.Environment]::MachineName
    if (-not $ComputerName.Equals($localComputerName, [System.StringComparison]::OrdinalIgnoreCase)) {
      throw "ComputerName must exactly match the local machine name '$localComputerName'. Invoke this function locally on each approved target host."
    }
    $approvedInstances = @('Production', 'QA', 'Integration', "Dev$UserName", "Exp$UserName")
    $normalizedInstances = @($SqlInstanceNames | Sort-Object -Unique)
    $normalizedApprovedInstances = @($approvedInstances | Sort-Object -Unique)
    if ($normalizedInstances.Count -ne $normalizedApprovedInstances.Count -or
      (Compare-Object -ReferenceObject $normalizedApprovedInstances -DifferenceObject $normalizedInstances).Count -ne 0) {
      throw "SqlInstanceNames must contain exactly: $($approvedInstances -join ', ')."
    }

    $approvedChocolateyPath = [System.IO.Path]::GetFullPath('C:\ProgramData\chocolatey').TrimEnd('\')
    $approvedLocalDatabasesPath = [System.IO.Path]::GetFullPath('C:\LocalDBs').TrimEnd('\')
    $resolvedChocolateyPath = [System.IO.Path]::GetFullPath($ChocolateyPath).TrimEnd('\')
    $resolvedLocalDatabasesPath = [System.IO.Path]::GetFullPath($LocalDatabasesPath).TrimEnd('\')
    if (-not $resolvedChocolateyPath.Equals($approvedChocolateyPath, [System.StringComparison]::OrdinalIgnoreCase)) {
      throw "ChocolateyPath must be exactly '$approvedChocolateyPath'."
    }
    if (-not $resolvedLocalDatabasesPath.Equals($approvedLocalDatabasesPath, [System.StringComparison]::OrdinalIgnoreCase)) {
      throw "LocalDatabasesPath must be exactly '$approvedLocalDatabasesPath'."
    }

    $approvedUserRoot = [System.IO.Path]::GetFullPath("C:\Users\$UserName").TrimEnd('\')
    $approvedUserRootPrefix = "$approvedUserRoot\"
    $approvedMachineNpmPrefix = [System.IO.Path]::GetFullPath('C:\Program Files\nodejs').TrimEnd('\')
    $profileIdentities = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $packageManagerPaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $packageManagerAncestorPaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $addApprovedUserPath = {
      param([Parameter(Mandatory)] [string] $Path)

      [void] $packageManagerPaths.Add($Path)
      $ancestor = [System.IO.Path]::GetDirectoryName($Path)
      while (-not [string]::IsNullOrWhiteSpace($ancestor) -and
        ($ancestor.Equals($approvedUserRoot, [System.StringComparison]::OrdinalIgnoreCase) -or
          $ancestor.StartsWith($approvedUserRootPrefix, [System.StringComparison]::OrdinalIgnoreCase))) {
        [void] $packageManagerAncestorPaths.Add($ancestor)
        if ($ancestor.Equals($approvedUserRoot, [System.StringComparison]::OrdinalIgnoreCase)) { break }
        $ancestor = [System.IO.Path]::GetDirectoryName($ancestor)
      }
    }
    $requiredProfileFields = @('Identity', 'PipPath', 'NpmPrefix', 'NuGetToolPath')
    foreach ($profile in $PackageManagerProfiles) {
      if ($null -eq $profile) { throw 'PackageManagerProfiles cannot contain a null profile.' }
      $values = @{}
      foreach ($fieldName in $requiredProfileFields) {
        if ($profile -is [System.Collections.IDictionary]) {
          if (-not $profile.Contains($fieldName)) { throw "PackageManagerProfiles entry is missing required field '$fieldName'." }
          $values[$fieldName] = $profile[$fieldName]
        }
        else {
          $property = $profile.PSObject.Properties[$fieldName]
          if ($null -eq $property) { throw "PackageManagerProfiles entry is missing required field '$fieldName'." }
          $values[$fieldName] = $property.Value
        }
      }
      $identity = [string] $values['Identity']
      if ([string]::IsNullOrWhiteSpace($identity) -or -not $profileIdentities.Add($identity)) {
        throw "PackageManagerProfiles Identity values must be non-empty and unique; rejected '$identity'."
      }
      foreach ($pathField in @('PipPath', 'NpmPrefix', 'NuGetToolPath')) {
        $configuredPath = [string] $values[$pathField]
        if ([string]::IsNullOrWhiteSpace($configuredPath)) { continue }
        if ($configuredPath.Contains('%') -or $configuredPath -match '(?i)\$env:') {
          throw "PackageManagerProfiles $pathField for '$identity' must not contain environment-variable syntax."
        }
        if (-not [System.IO.Path]::IsPathFullyQualified($configuredPath) -or $configuredPath.StartsWith('\\')) {
          throw "PackageManagerProfiles $pathField for '$identity' must be a fully-qualified local path."
        }
        $normalizedPath = [System.IO.Path]::GetFullPath($configuredPath).TrimEnd('\')
        $isUnderApprovedUserRoot = $normalizedPath.StartsWith($approvedUserRootPrefix, [System.StringComparison]::OrdinalIgnoreCase)
        $isExactMachineNpmPrefix = $pathField -eq 'NpmPrefix' -and
          $normalizedPath.Equals($approvedMachineNpmPrefix, [System.StringComparison]::OrdinalIgnoreCase)
        if (-not $isUnderApprovedUserRoot -and -not $isExactMachineNpmPrefix) {
          throw "PackageManagerProfiles $pathField for '$identity' must remain under '$approvedUserRootPrefix'; NpmPrefix alone may instead equal '$approvedMachineNpmPrefix'."
        }
        if ($isUnderApprovedUserRoot) {
          & $addApprovedUserPath -Path $normalizedPath
        }
        else {
          [void] $packageManagerPaths.Add($normalizedPath)
          if (Test-Path -LiteralPath $normalizedPath -PathType Container) {
            $npmPrefixItem = Get-Item -LiteralPath $normalizedPath -Force -ErrorAction Stop
            $linkTargets = @($npmPrefixItem.Target | Where-Object { -not [string]::IsNullOrWhiteSpace([string] $_) })
            if ($linkTargets.Count -gt 1) {
              throw "Approved machine NpmPrefix '$normalizedPath' has multiple link targets; refusing an ambiguous permission grant."
            }
            if ($linkTargets.Count -eq 1) {
              $linkTarget = [string] $linkTargets[0]
              if (-not [System.IO.Path]::IsPathFullyQualified($linkTarget) -or $linkTarget.StartsWith('\\')) {
                throw "Approved machine NpmPrefix '$normalizedPath' must resolve to one fully-qualified local target."
              }
              $normalizedTarget = [System.IO.Path]::GetFullPath($linkTarget).TrimEnd('\')
              if (-not $normalizedTarget.StartsWith($approvedUserRootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
                throw "Approved machine NpmPrefix '$normalizedPath' resolves outside '$approvedUserRootPrefix'; refusing the target grant."
              }
              & $addApprovedUserPath -Path $normalizedTarget
            }
          }
        }
      }
    }

    $escapedAccountName = $AccountName.Replace(']', ']]').Replace("'", "''")
    $failures = [System.Collections.Generic.List[string]]::new()
    $results = [System.Collections.Generic.List[object]]::new()
  }

  process {
    foreach ($pathGrant in @(
        @{ Path = $resolvedChocolateyPath; Rights = '(OI)(CI)(RX)' },
        @{ Path = $resolvedLocalDatabasesPath; Rights = '(OI)(CI)(R)' }
      ) + @($packageManagerPaths | Sort-Object | ForEach-Object {
          # Inventory commands must traverse directories beneath the configured profile
          # root. Read without execute/traverse can enumerate the root yet still fail when
          # npm, pip, or dotnet descends into it under the service identity.
          @{ Path = $_; Rights = '(OI)(CI)(RX)'; Surface = 'PackageManagerProfile' }
        }
      ) + @($packageManagerAncestorPaths | Sort-Object | ForEach-Object {
          # npm performs lstat while walking to its configured prefix. Non-inheriting
          # ReadAttributes plus Execute permits that walk without directory listing or
          # inherited access to sibling content.
          @{ Path = $_; Rights = '(X,RA)'; Surface = 'PackageManagerProfileAncestor' }
        }
      )) {
      $target = $pathGrant.Path
      if (-not $PSCmdlet.ShouldProcess("${ComputerName}:$target", "Add $($pathGrant.Rights) for $AccountName")) {
        $surface = if ($pathGrant.Surface) { $pathGrant.Surface } else { 'FileSystem' }
        $results.Add([pscustomobject]@{ Surface = $surface; Target = $target; Account = $AccountName; Access = $pathGrant.Rights; Changed = $false; WhatIf = $true })
        continue
      }
      try {
        $grantResult = Invoke-ParityPermissionNativeCommand -FilePath 'icacls.exe' -ArgumentList @($target, '/grant', "${AccountName}:$($pathGrant.Rights)", '/C')
        if ($grantResult.ExitCode -ne 0) { throw "icacls grant returned exit code $($grantResult.ExitCode)." }
        $verifyResult = Invoke-ParityPermissionNativeCommand -FilePath 'icacls.exe' -ArgumentList @($target)
        $verificationText = $verifyResult.Output -join "`n"
        if ($verifyResult.ExitCode -ne 0 -or
          $verificationText -notmatch [regex]::Escape($AccountName) -or
          $verificationText -notmatch [regex]::Escape($pathGrant.Rights)) {
          throw 'icacls verification did not find the requested account and exact rights.'
        }
        $surface = if ($pathGrant.Surface) { $pathGrant.Surface } else { 'FileSystem' }
        $results.Add([pscustomobject]@{ Surface = $surface; Target = $target; Account = $AccountName; Access = $pathGrant.Rights; Changed = $true; WhatIf = $false })
      }
      catch {
        $failures.Add("FileSystem '$target': $($_.Exception.Message)")
      }
    }

    foreach ($instanceName in $approvedInstances) {
      $serverName = "$ComputerName\$instanceName"
      $sql = @"
SET NOCOUNT ON;
IF SUSER_ID(N'$escapedAccountName') IS NULL CREATE LOGIN [$escapedAccountName] FROM WINDOWS;
GRANT VIEW ANY DEFINITION TO [$escapedAccountName];
GRANT VIEW SERVER STATE TO [$escapedAccountName];
USE [msdb];
IF USER_ID(N'$escapedAccountName') IS NULL CREATE USER [$escapedAccountName] FOR LOGIN [$escapedAccountName];
IF NOT EXISTS (
  SELECT 1 FROM sys.database_role_members drm
  JOIN sys.database_principals rolep ON rolep.principal_id = drm.role_principal_id
  JOIN sys.database_principals memberp ON memberp.principal_id = drm.member_principal_id
  WHERE rolep.name = N'SQLAgentReaderRole' AND memberp.name = N'$escapedAccountName'
) ALTER ROLE [SQLAgentReaderRole] ADD MEMBER [$escapedAccountName];
USE [master];
IF IS_SRVROLEMEMBER(N'sysadmin', N'$escapedAccountName') <> 0 THROW 51000, 'Parity audit identity must not be sysadmin.', 1;
IF EXISTS (
  SELECT 1 FROM sys.server_permissions p
  JOIN sys.server_principals sp ON sp.principal_id = p.grantee_principal_id
  WHERE sp.name = N'$escapedAccountName'
    AND p.state IN ('G', 'W')
    AND (p.permission_name LIKE N'%ALTER%' OR p.permission_name LIKE N'%CONTROL%' OR p.permission_name LIKE N'%IMPERSONATE%' OR p.permission_name LIKE N'%WRITE%')
) THROW 51001, 'Parity audit identity has a prohibited broad server permission.', 1;
"@
      if (-not $PSCmdlet.ShouldProcess($serverName, "Add and verify parity audit SQL metadata grants for $AccountName")) {
        $results.Add([pscustomobject]@{ Surface = 'SQL'; Target = $serverName; Account = $AccountName; Access = 'VIEW ANY DEFINITION,VIEW SERVER STATE,msdb:SQLAgentReaderRole'; Changed = $false; WhatIf = $true })
        continue
      }
      try {
        $sqlResult = Invoke-ParityPermissionNativeCommand -FilePath 'sqlcmd.exe' -ArgumentList @('-S', $serverName, '-E', '-b', '-Q', $sql)
        if ($sqlResult.ExitCode -ne 0) { throw "sqlcmd returned exit code $($sqlResult.ExitCode)." }
        $results.Add([pscustomobject]@{ Surface = 'SQL'; Target = $serverName; Account = $AccountName; Access = 'VIEW ANY DEFINITION,VIEW SERVER STATE,msdb:SQLAgentReaderRole'; Changed = $true; WhatIf = $false })
      }
      catch {
        $failures.Add("SQL '$serverName': $($_.Exception.Message)")
      }
    }

    if ($EnableWmiGrant) {
      try {
        $wmiResult = Grant-ParityWmiCimv2ReadAccess -ComputerName $ComputerName -AccountName $AccountName -WhatIf:$WhatIfPreference -Confirm:$false
        if ($null -ne $wmiResult) { $results.Add($wmiResult) }
      }
      catch {
        $failures.Add("WMI '$ComputerName\root\cimv2': $($_.Exception.Message)")
      }
    }
    else {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'WMI root\cimv2 grant was not requested; verification/grant remains coordinator-gated.'
      $results.Add([pscustomobject]@{ Surface = 'WMI'; Target = "$ComputerName\root\cimv2"; Account = $AccountName; Access = 'Enable,RemoteEnable'; Changed = $false; WhatIf = [bool] $WhatIfPreference; Deferred = $true })
    }

    if ($failures.Count -gt 0) {
      throw "One or more parity permission operations failed: $($failures -join ' | ')"
    }
    $results
  }

  end {}
}
