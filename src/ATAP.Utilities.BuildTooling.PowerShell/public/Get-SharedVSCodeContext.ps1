function Get-SharedVSCodeContext {
  <#
  .SYNOPSIS
    Reads one or more workspace files and returns context objects describing
    the SharedVSCode assets each workspace points to.
  .DESCRIPTION
    For each workspace file, extracts the templateRef, resolves the SharedVSCode
    worktree root, validates that required asset files exist, and returns a
    structured context object with all resolved paths.
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
    $contexts = Get-SharedVSCodeContext -WorkspaceFiles @('.\Planning.code-workspace')
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  #>
  [CmdletBinding()]
  [OutputType([PSCustomObject[]])]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string[]]$WorkspaceFiles,

    [string]$GitRoot = 'C:\dropbox\whertzing\GitHub',
    [string]$SharedVSCodeRepoName = 'SharedVSCode',
    [string]$SharedHooksSubPath = '.githooks',
    [string]$CommitTemplateRelativePath = 'GitTemplates\git.commit.template.txt'
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"
  }

  process {
    $resolvedWorkspaceFiles = Resolve-WorkspaceFiles -WorkspaceFiles $WorkspaceFiles
    $results = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($workspaceFile in $resolvedWorkspaceFiles) {
      $json = Get-WorkspaceJson -WorkspaceFile $workspaceFile

      if (-not $json.settings) {
        throw "Workspace '$workspaceFile' is missing the settings object."
      }

      $templateRef = $json.settings.'atap.sharedVSCode.templateRef'
      if ([string]::IsNullOrWhiteSpace($templateRef)) {
        throw "Workspace '$workspaceFile' is missing setting 'atap.sharedVSCode.templateRef'."
      }

      # Local label only; named $profileLabel so it does not shadow $PROFILE.
      $profileLabel = $json.settings.'atap.sharedVSCode.profile'
      if ([string]::IsNullOrWhiteSpace($profileLabel)) {
        $profileLabel = 'default'
      }

      $sharedRoot = Get-SharedVSCodeRootFromTemplateRef `
      -TemplateRef $templateRef `
      -GitRoot $GitRoot `
      -SharedVSCodeRepoName $SharedVSCodeRepoName

    if (-not (Test-Path -Path $sharedRoot)) {
      throw "Resolved SharedVSCode root '$sharedRoot' does not exist for template ref '$templateRef'."
    }

    $gitConfigPath      = Join-Path $sharedRoot '.gitconfig'
    $gitAttributesPath  = Join-Path $sharedRoot '.gitattributes'
    $commitTemplatePath = Join-Path $sharedRoot $CommitTemplateRelativePath
    $hooksPath          = Join-Path $sharedRoot $SharedHooksSubPath

    foreach ($requiredPath in @($gitConfigPath, $gitAttributesPath, $commitTemplatePath)) {
      if (-not (Test-Path -Path $requiredPath)) {
        throw "Required SharedVSCode asset not found: '$requiredPath'."
      }
    }

    $results.Add([PSCustomObject]@{
      WorkspaceFile  = $workspaceFile
      TemplateRef    = $templateRef
      Profile        = $profileLabel
      SharedRoot     = $sharedRoot
      GitConfig      = $gitConfigPath
      GitAttributes  = $gitAttributesPath
      CommitTemplate = $commitTemplatePath
      HooksPath      = $hooksPath
    })
    }

    return [PSCustomObject[]]$results
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn in module $mn"
  }
}
