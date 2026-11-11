# Import only module-owned function definitions. Validate every file before loading any.
$functionFiles = @(
  foreach ($folder in @('private', 'public')) {
    $directory = Join-Path $PSScriptRoot $folder
    if (Test-Path -LiteralPath $directory -PathType Container) {
      Get-ChildItem -LiteralPath $directory -Filter '*.ps1' -File | Sort-Object Name
    }
  }
)
foreach ($file in $functionFiles) {
  $tokens = $null
  $parseErrors = $null
  $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref] $tokens, [ref] $parseErrors)
  if ($parseErrors.Count -gt 0 -or $null -ne $ast.ParamBlock -or $null -ne $ast.BeginBlock -or
      $null -ne $ast.ProcessBlock -or $null -ne $ast.DynamicParamBlock -or $null -ne $ast.CleanBlock -or
      $ast.UsingStatements.Count -gt 0 -or $null -ne $ast.ScriptRequirements -or
      ($null -ne $ast.EndBlock -and $ast.EndBlock.Traps.Count -gt 0) -or
      @($ast.EndBlock.Statements | Where-Object { $_ -isnot [System.Management.Automation.Language.FunctionDefinitionAst] }).Count -gt 0) {
    throw "Module helper must contain only function definitions: $($file.FullName)"
  }
}
foreach ($file in $functionFiles) { . $file.FullName }
Export-ModuleMember -Function @('Get-CoordTask', 'Get-CoordResult', 'Get-CoordClaims', 'Stop-CoordClerk', 'Submit-CoordRequest', 'Invoke-CoordClerk', 'Export-CoordState', 'Restore-CoordState', 'Update-CoordWitness') -Alias @() -Cmdlet @() -Variable @()
