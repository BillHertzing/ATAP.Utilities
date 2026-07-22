# Internal trace shim (SC-follow-up: Decouple ConfigRootKeys from PSFramework).
#
# This file is intentionally NOT an eponymous begin/process/end cmdlet: it uses the simple
# $args passthrough form so it forwards the exact Write-PSFMessage parameter set unchanged,
# which an advanced function ([CmdletBinding]/param) cannot do ($args is empty there).
#
# Purpose: ConfigRootKeys' section functions (Set-GlobalConfigRootKeys and the Set-*/Add-*
# helpers it invokes) run during machine-profile config bootstrap. Calling Write-PSFMessage
# there would autoload PSFramework and pay its ~1.7s cold-load on every interactive shell.
# This shim forwards to Write-PSFMessage ONLY when PSFramework is already loaded, so bootstrap
# stays PSFramework-free; when it is absent the Debug/Verbose/Error lifecycle traces are
# skipped. Genuine failures still surface: every Error-level trace here is immediately
# followed by a throw, so the exception propagates regardless of logging state.
function Write-ConfigRootKeysMessage {
  if (-not (Get-Module -Name PSFramework)) { return }
  Write-PSFMessage @args
}
