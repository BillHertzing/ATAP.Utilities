function Assert-MainBranchTemplateRef {
  <#
  .SYNOPSIS
    Validates that all workspace files point to SharedVSCode "main".
  .DESCRIPTION
    Reads each workspace file and checks that atap.sharedVSCode.templateRef
    equals "main". If any workspace points to a sprint ref or is missing the
    setting, throws an error listing the offending files. Intended for
    CI/CD gates on PRs targeting downstream main.
  .PARAMETER WorkspaceFiles
    One or more paths to .code-workspace files to validate.
  .EXAMPLE
    Assert-MainBranchTemplateRef -WorkspaceFiles @('.\Planning.code-workspace')
  .NOTES
    Exit code is non-zero (via throw) if validation fails, making this
    suitable for pipeline steps.
  #>
  [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string[]]$WorkspaceFiles
  )

  $resolvedWorkspaceFiles = Resolve-WorkspaceFiles -WorkspaceFiles $WorkspaceFiles
  $violations = [System.Collections.Generic.List[string]]::new()

  foreach ($workspaceFile in $resolvedWorkspaceFiles) {
    $json = Get-WorkspaceJson -WorkspaceFile $workspaceFile

    $templateRef = $null
    if ($json.settings) {
      $templateRef = $json.settings.'atap.sharedVSCode.templateRef'
    }

    if ([string]::IsNullOrWhiteSpace($templateRef)) {
      $violations.Add("$workspaceFile - templateRef is missing or empty")
    }
    elseif ($templateRef -ne 'main') {
      $violations.Add("$workspaceFile - templateRef is '$templateRef' (expected 'main')")
    }
  }

  if ($violations.Count -gt 0) {
    $message = "Merge-gate violation: the following workspace files do not point to SharedVSCode 'main':`n"
    $message += ($violations | ForEach-Object { "  - $_" }) -join "`n"
    if (-not $WhatIfPreference) {
      throw $message
    }
    [void]$PSCmdlet.ShouldProcess(($resolvedWorkspaceFiles -join ', '), "Throw templateRef merge-gate violation for $($violations.Count) workspace file(s)")

    return [PSCustomObject]@{
      Ok         = $false
      WhatIf     = $true
      WouldThrow = $true
      Violations = $violations.ToArray()
      Message    = $message
    }
  }

  return [PSCustomObject]@{
    Ok         = $true
    WhatIf     = [bool]$WhatIfPreference
    WouldThrow = $false
    Violations = @()
    Message    = "All workspace files point to SharedVSCode 'main'."
  }
}
