function Set-AceOutpostProxyEnvironment {
  <#
  .SYNOPSIS
    Enables or disables AceOutpost proxying for one supported AI client and environment scope.
  .DESCRIPTION
    Configures the documented localhost AceOutpost forward-proxy contract for Claude Code or
    Codex. Enabling sets HTTP_PROXY, HTTPS_PROXY, NO_PROXY, and the client's interception-root
    trust variable. The proxy credential is resolved at run time from the approved secret store
    and is never returned or logged.

    The default Process scope is intentionally ephemeral: launch the client from that process.
    User and Machine scopes persist the Basic credential in the Windows environment store, so
    they require -AllowPersistentCredential. Machine scope normally requires an elevated shell.
    Disabling removes only the proxy and trust variables owned by this function; it never changes
    a certificate store.

    The currently ratified AceOutpost configuration admits only claude-code and codex. A future
    Antigravity client must first receive its own configured AceOutpost client credential and a
    verified trust-variable contract; this function fails closed rather than guessing either.
  .PARAMETER State
    Enabled writes the proxy settings. Disabled removes them.
  .PARAMETER Client
    The AceOutpost client identity: ClaudeCode or Codex.
  .PARAMETER Scope
    The Windows environment scope to modify. Process is the safe default.
  .PARAMETER ProxyPort
    AceOutpost's loopback proxy listener port. The documented default is 50055.
  .PARAMETER StateDirectory
    Directory in which AceOutpostService publishes its public interception root.
  .PARAMETER AllowPersistentCredential
    Required when enabling User or Machine scope because those scopes persist the proxy's Basic
    credential outside this PowerShell process.
  .OUTPUTS
    PSCustomObject with redacted operation metadata.
  .EXAMPLE
    Set-AceOutpostProxyEnvironment -State Enabled -Client Codex

    Enables metering for Codex processes launched from the current PowerShell session.
  .EXAMPLE
    Set-AceOutpostProxyEnvironment -State Disabled -Client ClaudeCode -Scope User

    Removes the persisted Claude Code proxy and trust settings from the current user's profile.
  .NOTES
    Values verified against AceOutpostService-ProxyEnablement.md and the September 5, 2026
    Claude Code and Codex proxy acceptance probes. Claude Code uses NODE_EXTRA_CA_CERTS; Codex
    uses SSL_CERT_FILE. Both use HTTP_PROXY, HTTPS_PROXY, and NO_PROXY.
  .LINK
    AceOutpost.Windows/Documentation/AceOutpostService-ProxyEnablement.md
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)]
    [ValidateSet('Enabled', 'Disabled')]
    [string]$State,

    [Parameter(Mandatory)]
    [ValidateSet('ClaudeCode', 'Codex')]
    [string]$Client,

    [ValidateSet('Process', 'User', 'Machine')]
    [string]$Scope = 'Process',

    [ValidateRange(50000, 50099)]
    [int]$ProxyPort = 50055,

    [ValidateNotNullOrEmpty()]
    [string]$StateDirectory = 'C:\ProgramData\ATAP\AceOutpostService\state',

    [switch]$AllowPersistentCredential
  )

  begin {
    $fn = 'Set-AceOutpostProxyEnvironment'
    $mn = 'ATAP.Utilities.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

    $clientSettings = @{
      ClaudeCode = @{ ClientId = 'claude-code'; TrustVariable = 'NODE_EXTRA_CA_CERTS' }
      Codex      = @{ ClientId = 'codex'; TrustVariable = 'SSL_CERT_FILE' }
    }
    $clientSetting = $clientSettings[$Client]
    $target = [System.EnvironmentVariableTarget]::$Scope
    $rootPem = Join-Path -Path $StateDirectory -ChildPath 'AceOutpost-Interception-Root.pem'
    $variableNames = @('HTTP_PROXY', 'HTTPS_PROXY', 'ALL_PROXY', 'NO_PROXY', $clientSetting.TrustVariable)

    if ($State -eq 'Enabled' -and $Scope -ne 'Process' -and -not $AllowPersistentCredential) {
      throw "Enabling $Scope scope persists the AceOutpost Basic credential. Re-run with -AllowPersistentCredential after confirming that persistence is intended."
    }
  }

  process {
    $changed = [System.Collections.Generic.List[string]]::new()
    $status = if ($State -eq 'Enabled') { 'Enabled' } else { 'Disabled' }

    try {
      if ($State -eq 'Enabled') {
        if (-not (Test-Path -LiteralPath $rootPem -PathType Leaf)) {
          throw "AceOutpost interception root was not found at '$rootPem'. Start AceOutpostService and confirm its proxy bootstrap completed before enabling a client."
        }
        if (-not (Get-Command -Name Get-SecretATAP -ErrorAction SilentlyContinue)) {
          throw 'Get-SecretATAP is required to resolve the AceOutpost proxy credential but is unavailable.'
        }

        $credential = Get-SecretATAP -SecretName "proxyCredential.Ace.AceOutpost.$($clientSetting.ClientId)"
        if ($credential -is [securestring]) {
          $credential = [System.Net.NetworkCredential]::new('', $credential).Password
        }
        $separator = ([string]$credential).IndexOf(':')
        if ($separator -le 0 -or $separator -eq ([string]$credential).Length - 1) {
          throw "The proxy credential for '$($clientSetting.ClientId)' is not a valid username:secret pair."
        }

        $username = [Uri]::EscapeDataString(([string]$credential).Substring(0, $separator))
        $secret = [Uri]::EscapeDataString(([string]$credential).Substring($separator + 1))
        $proxyUrl = "http://${username}:${secret}@127.0.0.1:$ProxyPort"
        $values = @{
          HTTP_PROXY = $proxyUrl
          HTTPS_PROXY = $proxyUrl
          NO_PROXY = 'localhost,127.0.0.1,::1'
          $clientSetting.TrustVariable = $rootPem
        }

        foreach ($name in $values.Keys) {
          if ($PSCmdlet.ShouldProcess("$Scope environment variable '$name'", 'Set AceOutpost proxy configuration')) {
            [System.Environment]::SetEnvironmentVariable($name, $values[$name], $target)
            $changed.Add($name)
          }
        }
        $credential = $username = $secret = $proxyUrl = $null
      } else {
        foreach ($name in $variableNames) {
          if ($PSCmdlet.ShouldProcess("$Scope environment variable '$name'", 'Remove AceOutpost proxy configuration')) {
            [System.Environment]::SetEnvironmentVariable($name, $null, $target)
            $changed.Add($name)
          }
        }
      }
    } catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "AceOutpost proxy environment configuration failed: $($_.Exception.Message)"
      throw
    } finally {
      $credential = $username = $secret = $proxyUrl = $null
    }

    [PSCustomObject]@{
      State = $status
      Client = $Client
      Scope = $Scope
      ProxyEndpoint = if ($State -eq 'Enabled') { "http://127.0.0.1:$ProxyPort" } else { $null }
      TrustVariable = $clientSetting.TrustVariable
      ChangedVariables = @($changed)
      PersistentCredential = ($State -eq 'Enabled' -and $Scope -ne 'Process')
      RestartRequired = ($Scope -ne 'Process')
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "AceOutpost proxy environment '$State' for $Client in $Scope scope."
  }
}
