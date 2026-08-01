$publicFunctions = @(Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'public') -Filter '*.ps1' -File -ErrorAction SilentlyContinue)
$privateFunctions = @(Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'private') -Filter '*.ps1' -File -ErrorAction SilentlyContinue)
foreach ($import in @($publicFunctions + $privateFunctions)) {
  . $import.FullName
}

Export-ModuleMember -Function @(
  'Build-AgentSpecificPerRepository',
  'Build-AGENTSPerRepository',
  'Build-AIInstructionsPerRepository',
  'Build-CLAUDEPerRepository',
  'Convert-DiagramsToImages',
  'Get-NumberOfFailingTestsFromTRX',
  'Invoke-FailureAcknowledgedGate',
  'Reset-DownstreamToSharedVSCodeMain',
  'Set-ClaudeSettingsSymlink',
  'Test-FailureAcknowledgedGate',
  'Test-PairedAgentTextSuite'
) -Cmdlet @() -Variable @() -Alias @()
