<#
.SYNOPSIS
Reports whether the current session can service an interactive Read-Host prompt.

.DESCRIPTION
Test-RotationSessionIsInteractive is the guard that keeps Invoke-RotateSecretsATAP's live path
out of agent shells, scheduled tasks, CI runners, and any -NonInteractive session. A session
qualifies as interactive only when the process was started with a user-interactive station AND
standard input is attached to a console rather than a redirected pipe or file.

The second condition is the one that matters in practice: an AI agent shell and a BuildMaster
plan step both run under an interactive Windows station, but both redirect stdin, so Read-Host
would read EOF and return an empty SecureString.

Any failure to interrogate the console is treated as NOT interactive. A false negative costs the
operator a clear error message; a false positive would let a secret rotation write an empty token.

.OUTPUTS
System.Boolean

.EXAMPLE
if (-not (Test-RotationSessionIsInteractive)) { throw 'Run this from a real terminal.' }

.NOTES
Private helper for Invoke-RotateSecretsATAP. Design decision D4.1 / D4.2 in
Documentation/Invoke-RotateSecretsATAP.DesignDecisions.md.
AI assisted using Powershell.instructions.md as guidelines.

.LINK
https://github.com/whertzing/ATAP.Utilities
#>
function Test-RotationSessionIsInteractive {
  [CmdletBinding()]
  [OutputType([bool])]
  param()

  BEGIN {
    $fn = 'Test-RotationSessionIsInteractive'
    $mn = 'ATAP.Utilities.Security.Secrets.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started' -Tag 'secret-rotation'
  }

  PROCESS {
    try {
      if (-not [System.Environment]::UserInteractive) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Session is not user-interactive' -Tag 'secret-rotation'
        return $false
      }
      if ([System.Console]::IsInputRedirected) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Standard input is redirected; Read-Host would read EOF' -Tag 'secret-rotation'
        return $false
      }
      return $true
    }
    catch {
      # No console attached at all. Fail closed.
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Console state could not be determined; treating session as non-interactive. Exception: $($_.Exception.Message)" -Tag 'secret-rotation'
      return $false
    }
    finally {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving Function $fn in module $mn" -Tag 'secret-rotation'
    }
  }

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed' -Tag 'secret-rotation'
  }
}
