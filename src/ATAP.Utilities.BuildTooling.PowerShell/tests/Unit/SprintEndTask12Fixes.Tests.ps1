#Requires -Version 7.0

BeforeAll {
  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$Rest) }
  }

  $moduleRoot = Join-Path $PSScriptRoot '..\..'
  foreach ($path in @(
      'private\Get-WorkspaceJson.ps1',
      'private\Resolve-WorkspaceFiles.ps1',
      'private\Invoke-SprintEndNativeCommand.ps1',
      'private\Invoke-SprintEndServiceAccountFreshShell.ps1',
      'public\Assert-MainBranchTemplateRef.ps1',
      'public\Invoke-SprintEndGitHubClose.ps1',
      'public\Set-SprintBoundaryUserProfiles.ps1',
      'public\Test-SprintEndBoundaryState.ps1'
    )) {
    . (Join-Path $moduleRoot $path)
  }
}

Describe 'SprintEnd Task 12 fixes' -Tag 'Unit' {
  Context 'Task 12.10 draft PR merge close' {
    It 'marks a draft pull request ready before squash merge' {
      $script:nativeCalls = [System.Collections.Generic.List[string]]::new()
      $script:viewCount = 0
      $script:issueViewCount = 0
      Mock Invoke-SprintEndNativeCommand {
        $argsText = $ArgumentList -join ' '
        [void]$script:nativeCalls.Add($argsText)
        $output = switch -Regex ($argsText) {
          '^api -i rate_limit$' { @('HTTP/1.1 200 OK', 'X-OAuth-Scopes: repo, read:org', '', '{}'); break }
          'branch --show-current' { @('48-Sprint-0012-work-items'); break }
          'remote get-url origin' { @('https://github.com/BillHertzing/ATAP.Utilities.git'); break }
          'issue view 48' {
            $script:issueViewCount++
            if ($script:issueViewCount -gt 1) {
              @('{"number":48,"state":"CLOSED","title":"Sprint 0012","url":"https://example/48"}')
            } else {
              @('{"number":48,"state":"OPEN","title":"Sprint 0012","url":"https://example/48"}')
            }
            break
          }
          'pr list' { @('[{"number":50,"state":"OPEN","title":"Sprint","body":"Closes #48","url":"https://example/pr/50","mergeable":"MERGEABLE","mergedAt":null}]'); break }
          'pr view 50' {
            $script:viewCount++
            if ($script:viewCount -eq 1) {
              @('{"number":50,"state":"OPEN","mergeable":"MERGEABLE","reviewDecision":"","isDraft":true,"statusCheckRollup":[],"url":"https://example/pr/50","headRefOid":"abc123"}')
            } else {
              @('{"number":50,"state":"OPEN","mergeable":"MERGEABLE","reviewDecision":"","isDraft":false,"statusCheckRollup":[],"url":"https://example/pr/50","headRefOid":"abc123"}')
            }
            break
          }
          'pr checks 50' { @('[]'); break }
          default { @('ok'); break }
        }
        [PSCustomObject]@{
          FilePath = $FilePath; ArgumentList = $ArgumentList; ExitCode = 0
          Output = $output; Succeeded = $true
        }
      }

      $repo = Join-Path $TestDrive 'ATAP.Utilities-wt-48-Sprint-0012-work-items'
      New-Item -ItemType Directory -Path $repo -Force | Out-Null
      $result = Invoke-SprintEndGitHubClose -RepoPath $repo -Merge -Confirm:$false

      $result.Ok | Should -BeTrue
      $result.Actions | Should -Contain 'Marked PR ready for review.'
      $readyIndex = $script:nativeCalls.IndexOf('pr ready 50 --repo BillHertzing/ATAP.Utilities')
      $mergeIndex = $script:nativeCalls.IndexOf('pr merge 50 --repo BillHertzing/ATAP.Utilities --squash --delete-branch')
      $readyIndex | Should -BeGreaterOrEqual 0
      $mergeIndex | Should -BeGreaterThan $readyIndex
    }
  }

  Context 'Task 12.11 templateRef WhatIf' {
    It 'returns a dry-run violation preview instead of throwing' {
      $workspaceFile = Join-Path $TestDrive 'Sprint.code-workspace'
      @{
        folders  = @(@{ path = '.' })
        settings = @{ 'atap.sharedVSCode.templateRef' = 'SharedVSCode-wt-54-Sprint-0012-work-items' }
      } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $workspaceFile -Encoding UTF8

      $result = Assert-MainBranchTemplateRef -WorkspaceFiles @($workspaceFile) -WhatIf

      $result.Ok | Should -BeFalse
      $result.WouldThrow | Should -BeTrue
      $result.Violations[0] | Should -Match 'SharedVSCode-wt-54-Sprint-0012-work-items'
    }
  }

  Context 'Task 12.13 service-account fresh shell' {
    It 'uses a supplied service-account credential for fresh-shell validation' {
      $gitRoot = Join-Path $TestDrive 'gitroot-service-account'
      $utilRoot = Join-Path $gitRoot 'ATAP.Utilities'
      $iacRoot = Join-Path $gitRoot 'ATAP.IAC'
      $serviceHome = Join-Path $TestDrive 'svc-home'
      $serviceSource = Join-Path $utilRoot 'src\ATAP.Utilities.PowerShell\Profiles\ProfileForServiceAccountUsers.ps1'
      $serviceProfile = Join-Path $serviceHome 'Documents\PowerShell\profile.ps1'
      New-Item -ItemType Directory -Path (Split-Path $serviceSource -Parent), $iacRoot, (Split-Path $serviceProfile -Parent) -Force | Out-Null
      Set-Content -LiteralPath $serviceSource -Value '# service stable profile' -Encoding UTF8
      Set-Content -LiteralPath $serviceProfile -Value '# service stable profile' -Encoding UTF8
      $credential = [pscredential]::new('MACHINE\SvcBuildmaster', (ConvertTo-SecureString 'not-used' -AsPlainText -Force))

      Mock Set-SprintBoundaryUserProfiles {
        [PSCustomObject]@{
          Ok = $true
          Profiles = @([PSCustomObject]@{
              Kind = 'ServiceAccount'; Identity = 'SvcBuildmaster'; ProfilePath = $serviceProfile; SourcePath = $serviceSource; Skipped = $false; Warning = $null
            })
          Warnings = @()
          Failures = @()
        }
      }
      Mock Invoke-SprintEndNativeCommand {
        [PSCustomObject]@{
          FilePath = $FilePath; ArgumentList = $ArgumentList; ExitCode = 0
          Output = @('PROFILE_READ_OK', 'SPRINT_END_PROFILE_OK'); Succeeded = $true
        }
      }
      Mock Invoke-SprintEndServiceAccountFreshShell {
        [PSCustomObject]@{
          Identity = $Identity; Tested = $true; Ok = $true; ExitCode = 0; Output = @('SERVICE_ACCOUNT_PROFILE_OK')
        }
      }

      $result = Test-SprintEndBoundaryState `
        -GitRoot $gitRoot `
        -SearchRoots @() `
        -ATAPUtilitiesRoot $utilRoot `
        -ATAPIACRoot $iacRoot `
        -ProhibitedEnvironmentVariableNames @() `
        -TestFreshShell `
        -ServiceAccountCredential @($credential) `
        -RequireServiceAccountFreshShell

      $result.Ok | Should -BeTrue
      $serviceProfileResult = $result.Profiles | Where-Object Kind -EQ 'ServiceAccount' | Select-Object -First 1
      $serviceProfileResult.ServiceAccountFreshShell.Tested | Should -BeTrue
      $serviceProfileResult.ServiceAccountFreshShell.CredentialSupplied | Should -BeTrue
      Should -Invoke Invoke-SprintEndServiceAccountFreshShell -Times 1 -Exactly
    }
  }
}

