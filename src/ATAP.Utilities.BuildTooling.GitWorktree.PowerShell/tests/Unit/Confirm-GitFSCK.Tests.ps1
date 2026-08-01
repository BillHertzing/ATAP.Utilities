BeforeAll {
  $moduleRoot = Join-Path $PSScriptRoot '..\..'
  Import-Module (Join-Path $moduleRoot 'ATAP.Utilities.BuildTooling.GitWorktree.PowerShell.psd1') -Force
}

Describe 'Confirm-GitFSCK [public]' {
  It 'supports an empty repository root and writes a JSON result without invoking git' {
    $repositoryRoot = Join-Path $TestDrive 'repositories'
    $outputDirectory = Join-Path $TestDrive 'reports'
    New-Item -ItemType Directory -Path $repositoryRoot, $outputDirectory -Force | Out-Null
    $outputPath = Join-Path $outputDirectory 'Confirm-GitFSCK-Results.json'

    { Confirm-GitFSCK -Path $repositoryRoot -OutPath $outputPath } | Should -Not -Throw

    $outputPath | Should -Exist
    { Get-Content -LiteralPath $outputPath -Raw | ConvertFrom-Json } | Should -Not -Throw
  }

  It 'exposes the frozen Path and OutPath parameters' {
    $command = Get-Command Confirm-GitFSCK -Module ATAP.Utilities.BuildTooling.GitWorktree.PowerShell
    $command.Parameters.Keys | Should -Contain 'Path'
    $command.Parameters.Keys | Should -Contain 'OutPath'
  }
}
