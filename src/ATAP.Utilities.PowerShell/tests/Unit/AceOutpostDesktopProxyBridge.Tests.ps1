#Requires -Module Pester

BeforeAll {
  $typeFile = Join-Path $PSScriptRoot '..\..\lib\AceOutpostDesktopProxyBridge.types.ps1'
  $typeSource = Get-Content -LiteralPath $typeFile -Raw
  $sourceMatch = [regex]::Match($typeSource, "(?s)Add-Type @'\r?\n(?<Source>.*)\r?\n'@")
  if (-not $sourceMatch.Success) { throw "Could not extract the C# bridge source from '$typeFile'." }
  $isolatedSource = $sourceMatch.Groups['Source'].Value `
    -replace 'namespace ATAP\.Utilities\.PowerShell', 'namespace ATAP.Utilities.PowerShell.SourceTests' `
    -replace 'AceOutpostDesktopProxyBridge', 'AceOutpostDesktopProxyBridgeUnderTest'
  Add-Type -TypeDefinition $isolatedSource

  function New-TestDesktopProxyBridge {
    param(
      [Parameter(Mandatory)][int]$UpstreamPort,
      [Parameter(Mandatory)][string]$Credential
    )

    [ATAP.Utilities.PowerShell.SourceTests.AceOutpostDesktopProxyBridgeUnderTest]::new($UpstreamPort, $Credential)
  }

  function Read-ProxyHeader {
    param([System.IO.Stream]$Stream)

    $bytes = [System.Collections.Generic.List[byte]]::new()
    while ($bytes.Count -lt 65536) {
      $value = $Stream.ReadByte()
      if ($value -lt 0) { throw 'Stream closed before the proxy header was complete.' }
      $bytes.Add([byte]$value)
      if ($bytes.Count -ge 4 -and
          $bytes[$bytes.Count - 4] -eq 13 -and $bytes[$bytes.Count - 3] -eq 10 -and
          $bytes[$bytes.Count - 2] -eq 13 -and $bytes[$bytes.Count - 1] -eq 10) {
        return [System.Text.Encoding]::ASCII.GetString($bytes.ToArray())
      }
    }
    throw 'Proxy header exceeded the test limit.'
  }

  function Read-ExactBytes {
    param(
      [Parameter(Mandatory)][System.IO.Stream]$Stream,
      [Parameter(Mandatory)][int]$Count
    )

    $buffer = [byte[]]::new($Count)
    $offset = 0
    while ($offset -lt $Count) {
      $read = $Stream.Read($buffer, $offset, $Count - $offset)
      if ($read -eq 0) { break }
      $offset += $read
    }
    [pscustomobject]@{ Buffer = $buffer; Count = $offset }
  }
}

Describe 'AceOutpostDesktopProxyBridge' -Tag 'Unit' {
  It 'injects one Basic authorization header for an allowed process' {
    $upstream = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
    $bridge = $client = $accepted = $null
    try {
      $upstream.Start()
      $upstreamPort = ([System.Net.IPEndPoint]$upstream.LocalEndpoint).Port
      $acceptTask = $upstream.AcceptTcpClientAsync()

      $bridge = New-TestDesktopProxyBridge -UpstreamPort $upstreamPort -Credential 'test-user:test-secret'
      $bridge.Start()
      $bridge.SetAllowedRootProcess($PID)

      $client = [System.Net.Sockets.TcpClient]::new()
      $client.Connect([System.Net.IPAddress]::Loopback, $bridge.LocalPort)
      $clientStream = $client.GetStream()
      $request = [System.Text.Encoding]::ASCII.GetBytes("CONNECT example.test:443 HTTP/1.1`r`nHost: example.test:443`r`n`r`n")
      $clientStream.Write($request, 0, $request.Length)

      $acceptTask.Wait(5000) | Should -BeTrue
      $accepted = $acceptTask.GetAwaiter().GetResult()
      $accepted.GetStream().ReadTimeout = 5000
      $header = Read-ProxyHeader -Stream $accepted.GetStream()
      $header | Should -Match '^CONNECT example\.test:443 HTTP/1\.1'
      @($header -split "`r`n" | Where-Object { $_ -match '^Proxy-Authorization:' }).Count | Should -Be 1
      $header | Should -Match 'Proxy-Authorization: Basic dGVzdC11c2VyOnRlc3Qtc2VjcmV0'

      $response = [System.Text.Encoding]::ASCII.GetBytes("HTTP/1.1 200 Connection Established`r`n`r`n")
      $accepted.GetStream().Write($response, 0, $response.Length)
      $clientStream.ReadTimeout = 5000
      (Read-ProxyHeader -Stream $clientStream) | Should -Be "HTTP/1.1 200 Connection Established`r`n`r`n"
      $bridge.AcceptedConnectionCount | Should -Be 1
      $bridge.RejectedConnectionCount | Should -Be 0
    } finally {
      if ($null -ne $accepted) { $accepted.Dispose() }
      if ($null -ne $client) { $client.Dispose() }
      if ($null -ne $bridge) { $bridge.Dispose() }
      $upstream.Stop()
    }
  }

  It 'rejects a client outside the allowed process tree without contacting upstream' {
    $upstream = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
    $bridge = $client = $otherRoot = $null
    try {
      $upstream.Start()
      $upstreamPort = ([System.Net.IPEndPoint]$upstream.LocalEndpoint).Port
      $acceptTask = $upstream.AcceptTcpClientAsync()
      $otherRoot = Start-Process -FilePath (Get-Command pwsh).Source `
        -ArgumentList @('-Command', 'Start-Sleep -Seconds 30') -WindowStyle Hidden -PassThru

      $bridge = New-TestDesktopProxyBridge -UpstreamPort $upstreamPort -Credential 'test-user:test-secret'
      $bridge.Start()
      $bridge.SetAllowedRootProcess($otherRoot.Id)
      $client = [System.Net.Sockets.TcpClient]::new()
      $client.Connect([System.Net.IPAddress]::Loopback, $bridge.LocalPort)
      $request = [System.Text.Encoding]::ASCII.GetBytes("CONNECT example.test:443 HTTP/1.1`r`nHost: example.test:443`r`n`r`n")
      $client.GetStream().Write($request, 0, $request.Length)

      $acceptTask.Wait(500) | Should -BeFalse
      $deadline = [datetime]::UtcNow.AddSeconds(5)
      while ($bridge.RejectedConnectionCount -lt 1 -and [datetime]::UtcNow -lt $deadline) {
        Start-Sleep -Milliseconds 25
      }
      $bridge.RejectedConnectionCount | Should -Be 1
      $bridge.AcceptedConnectionCount | Should -Be 0
    } finally {
      if ($null -ne $client) { $client.Dispose() }
      if ($null -ne $bridge) { $bridge.Dispose() }
      if ($null -ne $otherRoot -and -not $otherRoot.HasExited) { $otherRoot.Kill($true); $otherRoot.WaitForExit() }
      $upstream.Stop()
    }
  }

  It 'rejects caller-supplied proxy authorization without contacting upstream' {
    $upstream = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
    $bridge = $client = $null
    try {
      $upstream.Start()
      $upstreamPort = ([System.Net.IPEndPoint]$upstream.LocalEndpoint).Port
      $acceptTask = $upstream.AcceptTcpClientAsync()
      $bridge = New-TestDesktopProxyBridge -UpstreamPort $upstreamPort -Credential 'test-user:test-secret'
      $bridge.Start()
      $bridge.SetAllowedRootProcess($PID)

      $client = [System.Net.Sockets.TcpClient]::new()
      $client.Connect([System.Net.IPAddress]::Loopback, $bridge.LocalPort)
      $request = [System.Text.Encoding]::ASCII.GetBytes("CONNECT example.test:443 HTTP/1.1`r`nProxy-Authorization: Basic dW50cnVzdGVkOnZhbHVl`r`n`r`n")
      $client.GetStream().Write($request, 0, $request.Length)

      $acceptTask.Wait(500) | Should -BeFalse
      $deadline = [datetime]::UtcNow.AddSeconds(5)
      while ($bridge.RejectedConnectionCount -lt 1 -and [datetime]::UtcNow -lt $deadline) {
        Start-Sleep -Milliseconds 25
      }
      $bridge.RejectedConnectionCount | Should -Be 1
      $bridge.AcceptedConnectionCount | Should -Be 0
    } finally {
      if ($null -ne $client) { $client.Dispose() }
      if ($null -ne $bridge) { $bridge.Dispose() }
      $upstream.Stop()
    }
  }

  It 'rejects credentials containing line breaks' {
    { New-TestDesktopProxyBridge -UpstreamPort 50055 -Credential "user:secret`r`nInjected: value" } |
      Should -Throw '*credential is invalid*'
  }

  It 'allows the root process identity to be assigned only once' {
    $bridge = New-TestDesktopProxyBridge -UpstreamPort 50055 -Credential 'test-user:test-secret'
    try {
      $bridge.Start()
      $bridge.SetAllowedRootProcess($PID)
      { $bridge.SetAllowedRootProcess($PID) } | Should -Throw '*already set*'
    } finally {
      $bridge.Dispose()
    }
  }

  It 'continues relaying a delayed response after the client half-closes its send direction' {
    $upstream = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
    $bridge = $client = $accepted = $null
    try {
      $upstream.Start()
      $upstreamPort = ([System.Net.IPEndPoint]$upstream.LocalEndpoint).Port
      $acceptTask = $upstream.AcceptTcpClientAsync()
      $bridge = New-TestDesktopProxyBridge -UpstreamPort $upstreamPort -Credential 'test-user:test-secret'
      $bridge.Start()
      $bridge.SetAllowedRootProcess($PID)

      $client = [System.Net.Sockets.TcpClient]::new()
      $client.Connect([System.Net.IPAddress]::Loopback, $bridge.LocalPort)
      $clientStream = $client.GetStream()
      $clientStream.ReadTimeout = 5000
      $connect = [System.Text.Encoding]::ASCII.GetBytes("CONNECT example.test:443 HTTP/1.1`r`nHost: example.test:443`r`n`r`n")
      $clientStream.Write($connect)

      $acceptTask.Wait(5000) | Should -BeTrue
      $accepted = $acceptTask.GetAwaiter().GetResult()
      $upstreamStream = $accepted.GetStream()
      $upstreamStream.ReadTimeout = 5000
      $null = Read-ProxyHeader -Stream $upstreamStream
      $established = [System.Text.Encoding]::ASCII.GetBytes("HTTP/1.1 200 Connection Established`r`n`r`n")
      $upstreamStream.Write($established)
      $null = Read-ProxyHeader -Stream $clientStream

      $request = [System.Text.Encoding]::ASCII.GetBytes('request-complete')
      $clientStream.Write($request)
      $receivedRequest = [byte[]]::new($request.Length)
      $upstreamStream.Read($receivedRequest, 0, $receivedRequest.Length) | Should -Be $request.Length
      $client.Client.Shutdown([System.Net.Sockets.SocketShutdown]::Send)
      Start-Sleep -Milliseconds 250

      $response = [System.Text.Encoding]::ASCII.GetBytes('streamed-response-after-client-half-close')
      $upstreamStream.Write($response)
      $accepted.Client.Shutdown([System.Net.Sockets.SocketShutdown]::Send)
      $receivedResponse = Read-ExactBytes -Stream $clientStream -Count $response.Length

      $receivedResponse.Count | Should -Be $response.Length
      [System.Text.Encoding]::ASCII.GetString($receivedResponse.Buffer, 0, $receivedResponse.Count) |
        Should -Be 'streamed-response-after-client-half-close'
      $bridge.AcceptedConnectionCount | Should -Be 1
      $bridge.RejectedConnectionCount | Should -Be 0
    } finally {
      if ($null -ne $accepted) { $accepted.Dispose() }
      if ($null -ne $client) { $client.Dispose() }
      if ($null -ne $bridge) { $bridge.Dispose() }
      $upstream.Stop()
    }
  }

  It 'continues relaying client bytes after the upstream half-closes its send direction' {
    $upstream = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
    $bridge = $client = $accepted = $null
    try {
      $upstream.Start()
      $upstreamPort = ([System.Net.IPEndPoint]$upstream.LocalEndpoint).Port
      $acceptTask = $upstream.AcceptTcpClientAsync()
      $bridge = New-TestDesktopProxyBridge -UpstreamPort $upstreamPort -Credential 'test-user:test-secret'
      $bridge.Start()
      $bridge.SetAllowedRootProcess($PID)

      $client = [System.Net.Sockets.TcpClient]::new()
      $client.Connect([System.Net.IPAddress]::Loopback, $bridge.LocalPort)
      $clientStream = $client.GetStream()
      $clientStream.ReadTimeout = 5000
      $connect = [System.Text.Encoding]::ASCII.GetBytes("CONNECT example.test:443 HTTP/1.1`r`nHost: example.test:443`r`n`r`n")
      $clientStream.Write($connect)

      $acceptTask.Wait(5000) | Should -BeTrue
      $accepted = $acceptTask.GetAwaiter().GetResult()
      $upstreamStream = $accepted.GetStream()
      $upstreamStream.ReadTimeout = 5000
      $null = Read-ProxyHeader -Stream $upstreamStream
      $established = [System.Text.Encoding]::ASCII.GetBytes("HTTP/1.1 200 Connection Established`r`n`r`n")
      $upstreamStream.Write($established)
      $null = Read-ProxyHeader -Stream $clientStream

      $response = [System.Text.Encoding]::ASCII.GetBytes('upstream-response-complete')
      $upstreamStream.Write($response)
      $accepted.Client.Shutdown([System.Net.Sockets.SocketShutdown]::Send)
      $receivedResponse = Read-ExactBytes -Stream $clientStream -Count $response.Length
      $receivedResponse.Count | Should -Be $response.Length

      $lateClientBytes = [System.Text.Encoding]::ASCII.GetBytes('late-client-bytes')
      $clientStream.Write($lateClientBytes)
      $client.Client.Shutdown([System.Net.Sockets.SocketShutdown]::Send)
      $receivedClientBytes = Read-ExactBytes -Stream $upstreamStream -Count $lateClientBytes.Length

      $receivedClientBytes.Count | Should -Be $lateClientBytes.Length
      [System.Text.Encoding]::ASCII.GetString($receivedClientBytes.Buffer, 0, $receivedClientBytes.Count) |
        Should -Be 'late-client-bytes'
      $bridge.AcceptedConnectionCount | Should -Be 1
      $bridge.RejectedConnectionCount | Should -Be 0
    } finally {
      if ($null -ne $accepted) { $accepted.Dispose() }
      if ($null -ne $client) { $client.Dispose() }
      if ($null -ne $bridge) { $bridge.Dispose() }
      $upstream.Stop()
    }
  }
}
