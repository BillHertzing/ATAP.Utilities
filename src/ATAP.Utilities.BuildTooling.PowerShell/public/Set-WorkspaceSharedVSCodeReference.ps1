function Set-WorkspaceSharedVSCodeReference {
  <#
  .SYNOPSIS
    Updates the atap.sharedVSCode.templateRef and profile in workspace files.
  .DESCRIPTION
    For each workspace file, reads JSON, ensures the settings object exists,
    writes templateRef and profile, and saves back.
  .PARAMETER WorkspaceFiles
    One or more paths to .code-workspace files.
  .PARAMETER TemplateRef
    The SharedVSCode template reference to write (e.g. "main" or a worktree name).
  .PARAMETER Profile
    The profile label to write. Defaults to "default".
  .EXAMPLE
    Set-WorkspaceSharedVSCodeReference -WorkspaceFiles @('.\Planning.code-workspace') -TemplateRef 'main'
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string[]]$WorkspaceFiles,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$TemplateRef,

    [string]$Profile = 'default'
  )

  $resolvedWorkspaceFiles = Resolve-WorkspaceFiles -WorkspaceFiles $WorkspaceFiles

  foreach ($workspaceFile in $resolvedWorkspaceFiles) {
    $json = Get-WorkspaceJson -WorkspaceFile $workspaceFile

    if (-not $json.settings) {
      $json | Add-Member -MemberType NoteProperty -Name settings -Value ([PSCustomObject]@{})
    }

    $json.settings | Add-Member -MemberType NoteProperty `
      -Name 'atap.sharedVSCode.templateRef' -Value $TemplateRef -Force
    $json.settings | Add-Member -MemberType NoteProperty `
      -Name 'atap.sharedVSCode.profile' -Value $Profile -Force

    Save-WorkspaceJson -WorkspaceFile $workspaceFile -Json $json
  }
}
