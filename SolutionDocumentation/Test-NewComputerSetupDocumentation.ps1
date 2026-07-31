function Test-NewComputerSetupDocumentation {
  <#
  .SYNOPSIS
  Validates the active NewComputerSetup documentation contract.

  .DESCRIPTION
  Performs a read-only, repeatable validation of the canonical new-computer guide and
  its active BuildMaster runbooks. The validator rejects executable stale sprint paths,
  obsolete Inedo ports, suffixless infrastructure SecretNames, raw-key environment
  variables, and service-account Password Manager session guidance.

  .PARAMETER DocumentationRoot
  The SolutionDocumentation directory to validate.

  .OUTPUTS
  PSCustomObject containing Passed, CheckedFiles, and Findings.

  .EXAMPLE
  . .\Test-NewComputerSetupDocumentation.ps1
  Test-NewComputerSetupDocumentation -DocumentationRoot $PWD

  .NOTES
  This command is intentionally read-only and idempotent. It never resolves a secret,
  contacts a host, or writes an evidence file.

  .LINK
  NewComputerSetup.md
  #>
  [CmdletBinding()]
  param(
    [Parameter()]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [string] $DocumentationRoot = $PSScriptRoot
  )

  begin {
    $fn = 'Test-NewComputerSetupDocumentation'
    $mn = 'ATAP.Utilities.SolutionDocumentation'
    $null = $fn, $mn

    $requiredFiles = @(
      'NewComputerSetup.md'
      'BuildMaster-Install-Runbook.md'
      'Runbook-BuildMasterConfiguration.md'
    )
    $findings = [System.Collections.Generic.List[object]]::new()
  }

  process {
    foreach ($relativePath in $requiredFiles) {
      $path = Join-Path $DocumentationRoot $relativePath
      if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $findings.Add([PSCustomObject]@{
            File = $relativePath
            Rule = 'RequiredFile'
            Line = 0
            Text = 'Required documentation file is missing.'
          })
        continue
      }

      $documentText = Get-Content -LiteralPath $path -Raw
      $documentIsHistorical = $documentText -match '(?im)^> \*\*(?:DEPRECATED|HISTORICAL)'
      $lineNumber = 0
      foreach ($line in Get-Content -LiteralPath $path) {
        $lineNumber++
        $isHistorical = $documentIsHistorical -or $line -match '(?i)historical|archived|non-executable'
        $isExplicitProhibition = $line -match '(?i)\b(?:never|do not|must not|obsolete|retired|no)\b|routing it through'
        $rules = [ordered]@{
          StaleSprintWorktree = 'ATAP\.Utilities-wt-\d+-Sprint-\d{4}'
          StaleSprintBranch = '\b\d+-Sprint-\d{4}-work-items\b'
          ObsoleteInedoPort = '(?<!\d)8600(?!\d)'
          RawProGetKeyEnvironment = '(?i)\bPROGET_[A-Z0-9_]*API[A-Z0-9_]*KEY\b'
          ServiceAccountPasswordManagerSession = '(?i)service account.{0,80}\b(?:bw|BW_SESSION)\b|\b(?:bw|BW_SESSION)\b.{0,80}service account'
        }

        foreach ($rule in $rules.GetEnumerator()) {
          if (-not $isHistorical -and -not $isExplicitProhibition -and $line -match $rule.Value) {
            $findings.Add([PSCustomObject]@{
                File = $relativePath
                Rule = $rule.Key
                Line = $lineNumber
                Text = $line.Trim()
              })
          }
        }

        foreach ($secretBase in @('BuildMaster.Admin.API.Key', 'ProGet.Admin.API.Key', 'ProGet.BuildMaster.API.Key')) {
          if ($isHistorical -or $isExplicitProhibition -or $line -notmatch [regex]::Escape($secretBase)) { continue }
          if ($line -match [regex]::Escape("$secretBase.<service-host>") -or
            $line -match [regex]::Escape("$secretBase.`$serviceHost") -or
            $line -match '\$(?:BuildMasterAdminSecretName|ProGetAdminSecretName|ProGetApiKeySecretName)') {
            continue
          }
          $findings.Add([PSCustomObject]@{
              File = $relativePath
              Rule = 'HostQualifiedSecretName'
              Line = $lineNumber
              Text = $line.Trim()
            })
        }
      }
    }

    $canonicalPath = Join-Path $DocumentationRoot 'NewComputerSetup.md'
    if (Test-Path -LiteralPath $canonicalPath -PathType Leaf) {
      $canonical = Get-Content -LiteralPath $canonicalPath -Raw
      $requiredConcepts = [ordered]@{
        MultiHostIdentity = '(developer, host)'
        ProGetPort = 'port `50000`'
        BuildMasterPort = 'port `50017`'
        SecretBoundary = 'SecretName/Get-SecretATAP/bws'
        ReturnGate = 'bounded return'
        SvcBuildMasterTierGrant = '### 9.2.1 Grant SvcBuildMaster database-package deployment rights'
        SvcBuildMasterTierParity = 'Record this machine-state grant with `Add-ParityChangeEntry`'
      }
      foreach ($concept in $requiredConcepts.GetEnumerator()) {
        if ($canonical -notmatch [regex]::Escape($concept.Value)) {
          $findings.Add([PSCustomObject]@{
              File = 'NewComputerSetup.md'
              Rule = $concept.Key
              Line = 0
              Text = "Required concept is missing: $($concept.Value)"
            })
        }
      }
    }

    [PSCustomObject]@{
      Passed = $findings.Count -eq 0
      CheckedFiles = $requiredFiles
      Findings = @($findings)
    }
  }

  end {
  }
}

if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.InvocationName -ne '&') {
  $result = Test-NewComputerSetupDocumentation
  $result | ConvertTo-Json -Depth 5
  if (-not $result.Passed) { exit 1 }
}
