function Get-SharedVSCodeRootFromTemplateRef {
  <#
  .SYNOPSIS
    Resolves a templateRef string to the absolute path of the SharedVSCode worktree.
  .DESCRIPTION
    "main" maps to GitRoot\SharedVSCodeRepoName. Any other value is treated as
    a peer worktree folder name directly under GitRoot.
  .PARAMETER TemplateRef
    The value of atap.sharedVSCode.templateRef from the workspace file.
  .PARAMETER GitRoot
    Root directory containing all Git repositories.
  .PARAMETER SharedVSCodeRepoName
    Name of the SharedVSCode repository folder.
  #>
  [CmdletBinding()]
  [OutputType([string])]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$TemplateRef,

    [string]$GitRoot = 'C:\dropbox\whertzing\GitHub',

    [string]$SharedVSCodeRepoName = 'SharedVSCode'
  )

  if ($TemplateRef -eq 'main') {
    return (Join-Path $GitRoot $SharedVSCodeRepoName)
  }

  return (Join-Path $GitRoot $TemplateRef)
}
