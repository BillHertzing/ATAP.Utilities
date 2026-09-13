#Requires -Module Pester

BeforeAll {
  $typeFile = Join-Path $PSScriptRoot '..\..\lib\AceOutpostDesktopProxyBridge.types.ps1'
  . $typeFile

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
}

Describe 'AceOutpostDesktopProxyBridge' -Tag 'Unit' {
  It 'injects one Basic authorization header for an allowed process' {
    $upstream = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
    $bridge = $client = $accepted = $null
    try {
      $upstream.Start()
      $upstreamPort = ([System.Net.IPEndPoint]$upstream.LocalEndpoint).Port
      $acceptTask = $upstream.AcceptTcpClientAsync()

      $bridge = [ATAP.Utilities.PowerShell.AceOutpostDesktopProxyBridge]::new($upstreamPort, 'test-user:test-secret')
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
      $otherRoot = Start-Process -FilePath (Get-Command pwsh).Source -ArgumentList @('-Command', 'Start-Sleep -Seconds 30') -PassThru

      $bridge = [ATAP.Utilities.PowerShell.AceOutpostDesktopProxyBridge]::new($upstreamPort, 'test-user:test-secret')
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
      $bridge = [ATAP.Utilities.PowerShell.AceOutpostDesktopProxyBridge]::new($upstreamPort, 'test-user:test-secret')
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
    { [ATAP.Utilities.PowerShell.AceOutpostDesktopProxyBridge]::new(50055, "user:secret`r`nInjected: value") } |
      Should -Throw '*credential is invalid*'
  }

  It 'allows the root process identity to be assigned only once' {
    $bridge = [ATAP.Utilities.PowerShell.AceOutpostDesktopProxyBridge]::new(50055, 'test-user:test-secret')
    try {
      $bridge.Start()
      $bridge.SetAllowedRootProcess($PID)
      { $bridge.SetAllowedRootProcess($PID) } | Should -Throw '*already set*'
    } finally {
      $bridge.Dispose()
    }
  }
}
