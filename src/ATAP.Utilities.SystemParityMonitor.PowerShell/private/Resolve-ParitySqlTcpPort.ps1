function Resolve-ParitySqlTcpPort {
  [CmdletBinding()]
  param(
    [AllowNull()]
    [AllowEmptyString()]
    [string] $TcpPort,

    [AllowNull()]
    [AllowEmptyString()]
    [string] $TcpDynamicPorts
  )

  foreach ($candidate in @($TcpPort, $TcpDynamicPorts)) {
    if ([string]::IsNullOrWhiteSpace($candidate)) {
      continue
    }

    [int] $port = 0
    if ([int]::TryParse($candidate, [ref] $port) -and $port -ge 1 -and $port -le 65535) {
      return $port
    }
  }

  throw "SQL TCP configuration has neither a valid static TcpPort nor a valid TcpDynamicPorts value."
}
