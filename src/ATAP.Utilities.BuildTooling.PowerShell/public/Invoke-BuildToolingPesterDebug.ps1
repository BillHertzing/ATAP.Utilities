function Invoke-BuildToolingPesterDebug {
  [CmdletBinding()]
  param (
    [string]$TestPath = "$PSScriptRoot/../tests/unit",
    [string[]]$Tag,
    [string[]]$ExcludeTag,
    [ValidateSet('NUnitXml', 'JUnitXml', 'LegacyNUnitXml', 'None')]
    [string]$OutputFormat = 'None'
  )


  $cfg = Get-MergedPesterConfigurations

  # Override settings for debug/dev run
  $cfg.Run.Path = $TestPath
  $cfg.Output.Verbosity = 'Detailed'
  $cfg.Run.Exit = $true
  $cfg.Run.Throw = $true

  if ($Tag) { $cfg.Filter.Tag = $Tag }
  if ($ExcludeTag) { $cfg.Filter.ExcludeTag = $ExcludeTag }

  if ($OutputFormat -ne 'None') {
    $cfg.TestResult.Enabled = $true
    $cfg.TestResult.OutputFormat = $OutputFormat
    $cfg.TestResult.OutputPath = "$TestPath/TestResults.xml"
  }

  Write-Verbose "Running tests in '$TestPath' with config: $($cfg | Out-String)"
  Invoke-Pester -Configuration $cfg
}

Export-ModuleMember -Function Invoke-BuildToolingPesterDebug
