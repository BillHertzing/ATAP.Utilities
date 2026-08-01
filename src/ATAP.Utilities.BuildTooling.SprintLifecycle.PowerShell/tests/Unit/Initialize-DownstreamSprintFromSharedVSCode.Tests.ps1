BeforeAll {
  $moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
  $srcRoot = Split-Path -Parent $moduleRoot

  # Resolve cross-module helpers by SEARCHING the BuildTooling family instead of pinning
  # one module folder. The Task 13.72 extractions move functions between the parent and
  # the children; a pinned path silently goes stale and takes this whole file down with a
  # dot-source failure (that is how the sibling DatabaseManagement suite lost all six of
  # its tests when Get-DbConnectionStringSecretDescriptor moved to the Secrets child).
  function script:Resolve-FamilyScript {
    param(
      [Parameter(Mandatory)][string] $FileName,
      [ValidateSet('public', 'private')][string] $Folder = 'public'
    )
    $found = Get-ChildItem -LiteralPath $srcRoot -Directory -ErrorAction SilentlyContinue |
      Where-Object { $_.Name -like 'ATAP.Utilities.BuildTooling.*' } |
      ForEach-Object { Join-Path $_.FullName "$Folder\$FileName" } |
      Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
      Select-Object -First 1
    if (-not $found) {
      throw "$FileName was not found in any ATAP.Utilities.BuildTooling.*\$Folder folder under $srcRoot."
    }
    return $found
  }

  . (script:Resolve-FamilyScript -FileName 'Get-WorkspaceJson.ps1')
  . (script:Resolve-FamilyScript -FileName 'Save-WorkspaceJson.ps1' -Folder 'private')
  . (script:Resolve-FamilyScript -FileName 'Resolve-WorkspaceFiles.ps1')
  . (script:Resolve-FamilyScript -FileName 'Set-WorkspaceSharedVSCodeReference.ps1')
  . (Join-Path $moduleRoot 'public\Initialize-DownstreamSprintFromSharedVSCode.ps1')
}

Describe 'Initialize-DownstreamSprintFromSharedVSCode [public]' {
  BeforeAll {
    $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "ids_test_$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $script:tempDir -Force | Out-Null

    $script:wsFile = Join-Path $script:tempDir 'Test.code-workspace'
    @{
      folders  = @(@{ path = '.' })
      settings = @{
        'atap.sharedVSCode.templateRef' = 'main'
        'atap.sharedVSCode.profile'     = 'default'
      }
    } | ConvertTo-Json -Depth 10 | Set-Content -Path $script:wsFile -Encoding UTF8
  }

  AfterAll {
    Remove-Item -Path $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
  }

  BeforeEach {
    Mock Set-DownstreamSharedVSCodeContext { }
  }

  It 'Writes the sprint templateRef into the workspace file' {
    $sprintRef = 'SharedVSCode-wt-5-sprint-0003-work-items'

    Initialize-DownstreamSprintFromSharedVSCode `
      -WorkspaceFiles @($script:wsFile) `
      -TemplateRef $sprintRef `
      -Profile 'sprint-0003'

    $result = Get-WorkspaceJson -WorkspaceFile $script:wsFile
    $result.settings.'atap.sharedVSCode.templateRef' | Should -Be $sprintRef
    $result.settings.'atap.sharedVSCode.profile' | Should -Be 'sprint-0003'
  }

  It 'Delegates to Set-WorkspaceSharedVSCodeReference (public) for the pointer update' {
    Mock Set-WorkspaceSharedVSCodeReference { }

    Initialize-DownstreamSprintFromSharedVSCode `
      -WorkspaceFiles @($script:wsFile) `
      -TemplateRef 'SharedVSCode-wt-5-sprint-0003-work-items'

    Should -Invoke Set-WorkspaceSharedVSCodeReference -Times 1 -Exactly -Scope It
  }

  It 'Delegates to Set-DownstreamSharedVSCodeContext (public) for plumbing' {
    Initialize-DownstreamSprintFromSharedVSCode `
      -WorkspaceFiles @($script:wsFile) `
      -TemplateRef 'SharedVSCode-wt-5-sprint-0003-work-items'

    Should -Invoke Set-DownstreamSharedVSCodeContext -Times 1 -Exactly -Scope It
  }

  It 'Defaults Profile to "default" when not specified' {
    Initialize-DownstreamSprintFromSharedVSCode `
      -WorkspaceFiles @($script:wsFile) `
      -TemplateRef 'SharedVSCode-wt-5-sprint-0003-work-items'

    $result = Get-WorkspaceJson -WorkspaceFile $script:wsFile
    $result.settings.'atap.sharedVSCode.profile' | Should -Be 'default'
  }
}
