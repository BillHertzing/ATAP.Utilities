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
  .PARAMETER ProfileName
    The profile label to write. Defaults to "default". Exposed under the alias
    'Profile' for backward compatibility; named ProfileName so it does not shadow
    the automatic $PROFILE variable.
  .EXAMPLE
    Set-WorkspaceSharedVSCodeReference -WorkspaceFiles @('.\Planning.code-workspace') -TemplateRef 'main'
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
    [string]$TemplateRef,

    [Alias('Profile')]
    [string]$ProfileName = 'default'
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"
  }

  process {
    $resolvedWorkspaceFiles = Resolve-WorkspaceFiles -WorkspaceFiles $WorkspaceFiles

    foreach ($workspaceFile in $resolvedWorkspaceFiles) {
      $json = Get-WorkspaceJson -WorkspaceFile $workspaceFile

      if (-not $json.settings) {
        $json | Add-Member -MemberType NoteProperty -Name settings -Value ([PSCustomObject]@{})
      }

      $json.settings | Add-Member -MemberType NoteProperty `
        -Name 'atap.sharedVSCode.templateRef' -Value $TemplateRef -Force
      $json.settings | Add-Member -MemberType NoteProperty `
        -Name 'atap.sharedVSCode.profile' -Value $ProfileName -Force

      Save-WorkspaceJson -WorkspaceFile $workspaceFile -Json $json
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn in module $mn"
  }
}
