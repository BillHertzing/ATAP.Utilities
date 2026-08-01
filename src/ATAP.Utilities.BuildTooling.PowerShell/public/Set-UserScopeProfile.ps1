function Set-UserScopeProfile {
  <#
  .SYNOPSIS
    Creates or retargets the managed PowerShell 7 CurrentUserAllHosts profile for one identity.
  .DESCRIPTION
    Copies the canonical profile payload owned by ATAP.IAC for either a developer
    or a service account into <UserProfilePath>\Documents\PowerShell\profile.ps1.
    Existing unmanaged profiles are protected and require -Force.  Service
    Service payloads are validated to prohibit an interactive Password Manager
    `bw` invocation so a service shell never starts interactive authentication.
    An approved legacy symbolic-link target is removed before bytes are copied;
    cloud-backed real files with reparse attributes remain ordinary files.

    This cmdlet targets the local computer.  Invoke it through the hardened
    remoting path when provisioning a peer computer.
  .PARAMETER AccountName
    Local account whose CurrentUserAllHosts profile is managed.
  .PARAMETER AccountClass
    Developer profiles copy the canonical CurrentUserAllHosts payload.
    ServiceAccount profiles copy the administrator-managed service payload.
  .PARAMETER ComputerName
    Target computer.  The current implementation accepts only the local host;
    use the Task 12.38.b remoting path to execute this command on a peer.
  .PARAMETER ATAPIACRoot
    ATAP.IAC repository or worktree containing Windows\ProfileTemplates.
  .PARAMETER ATAPUtilitiesRoot
    Retained for caller compatibility. Profile payloads are now owned entirely
    by ATAP.IAC and this value is not used to compose deployed content.
  .PARAMETER UserProfilePath
    Explicit profile root.  Intended for tests and carefully scoped repairs.
  .PARAMETER TargetProfilePath
    Exact PowerShell 7 CurrentUserAllHosts profile path. Use this when the
    identity's Documents known folder is redirected and the loaded profile is
    outside `<UserProfilePath>\Documents\PowerShell`.
  .PARAMETER Force
    Allow replacement of a profile without the managed-header marker.
  .OUTPUTS
    PSCustomObject describing the profile path, action, and journal outcome.
  .EXAMPLE
    Set-UserScopeProfile -AccountName whertzing -AccountClass Developer `
      -ATAPIACRoot C:\Dropbox\whertzing\GitHub\ATAP.IAC `
      -ATAPUtilitiesRoot C:\Dropbox\whertzing\GitHub\ATAP.Utilities
  .NOTES
    Every mutation is journaled through Add-ParityChangeEntry.  Do not place
    secrets or token values in templates or journal fields.
  .LINK
    Set-SprintBoundaryUserProfiles
  #>
  [CmdletBinding(SupportsShouldProcess = $true)]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $AccountName,

    [Parameter(Mandatory)]
    [ValidateSet('Developer', 'ServiceAccount')]
    [string] $AccountClass,

    [string] $ComputerName = [Environment]::MachineName,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $ATAPIACRoot,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $ATAPUtilitiesRoot,

    [string] $UserProfilePath,

    [string] $TargetProfilePath,

    [switch] $Force,

    [string] $PeerHostName
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    $managedHeader = '# ATAP-Managed-UserScopeProfile: v1'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"

    $localComputerName = if ($env:COMPUTERNAME) { $env:COMPUTERNAME } else { [Environment]::MachineName }
    $localNames = @('.', 'localhost', $localComputerName) | Where-Object { $_ }
    if ($ComputerName -notin $localNames) {
      throw "Set-UserScopeProfile only writes the local host. Execute it through the approved remoting path on '$ComputerName'."
    }

    function Resolve-ProfileRoot {
      param([string] $Name, [string] $Override)

      if (-not [string]::IsNullOrWhiteSpace($Override)) {
        return [IO.Path]::GetFullPath($Override)
      }

      if ([string]::Equals($Name, $env:USERNAME, [StringComparison]::OrdinalIgnoreCase)) {
        return [IO.Path]::GetFullPath($env:USERPROFILE)
      }

      $profileListPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList'
      if (Test-Path -LiteralPath $profileListPath) {
        foreach ($profileKey in Get-ChildItem -LiteralPath $profileListPath -ErrorAction SilentlyContinue) {
          $profileImagePath = [string](Get-ItemProperty -LiteralPath $profileKey.PSPath -Name ProfileImagePath -ErrorAction SilentlyContinue).ProfileImagePath
          if ($profileImagePath) {
            $expandedPath = [Environment]::ExpandEnvironmentVariables($profileImagePath)
            if ([string]::Equals((Split-Path -Path $expandedPath -Leaf), $Name, [StringComparison]::OrdinalIgnoreCase)) {
              return [IO.Path]::GetFullPath($expandedPath)
            }
          }
        }
      }

      throw "User-profile path could not be resolved for '$Name'. Supply -UserProfilePath after verifying the local account profile exists."
    }

    function Get-DefaultPeerHostName {
      param([string] $HostName)
      if ($HostName -match '^utat022$') { return 'utat01' }
      if ($HostName -match '^utat01$') { return 'utat022' }
      return 'peer-review-required'
    }

    function Test-ProcessElevation {
      try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = [Security.Principal.WindowsPrincipal]::new($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
      } catch {
        return $false
      }
    }

    $sourceFileName = if ($AccountClass -eq 'Developer') {
      'CurrentUserAllHostsV7CoreProfile.ps1'
    } else {
      'ProfileForServiceAccountUsers.ps1'
    }
    $sourcePath = Join-Path $ATAPIACRoot 'Windows\ProfileTemplates' $sourceFileName
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
      throw "Profile payload was not found: '$sourcePath'."
    }

    $sourceContent = Get-Content -LiteralPath $sourcePath -Raw -ErrorAction Stop
    if (-not $sourceContent.StartsWith($managedHeader, [StringComparison]::Ordinal)) {
      throw "Profile payload '$sourcePath' is missing the required managed-header marker."
    }
    if ($AccountClass -eq 'ServiceAccount' -and $sourceContent -match '(?im)^\s*(?:&\s*)?bw(?:\.exe)?\b') {
      throw "Service-account profile '$sourcePath' must not invoke the interactive Bitwarden Password Manager CLI."
    }
    $sourceBytes = [IO.File]::ReadAllBytes($sourcePath)

    $profileRoot = Resolve-ProfileRoot -Name $AccountName -Override $UserProfilePath
    $isCurrentIdentity = [string]::Equals($AccountName, $env:USERNAME, [StringComparison]::OrdinalIgnoreCase)
    $profilePath = if (-not [string]::IsNullOrWhiteSpace($TargetProfilePath)) {
      [IO.Path]::GetFullPath($TargetProfilePath)
    } elseif ([string]::IsNullOrWhiteSpace($UserProfilePath) -and $isCurrentIdentity) {
      [IO.Path]::GetFullPath($PROFILE.CurrentUserAllHosts)
    } else {
      Join-Path $profileRoot 'Documents\PowerShell\profile.ps1'
    }
    $profileDirectory = Split-Path -Path $profilePath -Parent
    $resolvedPeerHostName = if ($PeerHostName) { $PeerHostName } else { Get-DefaultPeerHostName -HostName $localComputerName }

    if (-not $WhatIfPreference -and -not $isCurrentIdentity -and -not (Test-ProcessElevation)) {
      throw "Provisioning '$AccountName' requires an elevated session because it writes another user's profile."
    }

    if (-not $WhatIfPreference -and -not (Get-Command -Name Add-ParityChangeEntry -ErrorAction SilentlyContinue)) {
      throw 'Add-ParityChangeEntry is required before a live user-profile provisioning run can change a profile.'
    }
  }

  process {
    $profileItem = Get-Item -LiteralPath $profilePath -Force -ErrorAction SilentlyContinue
    # Cloud-backed real files can carry ReparsePoint (for example Dropbox
    # placeholders). LinkType distinguishes an actual symlink from those files.
    $isProfileLink = $null -ne $profileItem -and
      -not [string]::IsNullOrWhiteSpace([string]$profileItem.LinkType)
    $existingContent = if (Test-Path -LiteralPath $profilePath -PathType Leaf) {
      Get-Content -LiteralPath $profilePath -Raw -ErrorAction Stop
    } else {
      $null
    }

    $existingBytes = if (Test-Path -LiteralPath $profilePath -PathType Leaf) {
      [IO.File]::ReadAllBytes($profilePath)
    } else {
      $null
    }
    $contentMatches = $null -ne $existingBytes -and [Convert]::ToBase64String($existingBytes) -eq [Convert]::ToBase64String($sourceBytes)
    if ($contentMatches -and -not $isProfileLink) {
      return [PSCustomObject]@{
        AccountName = $AccountName; AccountClass = $AccountClass; ComputerName = $localComputerName
        ProfilePath = $profilePath; SourcePath = $sourcePath; TemplatePath = $sourcePath; Action = 'AlreadyCurrent'; Changed = $false; Journaled = $false
      }
    }

    $isLegacyManagedWrapper = $null -ne $existingContent -and
      $existingContent.Contains('# Quiet SSH-backed PowerShell remoting before profile initialization.') -and
      $existingContent.Contains('CurrentUserAllHostsV7CoreProfile.ps1') -and
      $existingContent -match '(?m)^\.\s+'
    if ($null -ne $existingContent -and -not $existingContent.StartsWith($managedHeader, [StringComparison]::Ordinal) -and -not $isLegacyManagedWrapper -and -not $Force) {
      throw "Refusing to overwrite unmanaged profile '$profilePath'. Re-run with -Force only after preserving its user-owned content."
    }

    $action = if ($null -eq $existingContent) { 'Created' } else { 'Updated' }
    if ($PSCmdlet.ShouldProcess($profilePath, "$action $AccountClass CurrentUserAllHosts profile for '$AccountName'")) {
      try {
        if (-not (Test-Path -LiteralPath $profileDirectory -PathType Container)) {
          New-Item -ItemType Directory -Path $profileDirectory -Force -ErrorAction Stop | Out-Null
        }
        if ($isProfileLink) {
          Remove-Item -LiteralPath $profilePath -Force -ErrorAction Stop
        }
        [IO.File]::WriteAllBytes($profilePath, $sourceBytes)
        $oldValue = if ($null -eq $existingContent) { 'Absent' } else { 'ManagedProfile' }
        Add-ParityChangeEntry -Category Files -Item "PowerShell profile: $AccountName" `
          -OldValue $oldValue `
          -NewValue $profilePath `
          -PeerHostName $resolvedPeerHostName `
          -PeerActionKind Document `
          -PeerAction "Provision the $AccountClass user-scope PowerShell profile for '$AccountName' after review." `
          -Reason 'Task 12.49 managed user-scope profile provisioning.' `
          -Confirm:$false | Out-Null
        return [PSCustomObject]@{
          AccountName = $AccountName; AccountClass = $AccountClass; ComputerName = $localComputerName
          ProfilePath = $profilePath; SourcePath = $sourcePath; TemplatePath = $sourcePath; Action = $action; Changed = $true; Journaled = $true
        }
      } catch {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Failed to provision '$profilePath'. Exception: $($_.Exception.Message)"
        throw
      }
    }

    return [PSCustomObject]@{
      AccountName = $AccountName; AccountClass = $AccountClass; ComputerName = $localComputerName
      ProfilePath = $profilePath; SourcePath = $sourcePath; TemplatePath = $sourcePath; Action = "Would$action"; Changed = $false; Journaled = $false
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn"
  }
}
