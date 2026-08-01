$publicFunctions = @(Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'public') -Filter '*.ps1' -File -ErrorAction SilentlyContinue)
$privateFunctions = @(Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'private') -Filter '*.ps1' -File -ErrorAction SilentlyContinue)
foreach ($import in @($publicFunctions + $privateFunctions)) {
  . $import.FullName
}

Export-ModuleMember -Function @(
  'Assert-MainBranchTemplateRef',
  'Confirm-GitFSCK',
  'Convert-StableWorktreeToConcreteAdapters',
  'Get-BrokenGitSubDirs',
  'Get-LocalPowerShellModulePollerGitScalar',
  'Invoke-GitCommit',
  'Invoke-GitPostCheckoutHook',
  'Invoke-GitPostCommitHook',
  'Invoke-GitPreCommitHook',
  'Invoke-LocalPowerShellModulePollerGit',
  'New-GitHubIssue',
  'New-WorktreeWithJunctions',
  'Set-WorktreeJunctions',
  'Start-LocalPowerShellModuleBuildMasterPoller'
) -Cmdlet @() -Variable @() -Alias @()
