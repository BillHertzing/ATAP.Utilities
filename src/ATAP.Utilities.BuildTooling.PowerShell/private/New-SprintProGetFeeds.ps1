function New-SprintProGetFeeds {
  <#
  .SYNOPSIS
    Creates per-sprint ProGet NuGet feeds for T1 (experimental) and T2 (development).
  .DESCRIPTION
    Creates two ephemeral ProGet NuGet feeds at sprint start:
      nuget-Sprint{NNNN}-experimental   (T1)
      nuget-Sprint{NNNN}-development    (T2)

    If -Username is supplied, it is appended to both feed names to support the rare
    case where multiple developers work on the same packages in the same sprint:
      nuget-Sprint{NNNN}-experimental-{username}
      nuget-Sprint{NNNN}-development-{username}

    T3 (integration), T4 (qa), and T5 (stable) are permanent feeds and are not
    created here. These feeds are deleted at sprint end by Remove-SprintProGetFeeds.
  .PARAMETER SprintNumber
    The sprint number, zero-padded to 4 digits (e.g., '0006').
  .PARAMETER ProGetBaseUrl
    Base URL for the ProGet server (e.g., 'http://localhost:50000').
  .PARAMETER Username
    Optional. When supplied, appended to both feed names to isolate a developer's
    packages from another developer working on the same packages in the same sprint.
  .OUTPUTS
    PSCustomObject with createdFeeds and errors arrays.
  .EXAMPLE
    New-SprintProGetFeeds -SprintNumber '0006' -ProGetBaseUrl 'http://localhost:50000'
  .EXAMPLE
    New-SprintProGetFeeds -SprintNumber '0006' -ProGetBaseUrl 'http://localhost:50000' -Username 'whertzing'
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  .LINK
    Remove-SprintProGetFeeds
  .LINK
    New-SprintStage2
  #>
  [CmdletBinding(SupportsShouldProcess = $true)]
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
      throw 'PROGET_ADMIN_API_KEY is not set at User scope. Cannot create ProGet feeds.'
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

    $headers = @{
      'X-ApiKey'     = $apiKey
      'Content-Type' = 'application/json'
    }

    $createdFeeds = [System.Collections.ArrayList]::new()
    $feedErrors   = [System.Collections.ArrayList]::new()

    foreach ($feedName in $feedNames) {
      if ($PSCmdlet.ShouldProcess($feedName, 'Create ProGet NuGet feed')) {
        $body = @{
          name     = $feedName
          feedType = 'nuget'
          active   = $true
        } | ConvertTo-Json

        $uri = "$ProGetBaseUrl/api/management/feeds/create"

        try {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
            -Message "Calling $uri" -Tag 'RestCall'
          $null = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $body
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
            -Message "Successfully returned from $uri" -Tag 'RestCall'
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
            -Message "ProGet feed created: $feedName"
          [void]$createdFeeds.Add($feedName)
        }
        catch {
          $errMsg = "Failed to create ProGet feed '$feedName'. Exception: $($_.Exception.Message)"
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errMsg
          [void]$feedErrors.Add($errMsg)
        }
      }
    }

    return [PSCustomObject]@{
      createdFeeds = $createdFeeds.ToArray()
      errors       = $feedErrors.ToArray()
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn"
  }
}
