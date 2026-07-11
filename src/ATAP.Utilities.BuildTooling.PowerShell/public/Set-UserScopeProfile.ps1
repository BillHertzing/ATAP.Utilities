function Set-UserScopeProfile {
  <#
  .SYNOPSIS
    Creates or retargets the managed PowerShell 7 CurrentUserAllHosts profile for one identity.
  .DESCRIPTION
    Renders the profile template owned by ATAP.IAC for either a developer or a
    service account into <UserProfilePath>\Documents\PowerShell\profile.ps1.
    Existing unmanaged profiles are protected and require -Force.  Service
    templates are validated to prohibit Bitwarden CLI invocation so a service
    shell never starts interactive authentication.

    This cmdlet targets the local computer.  Invoke it through the hardened
    remoting path when provisioning a peer computer.
  .PARAMETER AccountName
    Local account whose CurrentUserAllHosts profile is managed.
  .PARAMETER AccountClass
    Developer profiles dot-source the canonical developer core profile.
    ServiceAccount profiles use the minimal non-interactive template.
  .PARAMETER ComputerName
    Target computer.  The current implementation accepts only the local host;
    use the Task 12.38.b remoting path to execute this command on a peer.
  .PARAMETER ATAPIACRoot
    ATAP.IAC repository or worktree containing Windows\ProfileTemplates.
  .PARAMETER ATAPUtilitiesRoot
    ATAP.Utilities repository or worktree containing the canonical developer
    core profile referenced by the developer template.
  .PARAMETER UserProfilePath
    Explicit profile root.  Intended for tests and carefully scoped repairs.
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

    [string] $ComputerName = $env:COMPUTERNAME,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $ATAPIACRoot,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $ATAPUtilitiesRoot,

    [string] $UserProfilePath,

    [switch] $Force,

    [string] $PeerHostName
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    $managedHeader = '# ATAP-Managed-UserScopeProfile: v1'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"

    $localNames = @('.', 'localhost', $env:COMPUTERNAME) | Where-Object { $_ }
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

    $templateFileName = if ($AccountClass -eq 'Developer') {
      'Developer.CurrentUserAllHosts.ps1.template'
    } else {
      'ServiceAccount.CurrentUserAllHosts.ps1.template'
    }
    $templatePath = Join-Path $ATAPIACRoot 'Windows\ProfileTemplates' $templateFileName
    if (-not (Test-Path -LiteralPath $templatePath -PathType Leaf)) {
      throw "Profile template was not found: '$templatePath'."
    }

    $template = Get-Content -LiteralPath $templatePath -Raw -ErrorAction Stop
    if (-not $template.StartsWith($managedHeader, [StringComparison]::Ordinal)) {
      throw "Profile template '$templatePath' is missing the required managed-header marker."
    }
    if ($AccountClass -eq 'ServiceAccount' -and $template -match '(?im)\b(bw|bws)\b') {
      throw "Service-account template '$templatePath' must not invoke Bitwarden CLI commands."
    }

    $profileRoot = Resolve-ProfileRoot -Name $AccountName -Override $UserProfilePath
    $profileDirectory = Join-Path $profileRoot 'Documents\PowerShell'
    $profilePath = Join-Path $profileDirectory 'profile.ps1'
    $desiredContent = $template.Replace('{{ATAP_UTILITIES_ROOT}}', [IO.Path]::GetFullPath($ATAPUtilitiesRoot)).Replace('{{ACCOUNT_NAME}}', $AccountName)
    $resolvedPeerHostName = if ($PeerHostName) { $PeerHostName } else { Get-DefaultPeerHostName -HostName $env:COMPUTERNAME }

    if (-not $WhatIfPreference -and -not [string]::Equals($AccountName, $env:USERNAME, [StringComparison]::OrdinalIgnoreCase) -and -not (Test-ProcessElevation)) {
      throw "Provisioning '$AccountName' requires an elevated session because it writes another user's profile."
    }

    if (-not $WhatIfPreference -and -not (Get-Command -Name Add-ParityChangeEntry -ErrorAction SilentlyContinue)) {
      throw 'Add-ParityChangeEntry is required before a live user-profile provisioning run can change a profile.'
    }
  }

  process {
    $existingContent = if (Test-Path -LiteralPath $profilePath -PathType Leaf) {
      Get-Content -LiteralPath $profilePath -Raw -ErrorAction Stop
    } else {
      $null
    }

    if ($null -ne $existingContent -and [string]::Equals($existingContent, $desiredContent, [StringComparison]::Ordinal)) {
      return [PSCustomObject]@{
        AccountName = $AccountName; AccountClass = $AccountClass; ComputerName = $env:COMPUTERNAME
        ProfilePath = $profilePath; TemplatePath = $templatePath; Action = 'AlreadyCurrent'; Changed = $false; Journaled = $false
      }
    }

    if ($null -ne $existingContent -and -not $existingContent.StartsWith($managedHeader, [StringComparison]::Ordinal) -and -not $Force) {
      throw "Refusing to overwrite unmanaged profile '$profilePath'. Re-run with -Force only after preserving its user-owned content."
    }

    $action = if ($null -eq $existingContent) { 'Created' } else { 'Updated' }
    if ($PSCmdlet.ShouldProcess($profilePath, "$action $AccountClass CurrentUserAllHosts profile for '$AccountName'")) {
      try {
        if (-not (Test-Path -LiteralPath $profileDirectory -PathType Container)) {
          New-Item -ItemType Directory -Path $profileDirectory -Force -ErrorAction Stop | Out-Null
        }
        Set-Content -LiteralPath $profilePath -Value $desiredContent -Encoding utf8 -NoNewline -ErrorAction Stop
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
          AccountName = $AccountName; AccountClass = $AccountClass; ComputerName = $env:COMPUTERNAME
          ProfilePath = $profilePath; TemplatePath = $templatePath; Action = $action; Changed = $true; Journaled = $true
        }
      } catch {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Failed to provision '$profilePath'. Exception: $($_.Exception.Message)"
        throw
      }
    }

    return [PSCustomObject]@{
      AccountName = $AccountName; AccountClass = $AccountClass; ComputerName = $env:COMPUTERNAME
      ProfilePath = $profilePath; TemplatePath = $templatePath; Action = "Would$action"; Changed = $false; Journaled = $false
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn"
  }
}
