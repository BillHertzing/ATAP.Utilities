function Reset-DownstreamToSharedVSCodeMain {
  <#
  .SYNOPSIS
    Resets downstream workspace files back to SharedVSCode main, re-applies context,
    and removes the sprint ProGet feeds for the completed sprint.
  .DESCRIPTION
    Sets templateRef to "main" and profile to "default" in all workspace files,
    then re-applies the SharedVSCode context so local Git plumbing points at
    the SharedVSCode main worktree. Also calls Remove-SprintProGetFeeds to clean
    up the sprint-specific ProGet NuGet feeds (experimental and development).
  .PARAMETER WorkspaceFiles
    One or more paths to .code-workspace files.
  .PARAMETER SprintNumber
    The sprint number whose ProGet feeds should be removed (e.g., '0006').
  .PARAMETER GitRoot
    Root directory containing all Git repositories.
  .PARAMETER SharedVSCodeRepoName
    Name of the SharedVSCode repository folder.
  .PARAMETER SharedHooksSubPath
    Relative path under SharedVSCode root where hooks live.
  .PARAMETER CommitTemplateRelativePath
    Relative path under SharedVSCode root for the commit template.
  .PARAMETER ProGetBaseUrl
    Base URL for the ProGet server. Defaults to 'http://localhost:50000'.
  .PARAMETER Username
    The current user's name, used to identify sprint ProGet feeds.
    Defaults to $env:USERNAME.
  .EXAMPLE
    Reset-DownstreamToSharedVSCodeMain -WorkspaceFiles @('.\Planning.code-workspace') -SprintNumber '0006'
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string[]]$WorkspaceFiles,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$SprintNumber,

    [string]$GitRoot = 'C:\dropbox\whertzing\GitHub',
    [string]$SharedVSCodeRepoName = 'SharedVSCode',
    [string]$SharedHooksSubPath = '.githooks',
    [string]$CommitTemplateRelativePath = 'GitTemplates\git.commit.template.txt',
    [string]$ProGetBaseUrl = 'http://localhost:50000',
    [string]$Username = $env:USERNAME
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"

    # Ensure Remove-SprintProGetFeeds is loaded
    $privateDir = Join-Path $PSScriptRoot '..' 'private'
    $removeProGetFeedsPath = Join-Path $privateDir 'Remove-SprintProGetFeeds.ps1'
    if (-not (Get-Command -Name 'Remove-SprintProGetFeeds' -CommandType Function -ErrorAction SilentlyContinue)) {
      if (Test-Path $removeProGetFeedsPath) {
        . $removeProGetFeedsPath
      } else {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error `
          -Message "Remove-SprintProGetFeeds.ps1 not found at $removeProGetFeedsPath"
      }
    }
  }

  process {
    Remove-SprintProGetFeeds `
      -SprintNumber $SprintNumber `
      -ProGetBaseUrl $ProGetBaseUrl `
      -Username $Username

    Set-WorkspaceSharedVSCodeReference `
      -WorkspaceFiles $WorkspaceFiles `
      -TemplateRef 'main' `
      -Profile 'default'

    Set-DownstreamSharedVSCodeContext `
      -WorkspaceFiles $WorkspaceFiles `
      -GitRoot $GitRoot `
      -SharedVSCodeRepoName $SharedVSCodeRepoName `
      -SharedHooksSubPath $SharedHooksSubPath `
      -CommitTemplateRelativePath $CommitTemplateRelativePath
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn"
  }
}
