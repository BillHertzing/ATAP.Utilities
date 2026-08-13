<#
.SYNOPSIS
  Registers all five permanent powershellget-* ProGet feeds in both PowerShell repository stores.

.DESCRIPTION
  Iterates the ProGetFeedCollection (from $global:settings) and registers every feed whose
  FeedType is 'powershellget' as a trusted repository in both PowerShellGet and PSResourceGet.
  This is a one-time, per-workstation operation. Sprint start / end do NOT call this cmdlet —
  the five permanent powershellget-* feeds (experimental, development, integration, qa, stable)
  never change between sprints.

  If a repository with the same name is already registered, its URI and trust policy are
  reconciled to the canonical settings. Matching registrations are left unchanged.

  Only the canonical lowercase feed names (powershellget-experimental, -development,
  -integration, -qa, -stable) are ever registered — they come straight from the feed
  collection's FeedName.

  Before registering, the function PRUNES obsolete v3 (PSResource) registrations left over
  from the legacy promotion-matrix naming convention — names matching the pattern
  <Ext|Int><Rel|Pre><Nug|PSR|Cho><Prod|QA|Intg><Pull|Push>Feed (for example
  IntPreNugProdPushFeed, IntRelPSRProdPullFeed). Canonical powershellget-*, nuget-*,
  PSGallery, and public connector repositories are never touched. Pruning honours -WhatIf
  and -Confirm through ShouldProcess, and can be disabled with -PruneObsolete:$false.

.PARAMETER PruneObsolete
  When $true (default), unregisters obsolete legacy promotion-matrix PSResource repositories
  before registering the canonical feeds. Set to $false to register only, leaving any legacy
  registrations untouched.

.OUTPUTS
  [PSCustomObject] one per registered or pruned feed with RepositoryKind, FeedName,
  EndpointUri, and RegistrationResult ('Registered', 'Updated', 'AlreadyRegistered',
  or 'Unregistered').

.NOTES
  AI assisted using ./claude/Rules/Powershell.md as guidelines
#>
function Register-ProGetFeedSet {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
    [Parameter()]
    [bool]$PruneObsolete = $true
  )

  begin {
    Write-PSFMessage -Level Verbose -Message 'Entering function: Register-ProGetFeedSet' -Tag 'Register-ProGetFeedSet', 'Trace'

    # Legacy promotion-matrix PSResource repository names left over from the old
    # ConvertTo-ProGetFeedNameAlternateForm short-name convention, e.g.
    # IntPreNugProdPushFeed, IntRelPSRProdPullFeed. Canonical powershellget-*/nuget-*
    # names, PSGallery, and public connectors never match this pattern.
    $obsoleteFeedNamePattern = '^(Ext|Int)(Rel|Pre)(Nug|PSR|Cho)(Prod|QA|Intg)(Pull|Push)Feed$'

    if (-not $global:settings) {
      $errorMessage = 'global:settings is not initialised. Ensure HostSettings.ps1 has been dot-sourced before calling Register-ProGetFeedSet.'
      Write-PSFMessage -Level Error -Message $errorMessage -Tag 'Register-ProGetFeedSet', 'Trace', 'Error'
      throw $errorMessage
    }

    $feedCollection = $global:settings[$global:configRootKeys['ProGetFeedCollectionConfigRootKey']]
    if (-not $feedCollection) {
      $errorMessage = "ProGetFeedCollection not found in global:settings under key '$($global:configRootKeys['ProGetFeedCollectionConfigRootKey'])'. Ensure the ProGetFeeds HostSettings fragment has been loaded."
      Write-PSFMessage -Level Error -Message $errorMessage -Tag 'Register-ProGetFeedSet', 'Trace', 'Error'
      throw $errorMessage
    }
  }

  process {
    # Prune obsolete legacy promotion-matrix PSResource registrations before registering
    # the canonical feeds, so the workstation only ever carries the canonical names.
    if ($PruneObsolete) {
      $obsoleteRepos = Get-PSResourceRepository -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match $obsoleteFeedNamePattern }
      foreach ($obsolete in $obsoleteRepos) {
        if ($PSCmdlet.ShouldProcess("PSResource repository '$($obsolete.Name)'", 'Unregister-PSResourceRepository (obsolete)')) {
          try {
            Write-PSFMessage -Level Verbose -Message "Unregistering obsolete PSResource repository '$($obsolete.Name)'" -Tag 'Register-ProGetFeedSet', 'Trace'
            Unregister-PSResourceRepository -Name $obsolete.Name
            [PSCustomObject]@{
              RepositoryKind      = 'PSResourceGet'
              FeedName           = $obsolete.Name
              EndpointUri        = $obsolete.Uri
              RegistrationResult = 'Unregistered'
            }
          } catch {
            $errorMessage = "Failed to unregister obsolete PSResource repository '$($obsolete.Name)'. Exception: $($_.Exception.Message)"
            Write-PSFMessage -Level Error -Message $errorMessage -Exception $_.Exception -Tag 'Register-ProGetFeedSet', 'Trace', 'Error'
            throw $_
          }
        }
      }
    }

    # Preserve the full registration objects so URI and trust drift can be reconciled.
    $existingRepos = @(Get-PSResourceRepository -ErrorAction SilentlyContinue)

    [string[]]$feedKeys = $feedCollection.Keys

    for ($i = 0; $i -lt $feedKeys.Count; $i++) {
      $feedKey = $feedKeys[$i]
      $feed = $feedCollection[$feedKey]

      # Only register powershellget-* feeds.
      if ($feed.FeedType -ne 'powershellget') {
        Write-PSFMessage -Level Debug -Message "Skipping feed '$($feed.FeedName)' (FeedType '$($feed.FeedType)' is not 'powershellget')" -Tag 'Register-ProGetFeedSet', 'Trace'
        continue
      }

      $feedName = $feed.FeedName
      $endpointUri = $feed.NuGetV3Uri

      if ([string]::IsNullOrWhiteSpace($endpointUri)) {
        $errorMessage = "Feed '$feedName' has no NuGetV3Uri — cannot register as a PSResource repository."
        Write-PSFMessage -Level Error -Message $errorMessage -Tag 'Register-ProGetFeedSet', 'Trace', 'Error'
        throw $errorMessage
      }

      $existingRepo = $existingRepos | Where-Object Name -EQ $feedName | Select-Object -First 1
      if ($null -ne $existingRepo) {
        $existingUri = ([string]$existingRepo.Uri).TrimEnd('/')
        $expectedUri = ([string]$endpointUri).TrimEnd('/')
        if ($existingUri -eq $expectedUri -and [bool]$existingRepo.Trusted) {
          Write-PSFMessage -Level Verbose -Message "PSResource repository '$feedName' already matches canonical settings." -Tag 'Register-ProGetFeedSet', 'Trace'
          [PSCustomObject]@{
            RepositoryKind      = 'PSResourceGet'
            FeedName           = $feedName
            EndpointUri        = $endpointUri
            RegistrationResult = 'AlreadyRegistered'
          }
          continue
        }

        if ($PSCmdlet.ShouldProcess("PSResource repository '$feedName'", "Reconcile URI and trust policy to $endpointUri")) {
          try {
            Write-PSFMessage -Level Verbose -Message "Reconciling PSResource repository '$feedName' to '$endpointUri'." -Tag 'Register-ProGetFeedSet', 'Trace'
            $result = Set-PSResourceRepository -Name $feedName -Uri $endpointUri -Trusted -PassThru
          } catch {
            $errorMessage = "Failed to reconcile PSResource repository '$feedName'. Exception: $($_.Exception.Message)"
            Write-PSFMessage -Level Error -Message $errorMessage -Exception $_.Exception -Tag 'Register-ProGetFeedSet', 'Trace', 'Error'
            throw $_
          }
        }
        [PSCustomObject]@{
          RepositoryKind      = 'PSResourceGet'
          FeedName           = $feedName
          EndpointUri        = $endpointUri
          RegistrationResult = 'Updated'
        }
        continue
      }

      if ($PSCmdlet.ShouldProcess("PSResource repository '$feedName' at $endpointUri", 'Register-PSResourceRepository')) {
        try {
          Write-PSFMessage -Level Verbose -Message "Registering PSResource repository '$feedName' at '$endpointUri'" -Tag 'Register-ProGetFeedSet', 'Trace'
          $result = Register-PSResourceRepository -Name $feedName -Uri $endpointUri -Trusted -PassThru
          Write-PSFMessage -Level Verbose -Message "Successfully registered PSResource repository '$feedName'" -Tag 'Register-ProGetFeedSet', 'Trace'
          [PSCustomObject]@{
            RepositoryKind      = 'PSResourceGet'
            FeedName           = $feedName
            EndpointUri        = $endpointUri
            RegistrationResult = 'Registered'
          }
        } catch {
          $errorMessage = "Failed to register PSResource repository '$feedName' at '$endpointUri'. Exception: $($_.Exception.Message)"
          Write-PSFMessage -Level Error -Message $errorMessage -Exception $_.Exception -Tag 'Register-ProGetFeedSet', 'Trace', 'Error'
          throw $_
        }
      }
    }

    # PowerShellGet and PSResourceGet persist separate repository stores. Reconcile the
    # legacy store as well because Install-Module and the elevation broker still use it.
    $existingPSRepositories = @(Get-PSRepository -ErrorAction SilentlyContinue)
    for ($i = 0; $i -lt $feedKeys.Count; $i++) {
      $feed = $feedCollection[$feedKeys[$i]]
      if ($feed.FeedType -ne 'powershellget') {
        continue
      }

      $feedName = $feed.FeedName
      $endpointUri = $feed.Uri
      if ([string]::IsNullOrWhiteSpace($endpointUri)) {
        $errorMessage = "Feed '$feedName' has no Uri - cannot register as a PowerShellGet repository."
        Write-PSFMessage -Level Error -Message $errorMessage -Tag 'Register-ProGetFeedSet', 'Trace', 'Error'
        throw $errorMessage
      }

      $existingRepo = $existingPSRepositories | Where-Object Name -EQ $feedName | Select-Object -First 1
      if ($null -ne $existingRepo) {
        $sourceMatches = ([string]$existingRepo.SourceLocation).TrimEnd('/') -eq ([string]$endpointUri).TrimEnd('/')
        $publishMatches = ([string]$existingRepo.PublishLocation).TrimEnd('/') -eq ([string]$endpointUri).TrimEnd('/')
        $trusted = [string]$existingRepo.InstallationPolicy -eq 'Trusted'
        if ($sourceMatches -and $publishMatches -and $trusted) {
          [PSCustomObject]@{
            RepositoryKind      = 'PowerShellGet'
            FeedName           = $feedName
            EndpointUri        = $endpointUri
            RegistrationResult = 'AlreadyRegistered'
          }
          continue
        }

        if ($PSCmdlet.ShouldProcess("PowerShellGet repository '$feedName'", "Reconcile URI and trust policy to $endpointUri")) {
          try {
            Set-PSRepository -Name $feedName -SourceLocation $endpointUri -PublishLocation $endpointUri -InstallationPolicy Trusted
          } catch {
            $errorMessage = "Failed to reconcile PowerShellGet repository '$feedName'. Exception: $($_.Exception.Message)"
            Write-PSFMessage -Level Error -Message $errorMessage -Exception $_.Exception -Tag 'Register-ProGetFeedSet', 'Trace', 'Error'
            throw $_
          }
        }
        [PSCustomObject]@{
          RepositoryKind      = 'PowerShellGet'
          FeedName           = $feedName
          EndpointUri        = $endpointUri
          RegistrationResult = 'Updated'
        }
        continue
      }

      if ($PSCmdlet.ShouldProcess("PowerShellGet repository '$feedName' at $endpointUri", 'Register-PSRepository')) {
        try {
          Register-PSRepository -Name $feedName -SourceLocation $endpointUri -PublishLocation $endpointUri -InstallationPolicy Trusted
          [PSCustomObject]@{
            RepositoryKind      = 'PowerShellGet'
            FeedName           = $feedName
            EndpointUri        = $endpointUri
            RegistrationResult = 'Registered'
          }
        } catch {
          $errorMessage = "Failed to register PowerShellGet repository '$feedName' at '$endpointUri'. Exception: $($_.Exception.Message)"
          Write-PSFMessage -Level Error -Message $errorMessage -Exception $_.Exception -Tag 'Register-ProGetFeedSet', 'Trace', 'Error'
          throw $_
        }
      }
    }
  }

  end {
    Write-PSFMessage -Level Verbose -Message 'Leaving function: Register-ProGetFeedSet' -Tag 'Register-ProGetFeedSet', 'Trace'
  }
}


