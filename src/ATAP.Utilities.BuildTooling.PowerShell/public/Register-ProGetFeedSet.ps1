<#
.SYNOPSIS
  Registers all five permanent powershellget-* ProGet feeds as PSResource repositories on the developer workstation.

.DESCRIPTION
  Iterates the ProGetFeedCollection (from $global:settings) and registers every feed whose
  FeedType is 'powershell' as a trusted PSResource repository using Register-PSResourceRepository.
  This is a one-time, per-workstation operation. Sprint start / end do NOT call this cmdlet —
  the five permanent powershellget-* feeds (experimental, development, integration, qa, stable)
  never change between sprints.

  If a repository with the same name is already registered it is skipped (idempotent).

.OUTPUTS
  [PSCustomObject] one per registered feed with FeedName, EndpointUri, and RegistrationResult.

.NOTES
  AI assisted using ./claude/Rules/Powershell.md as guidelines
#>
function Register-ProGetFeedSet {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param ( )

  begin {
    Write-PSFMessage -Level Verbose -Message 'Entering function: Register-ProGetFeedSet' -Tag 'Register-ProGetFeedSet', 'Trace'

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
    # Collect all existing PSResource repository names for idempotency check
    $existingRepos = Get-PSResourceRepository -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name

    [string[]]$feedKeys = $feedCollection.Keys

    for ($i = 0; $i -lt $feedKeys.Count; $i++) {
      $feedKey = $feedKeys[$i]
      $feed = $feedCollection[$feedKey]

      # Only register powershellget-* feeds (FeedType 'powershell')
      if ($feed.FeedType -ne 'powershell') {
        Write-PSFMessage -Level Debug -Message "Skipping feed '$($feed.FeedName)' (FeedType '$($feed.FeedType)' is not 'powershell')" -Tag 'Register-ProGetFeedSet', 'Trace'
        continue
      }

      $feedName = $feed.FeedName
      $endpointUri = $feed.NuGetV3Uri

      if ([string]::IsNullOrWhiteSpace($endpointUri)) {
        $errorMessage = "Feed '$feedName' has no NuGetV3Uri — cannot register as a PSResource repository."
        Write-PSFMessage -Level Error -Message $errorMessage -Tag 'Register-ProGetFeedSet', 'Trace', 'Error'
        throw $errorMessage
      }

      if ($existingRepos -contains $feedName) {
        Write-PSFMessage -Level Verbose -Message "PSResource repository '$feedName' is already registered — skipping." -Tag 'Register-ProGetFeedSet', 'Trace'
        [PSCustomObject]@{
          FeedName           = $feedName
          EndpointUri        = $endpointUri
          RegistrationResult = 'AlreadyRegistered'
        }
        continue
      }

      if ($PSCmdlet.ShouldProcess("PSResource repository '$feedName' at $endpointUri", 'Register-PSResourceRepository')) {
        try {
          Write-PSFMessage -Level Verbose -Message "Registering PSResource repository '$feedName' at '$endpointUri'" -Tag 'Register-ProGetFeedSet', 'Trace'
          $result = Register-PSResourceRepository -Name $feedName -Uri $endpointUri -Trusted -PassThru
          Write-PSFMessage -Level Verbose -Message "Successfully registered PSResource repository '$feedName'" -Tag 'Register-ProGetFeedSet', 'Trace'
          [PSCustomObject]@{
            FeedName           = $feedName
            EndpointUri        = $endpointUri
            RegistrationResult = $result
          }
        } catch {
          $errorMessage = "Failed to register PSResource repository '$feedName' at '$endpointUri'. Exception: $($_.Exception.Message)"
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


