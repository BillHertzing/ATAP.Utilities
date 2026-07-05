# tests/Unit/Enable-SeqGelfLogging.Tests.ps1
#
# Task 12.19 (SC-0230): PSFramework GELF logging to the SEQ (UDP) ingestor.
# The built-in PSFramework 'gelf' provider is TCP-only (Send-PSGelfTCP), so this
# module ships a 'gelfudp' provider enabled via Enable-SeqGelfLogging.
#
# The end-to-end test binds a REAL loopback UDP listener on an ephemeral port,
# enables the provider against it, emits a Write-PSFMessage, and asserts the
# received datagram decodes (GZip) to GELF JSON carrying the message. This proves
# the whole chain PSFramework -> gelfudp provider -> PSGELF UDP -> wire, which is
# the same chain the production sqelf ingestor consumes on udp://127.0.0.1:12201.

#Requires -Module Pester

BeforeAll {
  $script:moduleRoot = Join-Path $PSScriptRoot '..\..' | Resolve-Path
  $script:sut = Join-Path $script:moduleRoot 'public\Enable-SeqGelfLogging.ps1' | Resolve-Path
  . $script:sut
}

Describe 'Enable-SeqGelfLogging' {

  Context 'Function shape and manifest' {
    It 'is exported by the module manifest' {
      $manifest = Import-PowerShellDataFile (Join-Path $script:moduleRoot 'ATAP.Utilities.Powershell.psd1')
      $manifest.FunctionsToExport | Should -Contain 'Enable-SeqGelfLogging'
    }

    It 'defaults to the SendToSEQ instance and udp 127.0.0.1:12201' {
      $cmd = Get-Command Enable-SeqGelfLogging
      $cmd.Parameters['InstanceName'].Attributes | Should -Not -BeNullOrEmpty
      $ast = $cmd.ScriptBlock.Ast
      $ast.Body.ParamBlock.Parameters.Where({ $_.Name.VariablePath.UserPath -eq 'InstanceName' }).DefaultValue.Value |
        Should -Be 'SendToSEQ'
      $ast.Body.ParamBlock.Parameters.Where({ $_.Name.VariablePath.UserPath -eq 'Port' }).DefaultValue.Value |
        Should -Be 12201
      $ast.Body.ParamBlock.Parameters.Where({ $_.Name.VariablePath.UserPath -eq 'GelfServer' }).DefaultValue.Value |
        Should -Be '127.0.0.1'
    }

    It 'references the SEQ API key by SecretName only (no literal key parameter)' {
      $cmd = Get-Command Enable-SeqGelfLogging
      $cmd.Parameters.Keys | Should -Contain 'SeqApiKeySecretName'
      $cmd.Parameters.Keys | Should -Not -Contain 'SeqApiKey'
      $ast = $cmd.ScriptBlock.Ast
      $ast.Body.ParamBlock.Parameters.Where({ $_.Name.VariablePath.UserPath -eq 'SeqApiKeySecretName' }).DefaultValue.Value |
        Should -Be 'SEQ.Admin.API.Key'
    }
  }

  Context 'End-to-end UDP GELF delivery (loopback listener)' {
    AfterAll {
      # Disable the test instance so later sessions/tests do not keep sending to a dead port
      Set-PSFLoggingProvider -Name 'gelfudp' -InstanceName 'SendToPesterListener' -Enabled $false -ErrorAction SilentlyContinue
      $null = Wait-PSFMessage -Timeout 2
    }

    It 'registers the provider and delivers the marker message as a GELF datagram over UDP' {
      # Regression context: the first enable of a gelfudp instance used to deliver
      # nothing (provider StartEvent cached instance config before it was visible);
      # the message event now resolves config per message, so a fresh-session first
      # enable must deliver. This test guards exactly that.
      $udpClient = [System.Net.Sockets.UdpClient]::new(0)
      $listenPort = ([System.Net.IPEndPoint]$udpClient.Client.LocalEndPoint).Port
      try {
        $result = Enable-SeqGelfLogging -GelfServer '127.0.0.1' -Port $listenPort -InstanceName 'SendToPesterListener' -Confirm:$false

        $result | Should -Not -BeNullOrEmpty
        $result.ProviderName | Should -Be 'gelfudp'
        $result.Enabled | Should -BeTrue

        # Receive until the marker datagram arrives (skip unrelated packets
        # defensively). Re-emit the marker between receive attempts: messages logged
        # before the async instance start are not replayed, so a re-emitted marker
        # guarantees delivery once the instance is live.
        $payload = $null
        $endpoint = [System.Net.IPEndPoint]::new([System.Net.IPAddress]::Any, 0)
        $udpClient.Client.ReceiveTimeout = 3000
        $deadline = (Get-Date).AddSeconds(20)
        while ((Get-Date) -lt $deadline) {
          try {
            $bytes = $udpClient.Receive([ref]$endpoint)
          } catch {
            Write-PSFMessage -Level Important -Message $result.TestMarker
            $null = Wait-PSFMessage -Timeout 2
            continue
          }
          # PSGELF sends small UDP GELF datagrams as plain JSON; handle GZip (magic 1f 8b) defensively
          if ($bytes.Length -gt 2 -and $bytes[0] -eq 0x1f -and $bytes[1] -eq 0x8b) {
            $inStream = [System.IO.MemoryStream]::new($bytes)
            $gzip = [System.IO.Compression.GZipStream]::new($inStream, [System.IO.Compression.CompressionMode]::Decompress)
            $reader = [System.IO.StreamReader]::new($gzip, [System.Text.Encoding]::UTF8)
            $json = $reader.ReadToEnd()
            $reader.Dispose(); $gzip.Dispose(); $inStream.Dispose()
          } else {
            $json = [System.Text.Encoding]::UTF8.GetString($bytes)
          }
          $decoded = $null
          try { $decoded = $json | ConvertFrom-Json } catch { continue }
          if ($decoded.short_message -like "*$($result.TestMarker)*") {
            $payload = $decoded
            break
          }
        }

        $payload | Should -Not -BeNullOrEmpty -Because 'the loopback listener must receive the GELF datagram carrying the test marker'
        $payload.version | Should -Be '1.1'
        $payload.host | Should -Not -BeNullOrEmpty
      } finally {
        $udpClient.Dispose()
      }
    }
  }
}
