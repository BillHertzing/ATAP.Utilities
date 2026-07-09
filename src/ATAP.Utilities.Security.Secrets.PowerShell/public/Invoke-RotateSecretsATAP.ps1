<#
.SYNOPSIS
Rotates the ATAP Bitwarden machine-account access tokens on the current host for the current
Windows identity, from values the operator pastes into individually labeled prompts.

.DESCRIPTION
Invoke-RotateSecretsATAP is the write half of an access-token rotation whose read half is
performed by a human in the Bitwarden UI. The function GENERATES NOTHING. The operator
regenerates each machine-account access token by hand, out of band, then pastes each value into
a separate prompt that names the machine account it belongs to.

For each token in the rotation set, in fixed order, the function:

1. prompts once with Read-Host -AsSecureString, naming the machine account;
2. rejects an empty paste and (unless -SkipTokenFormatValidation) a value that does not have the
   `0.<uuid>.<secret>` bws shape;
3. emits a non-revealing confirmation -- character length plus a 12-character SHA-256 prefix -- so
   a truncated or swapped paste is caught before anything is written;
4. writes the DPAPI token file via Initialize-BWSAccessToken -TokenPurpose;
5. reads the file back with Get-BWSAccessToken -TokenPurpose and asserts the fingerprint matches,
   proving the value landed in the slot it was typed for.

DPAPI token files are bound to one host and one Windows identity, so this function must be run
once per host, once per identity. It never copies a token file between accounts or machines.

Rotation set (closed at exactly two entries this iteration; the table is data-driven so future
secret classes can be added, but adding one is a reviewed change, not a parameter):

  order 1  CommonCIForBitwardenReadOnly   -> -TokenPurpose ReadOnly
  order 2  CommonCIForBitwardenReadWrite  -> -TokenPurpose ReadWrite

The order is not cosmetic. This function authenticates to Bitwarden with the ReadWrite
machine-account token, which is one of the two tokens it rotates. Rotating ReadWrite last keeps
the running session's credential valid for as long as possible: a failure while rotating ReadOnly
leaves the operator with a working ReadWrite token to recover with.

INTERACTIVE-ONLY LIVE PATH. The live path cannot run from an agent shell, a scheduled task, CI,
or any session whose standard input is redirected. Such a session is rejected in BEGIN, before
any token file is written, with a single terminating error. It never half-rotates and never falls
through to an empty value. -WhatIf is exempt: a dry run writes nothing, so it prompts for nothing
and runs from any shell.

No token value is ever echoed, logged, thrown, or written to a transcript. PSFramework messages
carry the machine-account label, the token purpose, the file path, the value's length, and its
fingerprint prefix -- never the value.

.PARAMETER TokenLabel
Restricts the rotation to a subset of the rotation set. Defaults to both machine accounts.
Rotation always proceeds in the fixed ReadOnly-then-ReadWrite order regardless of the order in
which labels are supplied.

.PARAMETER CredentialDirectory
Absolute path to the protected credential folder holding the DPAPI token files. Defaults to
`C:\ProgramData\ATAP\BitwardenCredentials\<SamAccountName>`, matching Initialize-BWSAccessToken.

.PARAMETER SkipTokenFormatValidation
Accepts a pasted value that does not match the `0.<uuid>.<secret>` bws token shape. Provided only
so a future change to Bitwarden's token format cannot hard-block a rotation. Using it discards the
strongest available mis-paste guard.

.PARAMETER FingerprintLength
Number of SHA-256 hex characters shown in the paste confirmation. Defaults to 12.

.OUTPUTS
PSCustomObject, one per rotation-set entry, with TokenLabel, TokenPurpose, ComputerName, Identity,
TokenPath, Action ('Rotated' or 'WouldRotate'), TokenLength, Fingerprint, Verified, and Timestamp.
TokenLength and Fingerprint are $null on a -WhatIf dry run, because nothing was read.

.EXAMPLE
Invoke-RotateSecretsATAP -WhatIf

Enumerates what would rotate on this host for this identity -- machine account, token purpose, and
target DPAPI file path -- prompting for nothing and writing nothing. Safe from any shell.

.EXAMPLE
Invoke-RotateSecretsATAP

Prompts for the CommonCIForBitwardenReadOnly token, then the CommonCIForBitwardenReadWrite token,
confirming each paste by length and fingerprint, and writes both DPAPI files. Must be run from a
real interactive terminal.

.EXAMPLE
Invoke-RotateSecretsATAP -TokenLabel 'CommonCIForBitwardenReadOnly'

Rotates only the read-only machine-account token, leaving the read/write slot untouched.

.NOTES
AI assisted using Powershell.instructions.md as guidelines.

Design decisions D1-D7 are binding and recorded in
Documentation/Invoke-RotateSecretsATAP.DesignDecisions.md. In particular: this function calls no
PKI function (D1); the rotation set is closed at two tokens (D2); it generates nothing (D3); the
live path is human-only and fails terminating in a non-interactive session (D4.1, D4.2).

After a rotation, every other identity on this host -- and every identity on every other host --
still holds the old token in its own DPAPI file. Sprint 0012 Task 12.56 enumerates those identities
from the SolutionDocumentation/NewComputerSetup.md account matrix and repeats the rotation for each.

.LINK
https://bitwarden.com/help/secrets-manager-cli/

.LINK
https://github.com/whertzing/ATAP.Utilities
#>
function Invoke-RotateSecretsATAP {
  # CredentialDirectory is a filesystem path, not a credential. PSScriptAnalyzer flags any [string]
  # parameter whose name contains 'Credential'. The token values themselves are never [string]:
  # they exist only as SecureString, from Read-Host to Initialize-BWSAccessToken.
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'CredentialDirectory')]
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory = $false)]
    [ValidateSet('CommonCIForBitwardenReadOnly', 'CommonCIForBitwardenReadWrite')]
    [string[]]$TokenLabel = @('CommonCIForBitwardenReadOnly', 'CommonCIForBitwardenReadWrite'),

    [Parameter(Mandatory = $false)]
    [string]$CredentialDirectory,

    [Parameter(Mandatory = $false)]
    [switch]$SkipTokenFormatValidation,

    [Parameter(Mandatory = $false)]
    [ValidateRange(4, 64)]
    [int]$FingerprintLength = 12
  )

  BEGIN {
    $fn = 'Invoke-RotateSecretsATAP'
    $mn = 'ATAP.Utilities.Security.Secrets.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started' -Tag 'secret-rotation'

    # Load helper functions.
    # Get-BWSAccessToken and Initialize-BWSAccessToken still live in
    # ATAP.Utilities.BuildTooling.PowerShell, which the manifest now pins at a 0.1.29 minimum for
    # their -TokenPurpose parameter. Importing this module therefore normally imports them first,
    # and the Function: provider check below short-circuits. The sibling-source fallback remains
    # for running this file straight from the source tree without a module import, and the
    # Function: check also means a Pester mock -- injected as a function in this module's scope --
    # is never overwritten by a dot-source.
    $helpFunctionsNeeded = @(
      @{ FunctionName = 'Get-BWSAccessToken'; ModuleName = 'ATAP.Utilities.BuildTooling.PowerShell' }
      @{ FunctionName = 'Initialize-BWSAccessToken'; ModuleName = 'ATAP.Utilities.BuildTooling.PowerShell' }
    )
    $siblingSourceRoot = Join-Path $PSScriptRoot '..' '..'
    foreach ($helpFunction in $helpFunctionsNeeded) {
      $helperPath = Join-Path $siblingSourceRoot $helpFunction.ModuleName 'public' "$($helpFunction.FunctionName).ps1"
      try {
        if (-not (Test-Path -LiteralPath "Function:\$($helpFunction.FunctionName)")) {
          if (Test-Path -LiteralPath $helperPath) {
            . $helperPath
          }
          elseif (-not (Get-Command -Name $helpFunction.FunctionName -ErrorAction SilentlyContinue)) {
            throw "Neither an installed nor a source copy of $($helpFunction.FunctionName) could be found. Looked for '$helperPath'."
          }
        }
      }
      catch {
        $errorMessage = "Failed to load $($helpFunction.FunctionName) from '$helperPath'. Exception: $($_.Exception.Message)"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage -Tag 'secret-rotation'
        throw
      }
    }
    # End of the helper-loading block.

    # The rotation set. Data-driven and extensible by design, but CLOSED AT TWO ENTRIES for this
    # iteration (design decision D2). Adding a row is a reviewed change with its own consumer map,
    # not a runtime option. Order is load-bearing: see the self-eviction note in the .DESCRIPTION.
    $rotationSet = @(
      [PSCustomObject]@{ Order = 1; TokenLabel = 'CommonCIForBitwardenReadOnly'; TokenPurpose = 'ReadOnly' }
      [PSCustomObject]@{ Order = 2; TokenLabel = 'CommonCIForBitwardenReadWrite'; TokenPurpose = 'ReadWrite' }
    )

    $selectedTargets = @(
      $rotationSet | Where-Object { $TokenLabel -contains $_.TokenLabel } | Sort-Object Order
    )
    if ($selectedTargets.Count -eq 0) {
      $PSCmdlet.ThrowTerminatingError(
        [System.Management.Automation.ErrorRecord]::new(
          [System.InvalidOperationException]::new('No rotation target matched -TokenLabel. Nothing to do.'),
          'NoRotationTargetSelected',
          [System.Management.Automation.ErrorCategory]::InvalidArgument,
          $TokenLabel))
    }

    # Derive the identity from the Windows token, not $env:USERNAME, so the file name matches the
    # DPAPI key even under Start-Process -Credential. This mirrors Initialize-BWSAccessToken.
    $currentSamName = ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name -split '\\') | Select-Object -Last 1
    if ([string]::IsNullOrWhiteSpace($CredentialDirectory)) {
      $CredentialDirectory = "C:\ProgramData\ATAP\BitwardenCredentials\$currentSamName"
    }

    # A dry run writes nothing, so it prompts for nothing, so it needs no console (D4.6).
    # A live run without a console would read EOF at the first prompt and write an empty token.
    # Reject it here, in BEGIN, before the first write -- never mid-rotation (D4.2).
    if (-not $WhatIfPreference) {
      if (-not (Test-RotationSessionIsInteractive)) {
        $message = "Invoke-RotateSecretsATAP requires an interactive terminal: it reads $($selectedTargets.Count) pasted token value(s) with Read-Host. This session has no attached console (agent shell, scheduled task, CI, or -NonInteractive), so the prompt for '$($selectedTargets[0].TokenLabel)' cannot be answered. No token file was written. Re-run from a real interactive terminal, or use -WhatIf for a dry run."
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $message -Tag 'secret-rotation'
        $PSCmdlet.ThrowTerminatingError(
          [System.Management.Automation.ErrorRecord]::new(
            [System.InvalidOperationException]::new($message),
            'NonInteractiveSessionCannotRotate',
            [System.Management.Automation.ErrorCategory]::InvalidOperation,
            $fn))
      }
    }
  }

  PROCESS {
    foreach ($target in $selectedTargets) {
      $tokenFileName = "$env:COMPUTERNAME`_$currentSamName`_BWS_$($target.TokenLabel)`_AccessToken.xml"
      $tokenPath = Join-Path $CredentialDirectory $tokenFileName

      $result = [PSCustomObject]@{
        TokenLabel   = $target.TokenLabel
        TokenPurpose = $target.TokenPurpose
        ComputerName = $env:COMPUTERNAME
        Identity     = $currentSamName
        TokenPath    = $tokenPath
        Action       = 'WouldRotate'
        TokenLength  = $null
        Fingerprint  = $null
        Verified     = $false
        Timestamp    = [DateTimeOffset]::UtcNow.ToString('o')
      }

      $shouldProcessMessage = "Rotate the $($target.TokenPurpose) machine-account access token for '$($target.TokenLabel)' (prompts for a pasted value, then overwrites the DPAPI file)"
      if (-not $PSCmdlet.ShouldProcess($tokenPath, $shouldProcessMessage)) {
        # -WhatIf, or the operator declined at -Confirm. Emit the plan row and move on. No prompt,
        # no read, no write.
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Dry run: would rotate '$($target.TokenLabel)' ($($target.TokenPurpose)) into '$tokenPath'" -Tag 'secret-rotation'
        $result
        continue
      }

      $pastedToken = $null
      try {
        $prompt = "Paste the NEW access token for machine account '$($target.TokenLabel)' [$($target.TokenPurpose)] (input is hidden)"
        $pastedToken = Read-Host -Prompt $prompt -AsSecureString

        if ($null -eq $pastedToken -or $pastedToken.Length -eq 0) {
          $message = "No value was entered for '$($target.TokenLabel)'. Rotation aborted before writing '$tokenPath'. Nothing was changed for this token."
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $message -Tag 'secret-rotation'
          $PSCmdlet.ThrowTerminatingError(
            [System.Management.Automation.ErrorRecord]::new(
              [System.InvalidOperationException]::new($message),
              'EmptyTokenValuePasted',
              [System.Management.Automation.ErrorCategory]::InvalidData,
              $target.TokenLabel))
        }

        if (-not $SkipTokenFormatValidation) {
          if (-not (Test-BWSAccessTokenFormat -SecureValue $pastedToken)) {
            $message = "The value pasted for '$($target.TokenLabel)' does not have the expected bws access-token shape '0.<uuid>.<secret>'. This usually means a stale clipboard, a truncated selection, or a secret name pasted instead of a secret value. Nothing was written to '$tokenPath'. Re-run and paste the token, or pass -SkipTokenFormatValidation if Bitwarden's token format has changed."
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $message -Tag 'secret-rotation'
            $PSCmdlet.ThrowTerminatingError(
              [System.Management.Automation.ErrorRecord]::new(
                [System.InvalidOperationException]::new($message),
                'PastedTokenFailedFormatValidation',
                [System.Management.Automation.ErrorCategory]::InvalidData,
                $target.TokenLabel))
          }
        }

        # Non-revealing paste confirmation (D4.3). The operator compares this against the value
        # shown in the Bitwarden UI before the write proceeds. Length and a 12-hex-character digest
        # prefix distinguish the two tokens from one another and catch a truncated paste; neither
        # discloses the value.
        $fingerprint = Get-SecureStringFingerprint -SecureValue $pastedToken -PrefixLength $FingerprintLength
        $result.TokenLength = $fingerprint.Length
        $result.Fingerprint = $fingerprint.Fingerprint
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Pasted value for '$($target.TokenLabel)': length $($fingerprint.Length), sha256:$($fingerprint.Fingerprint)..." -Tag 'secret-rotation'

        $writeResult = Initialize-BWSAccessToken -AccessToken $pastedToken -TokenPurpose $target.TokenPurpose -CredentialDirectory $CredentialDirectory -Confirm:$false
        if (-not $writeResult -or -not $writeResult.Success) {
          $message = "Initialize-BWSAccessToken did not write the $($target.TokenPurpose) token file for '$($target.TokenLabel)'. Reported: $($writeResult.Message)"
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $message -Tag 'secret-rotation'
          $PSCmdlet.ThrowTerminatingError(
            [System.Management.Automation.ErrorRecord]::new(
              [System.InvalidOperationException]::new($message),
              'TokenFileWriteFailed',
              [System.Management.Automation.ErrorCategory]::WriteError,
              $tokenPath))
        }
        $result.TokenPath = $writeResult.Path

        # Read the file back and prove the value that landed in this slot is the value typed for
        # this slot. This is what catches a swapped paste, a cross-slot write, and a DPAPI failure
        # that reported success. A swapped token authenticates on first touch, so it must be caught
        # here rather than surfacing later as a confusing permissions error.
        $readBack = Get-BWSAccessToken -TokenPurpose $target.TokenPurpose -CredentialDirectory $CredentialDirectory
        $readBackFingerprint = Get-SecureStringFingerprint -SecureValue $readBack.Password -PrefixLength $FingerprintLength
        if ($readBackFingerprint.Fingerprint -ne $fingerprint.Fingerprint) {
          $message = "Read-back verification FAILED for '$($target.TokenLabel)'. Wrote a value with fingerprint sha256:$($fingerprint.Fingerprint), but '$($result.TokenPath)' now holds sha256:$($readBackFingerprint.Fingerprint). The slot may hold the wrong token. Restore the .bak file next to it before any further rotation."
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $message -Tag 'secret-rotation'
          $PSCmdlet.ThrowTerminatingError(
            [System.Management.Automation.ErrorRecord]::new(
              [System.InvalidOperationException]::new($message),
              'TokenReadBackVerificationFailed',
              [System.Management.Automation.ErrorCategory]::InvalidResult,
              $result.TokenPath))
        }

        $result.Action = 'Rotated'
        $result.Verified = $true
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Rotated '$($target.TokenLabel)' ($($target.TokenPurpose)) for $currentSamName on $env:COMPUTERNAME; verified sha256:$($fingerprint.Fingerprint)..." -Tag 'secret-rotation'
        $result
      }
      finally {
        # Drop the plaintext from memory as soon as this entry is done, whether it succeeded,
        # was rejected as a mis-paste, or failed the read-back check.
        if ($pastedToken -is [System.Security.SecureString]) { $pastedToken.Dispose() }
        $pastedToken = $null
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Finished rotation-set entry '$($target.TokenLabel)'" -Tag 'secret-rotation'
      }
    }
  }

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed' -Tag 'secret-rotation'
  }
}
