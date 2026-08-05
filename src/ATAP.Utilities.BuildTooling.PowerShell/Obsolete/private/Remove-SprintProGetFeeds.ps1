function Remove-SprintProGetFeeds {
  <#
  .SYNOPSIS
    Deletes the per-sprint ProGet NuGet feeds created by New-SprintProGetFeeds.
  .DESCRIPTION
    Deletes the two ephemeral T1/T2 feeds at sprint end:
      nuget-Sprint{NNNN}-experimental
      nuget-Sprint{NNNN}-development

    If -Username was supplied when the feeds were created, pass the same value here
    so the correct feed names are resolved.
  .PARAMETER SprintNumber
    The sprint number, zero-padded to 4 digits (e.g., '0006').
  .PARAMETER ProGetBaseUrl
    Base URL for the ProGet server (e.g., 'https://utat022:50000').
  .PARAMETER Username
    Optional. Must match the value used when the feeds were created.
  .OUTPUTS
    PSCustomObject with deletedFeeds and errors arrays.
  .EXAMPLE
    Remove-SprintProGetFeeds -SprintNumber '0006' -ProGetBaseUrl 'https://utat022:50000'
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  .LINK
    New-SprintProGetFeeds
  .LINK
    Reset-DownstreamToSharedVSCodeMain
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$SprintNumber,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$ProGetBaseUrl,

    [Parameter()]
    [string]$Username
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"

    $apiKey = [System.Environment]::GetEnvironmentVariable('PROGET_ADMIN_API_KEY', 'User')
    if ([string]::IsNullOrWhiteSpace($apiKey)) {
      throw 'PROGET_ADMIN_API_KEY is not set at User scope. Cannot delete ProGet feeds.'
    }
  }

  process {
    $suffix = if ($PSBoundParameters.ContainsKey('Username') -and -not [string]::IsNullOrWhiteSpace($Username)) {
      "-$Username"
    } else { '' }

    $feedNames = @(
      "nuget-Sprint${SprintNumber}-experimental${suffix}"
      "nuget-Sprint${SprintNumber}-development${suffix}"
    )

    $headers = @{ 'X-ApiKey' = $apiKey }

    $deletedFeeds = [System.Collections.ArrayList]::new()
    $feedErrors   = [System.Collections.ArrayList]::new()

    foreach ($feedName in $feedNames) {
      if ($PSCmdlet.ShouldProcess($feedName, 'Delete ProGet NuGet feed')) {
        $uri = "$ProGetBaseUrl/api/management/feeds/delete/$feedName"

        try {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
            -Message "Calling DELETE $uri" -Tag 'RestCall'
          $null = Invoke-RestMethod -Uri $uri -Method Delete -Headers $headers
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
            -Message "ProGet feed deleted: $feedName"
          [void]$deletedFeeds.Add($feedName)
        }
        catch {
          $errMsg = "Failed to delete ProGet feed '$feedName'. Exception: $($_.Exception.Message)"
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errMsg
          [void]$feedErrors.Add($errMsg)
        }
      }
    }

    return [PSCustomObject]@{
      deletedFeeds = $deletedFeeds.ToArray()
      errors       = $feedErrors.ToArray()
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn"
  }
}
