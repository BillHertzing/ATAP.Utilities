BeforeAll {
  $moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
  . (Join-Path $moduleRoot 'private\Get-SharedVSCodeRootFromTemplateRef.ps1')
}

Describe 'Get-SharedVSCodeRootFromTemplateRef [private]' {
  Context 'When templateRef is "main"' {
    It 'Returns GitRoot\SharedVSCodeRepoName' {
      $result = Get-SharedVSCodeRootFromTemplateRef `
        -TemplateRef 'main' `
        -GitRoot 'C:\repos' `
        -SharedVSCodeRepoName 'SharedVSCode'

      $result | Should -Be (Join-Path 'C:\repos' 'SharedVSCode')
    }
  }

  Context 'When templateRef is a sprint worktree name' {
    It 'Returns GitRoot joined with the worktree name' {
      $ref = 'SharedVSCode-wt-5-sprint-0003-work-items'
      $result = Get-SharedVSCodeRootFromTemplateRef `
        -TemplateRef $ref `
        -GitRoot 'C:\repos'

      $result | Should -Be (Join-Path 'C:\repos' $ref)
    }
  }

  Context 'Default parameter values' {
    It 'Uses the baked-in GitRoot and SharedVSCodeRepoName for main' {
      $result = Get-SharedVSCodeRootFromTemplateRef -TemplateRef 'main'
      $result | Should -Be (Join-Path 'C:\dropbox\whertzing\GitHub' 'SharedVSCode')
    }

    It 'Uses the baked-in GitRoot for sprint refs' {
      $ref = 'SharedVSCode-wt-99-sprint-0010-work-items'
      $result = Get-SharedVSCodeRootFromTemplateRef -TemplateRef $ref
      $result | Should -Be (Join-Path 'C:\dropbox\whertzing\GitHub' $ref)
    }
  }
}
