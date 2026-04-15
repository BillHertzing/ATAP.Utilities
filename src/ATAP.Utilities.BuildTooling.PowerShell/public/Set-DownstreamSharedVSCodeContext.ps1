function Set-DownstreamSharedVSCodeContext {
  <#
  .SYNOPSIS
    Applies SharedVSCode settings to the current downstream Git repository.
  .DESCRIPTION
    Reads workspace context(s), then for each:
    - Sets git local commit.template to the resolved commit template path.
    - Generates and writes a stamped .gitattributes at the repo root.
    - Generates and writes a stamped .gitconfig.shared at the repo root.
    - Sets git local include.path to the generated .gitconfig.shared.
    - Sets git local core.hooksPath to the SharedVSCode hooks directory (if it exists).
  .PARAMETER WorkspaceFiles
    One or more paths to .code-workspace files.
  .PARAMETER GitRoot
    Root directory containing all Git repositories.
  .PARAMETER SharedVSCodeRepoName
    Name of the SharedVSCode repository folder.
  .PARAMETER SharedHooksSubPath
    Relative path under SharedVSCode root where hooks live.
  .PARAMETER CommitTemplateRelativePath
    Relative path under SharedVSCode root for the commit template.
  .EXAMPLE
    Set-DownstreamSharedVSCodeContext -WorkspaceFiles @('.\Planning.code-workspace')
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string[]]$WorkspaceFiles,

    [string]$GitRoot = 'C:\dropbox\whertzing\GitHub',
    [string]$SharedVSCodeRepoName = 'SharedVSCode',
    [string]$SharedHooksSubPath = '.githooks',
    [string]$CommitTemplateRelativePath = 'GitTemplates\git.commit.template.txt'
  )

  Assert-GitAvailable
  $repoRoot = Get-RepoRoot

  $contexts = Get-SharedVSCodeContext `
    -WorkspaceFiles $WorkspaceFiles `
    -GitRoot $GitRoot `
    -SharedVSCodeRepoName $SharedVSCodeRepoName `
    -SharedHooksSubPath $SharedHooksSubPath `
    -CommitTemplateRelativePath $CommitTemplateRelativePath

  foreach ($ctx in $contexts) {
    # Set commit template
    $commitTemplateResolved = (Resolve-Path -Path $ctx.CommitTemplate).ProviderPath
    git config --local commit.template $commitTemplateResolved | Out-Null

    # Generate and write downstream .gitattributes
    $generatedGitAttributes = New-GeneratedFileContent -SourcePath $ctx.GitAttributes
    $downstreamGitAttributesPath = Join-Path $repoRoot '.gitattributes'
    Set-Content -Path $downstreamGitAttributesPath -Value $generatedGitAttributes -Encoding UTF8

    # Generate and write downstream .gitconfig.shared
    $generatedGitConfig = New-GeneratedFileContent -SourcePath $ctx.GitConfig
    $downstreamSharedGitConfigPath = Join-Path $repoRoot '.gitconfig.shared'
    Set-Content -Path $downstreamSharedGitConfigPath -Value $generatedGitConfig -Encoding UTF8

    # Point git local config to the shared config include
    git config --local include.path $downstreamSharedGitConfigPath | Out-Null

    # Set hooks path if the hooks directory exists
    if (Test-Path -Path $ctx.HooksPath) {
      $hooksResolved = (Resolve-Path -Path $ctx.HooksPath).ProviderPath
      git config --local core.hooksPath $hooksResolved | Out-Null
    }
  }
}
