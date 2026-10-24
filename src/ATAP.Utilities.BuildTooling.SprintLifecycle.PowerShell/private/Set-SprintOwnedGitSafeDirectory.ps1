function Set-SprintOwnedGitSafeDirectory {
  <#
  .SYNOPSIS
    Manages only Git trust introduced by this host's sprint Start boundary.
  .DESCRIPTION
    Per-checkout generated receipts bind ownership to the caller, host, explicit
    configuration and exact value. Missing or invalid evidence preserves trust.
    End retires ownership before removing a value, so a retry cannot remove a
    subsequently re-added value. An interrupted removal requires manual review.
    Receipts are operational evidence, not an authorization boundary against a
    caller who can already edit both the checkout and the Git configuration.
  #>
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [Parameter(Mandatory)][ValidateSet('Start', 'End')][string]$Boundary,
    [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$WorktreePaths,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$GitConfigPath,
    [ValidateNotNullOrEmpty()][string[]]$RepositoryNames = @('Ace', 'ATAP.Utilities'),
    [ValidateNotNullOrEmpty()][string]$GitExecutable = 'git'
  )
  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering $fn ($Boundary)"
    if (-not (Get-Command Set-ServiceAccountGitSafeDirectory -ErrorAction SilentlyContinue)) {
      $helperPath = Join-Path $PSScriptRoot '../public/Set-ServiceAccountGitSafeDirectory.ps1'
      if (-not (Test-Path -LiteralPath $helperPath -PathType Leaf)) { throw "Required helper unavailable: $helperPath" }
      . $helperPath
    }
    $config = [IO.Path]::GetFullPath($GitConfigPath).Replace('\', '/')
    $hostName = [Environment]::MachineName
    $identity = if ($IsWindows) { [Security.Principal.WindowsIdentity]::GetCurrent().User.Value } else { [Environment]::UserName }
    $selected = [Collections.Generic.List[string]]::new()
    $added = [Collections.Generic.List[string]]::new()
    $removed = [Collections.Generic.List[string]]::new()
    $unchanged = [Collections.Generic.List[string]]::new()
    $preserved = [Collections.Generic.List[object]]::new()
    $receipts = [Collections.Generic.List[string]]::new()
  }
  process {
    foreach ($candidate in $WorktreePaths) {
      if ([string]::IsNullOrWhiteSpace($candidate)) { continue }
      $path = [IO.Path]::GetFullPath($candidate).TrimEnd('\', '/').Replace('\', '/')
      $leaf = Split-Path $path -Leaf
      $eligible = @($RepositoryNames | Where-Object { $leaf -match ('^' + [regex]::Escape($_) + '-wt-\d+-Sprint-\d+-work-items$') }).Count -gt 0
      if (-not $eligible -or $selected.Contains($path)) { continue }
      [void]$selected.Add($path)
      if ($Boundary -eq 'Start' -and -not (Test-Path -LiteralPath (Join-Path $path '.git'))) {
        [void]$preserved.Add([pscustomobject]@{ Path = $path; Reason = 'CheckoutMissing' })
        continue
      }
      $key = "$hostName`n$identity`n$config`n$path"
      $digest = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($key)))
      $receiptPath = Join-Path $path "_generated/SprintGitTrust/$digest.json"
      $receipt = $null
      $receiptValid = $false
      if (Test-Path -LiteralPath $receiptPath -PathType Leaf) {
        try {
          $receipt = Get-Content -LiteralPath $receiptPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
          $receiptValid = ($receipt.SchemaVersion -ceq '1' -and $receipt.HostName -ceq $hostName -and
            $receipt.Identity -ceq $identity -and $receipt.GitConfigPath -ceq $config -and
            $receipt.Path -ceq $path -and $receipt.State -cin @('Owned', 'Retired', 'Consumed'))
        } catch {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Invalid trust receipt '$receiptPath'; preserving trust."
        }
        if (-not $receiptValid) {
          [void]$preserved.Add([pscustomobject]@{ Path = $path; Reason = 'InvalidReceipt' })
          continue
        }
      }
      $parameters = @{ Boundary = $Boundary; WorktreePaths = @($path); GitConfigPath = $config; RepositoryNames = $RepositoryNames; GitExecutable = $GitExecutable; Confirm = $false }
      if ($Boundary -eq 'End' -and (-not $receiptValid -or $receipt.State -cne 'Owned')) {
        [void]$preserved.Add([pscustomobject]@{ Path = $path; Reason = $(if ($receiptValid) { 'OwnershipRetired' } else { 'ReceiptMissing' }) })
        continue
      }
      if ($WhatIfPreference) {
        $result = Set-ServiceAccountGitSafeDirectory @parameters -WhatIf
      } elseif ($PSCmdlet.ShouldProcess($config, "$Boundary exact sprint Git trust with ownership receipt for '$path'")) {
        try {
          if ($Boundary -eq 'End') {
            # Persist before mutation. If Git or the final receipt write fails,
            # retries preserve trust rather than replaying an old ownership claim.
            $receipt.State = 'Retired'
            $receipt | ConvertTo-Json | Set-Content -LiteralPath $receiptPath -Encoding utf8 -ErrorAction Stop
          }
          $result = Set-ServiceAccountGitSafeDirectory @parameters -WhatIf:$false
          if ($null -eq $result -or -not $result.Success -or $result.DryRun) { throw 'Git trust helper did not confirm an applied result.' }
          if ($Boundary -eq 'Start' -and @($result.Added).Count -gt 0) {
            # This is the only place ownership is created. Repeat Start keeps
            # an existing Owned receipt, but cannot claim a pre-existing entry.
            $receipt = [ordered]@{ SchemaVersion = '1'; HostName = $hostName; Identity = $identity; GitConfigPath = $config; Path = $path; State = 'Owned' }
            New-Item -ItemType Directory -Path (Split-Path $receiptPath -Parent) -Force -ErrorAction Stop | Out-Null
            $receipt | ConvertTo-Json | Set-Content -LiteralPath $receiptPath -Encoding utf8 -ErrorAction Stop
          } elseif ($Boundary -eq 'End') {
            $receipt.State = 'Consumed'
            $receipt | ConvertTo-Json | Set-Content -LiteralPath $receiptPath -Encoding utf8 -ErrorAction Stop
          }
        } catch {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Sprint Git trust failed for '$path': $($_.Exception.Message)"
          throw
        }
      } else { continue }
      foreach ($value in @($result.Added)) { [void]$added.Add($value) }
      foreach ($value in @($result.Removed)) { [void]$removed.Add($value) }
      foreach ($value in @($result.Unchanged)) { [void]$unchanged.Add($value) }
      if (Test-Path -LiteralPath $receiptPath -PathType Leaf) { [void]$receipts.Add($receiptPath) }
    }
  }
  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving $fn"
    [pscustomobject]@{ Boundary = $Boundary; GitConfigPath = $config; Success = $true; DryRun = [bool]$WhatIfPreference; SelectedPaths = $selected.ToArray(); Added = $added.ToArray(); Removed = $removed.ToArray(); Unchanged = $unchanged.ToArray(); Preserved = $preserved.ToArray(); Receipts = $receipts.ToArray() }
  }
}
