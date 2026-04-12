<#
.SYNOPSIS
  Creates a new GitHub issue in the specified repository.
.DESCRIPTION
  Wraps the GitHub CLI (gh) to create an issue with a title, body, and optional labels.
  Returns the newly created issue number as an integer.
.PARAMETER RepoName
  The GitHub repository in 'owner/repo' format. E.g. 'whertzing/ATAP.Utilities'.
.PARAMETER Title
  The title of the GitHub issue.
.PARAMETER Body
  The body text of the GitHub issue.
.PARAMETER Labels
  An optional array of label names to apply to the issue.
.OUTPUTS
  System.Int32
  The issue number of the newly created GitHub issue.
.EXAMPLE
  New-GitHubIssue -RepoName 'whertzing/ATAP.Utilities' -Title 'Bug: foo fails' -Body 'Steps to reproduce...'
.EXAMPLE
  New-GitHubIssue -RepoName 'whertzing/ATAP.Utilities' -Title 'Feature request' -Body 'Please add...' -Labels @('enhancement', 'help wanted')
.NOTES
  AI assisted using Powershell.instructions.md as guidelines
.LINK
  https://github.com/whertzing/ATAP.Utilities
#>
function New-GitHubIssue {
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
  [OutputType([int])]
  param(
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $RepoName,

    [Parameter(Mandatory = $true, Position = 1, ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $Title,

    [Parameter(Mandatory = $true, Position = 2, ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $Body,

    [Parameter(Mandatory = $false, Position = 3, ValueFromPipelineByPropertyName = $true)]
    [string[]] $Labels = @()
  )

  begin {
    $fn = 'New-GitHubIssue'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Entering function'

    # Check and populate simple parameter - RepoName
    $RepoName = Get-PVal -ParameterName RepoName -originalPSBoundParameters $PSBoundParameters -dottedPath RepoName -DefaultValue $RepoName
    # Check and populate simple parameter - Title
    $Title = Get-PVal -ParameterName Title -originalPSBoundParameters $PSBoundParameters -dottedPath Title -DefaultValue $Title
    # Check and populate simple parameter - Body
    $Body = Get-PVal -ParameterName Body -originalPSBoundParameters $PSBoundParameters -dottedPath Body -DefaultValue $Body
  }

  process {
    if ($PSCmdlet.ShouldProcess("$RepoName", "Create GitHub issue '$Title'")) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Creating GitHub issue in '$RepoName' with title '$Title'"

      $issueNumber = $null
      try {
        $labelArgs = $Labels | ForEach-Object { @('--label', $_) }

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Calling gh issue create for repo '$RepoName'"
        $ghOutput = gh issue create `
          --repo $RepoName `
          --title $Title `
          --body $Body `
          @labelArgs
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Successfully returned from gh issue create for repo '$RepoName'"

        # gh outputs a URL like https://github.com/owner/repo/issues/123
        $issueNumber = [int]($ghOutput -replace '.*/issues/(\d+).*', '$1')
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Created GitHub issue #$issueNumber in '$RepoName'"
      } catch {
        $errorMessage = "Failed to create GitHub issue in '$RepoName'. Exception: $($_.Exception.Message)"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
        throw
      } finally {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Leaving PROCESS block'
      }

      return $issueNumber
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Leaving function'
  }
}
