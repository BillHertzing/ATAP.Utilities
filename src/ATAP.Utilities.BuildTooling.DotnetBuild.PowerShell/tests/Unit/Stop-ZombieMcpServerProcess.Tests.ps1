#Requires -Module Pester

BeforeAll {
  $script:CreatedNetTcpConnectionShim = $false
  if (-not (Get-Command -Name Get-NetTCPConnection -ErrorAction SilentlyContinue)) {
    function global:Get-NetTCPConnection {
      [CmdletBinding()]
      param([string] $State, [int] $LocalPort)
      @()
    }
    $script:CreatedNetTcpConnectionShim = $true
  }
  $script:ModuleRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
  $script:ModuleName = 'ATAP.Utilities.BuildTooling.DotnetBuild.PowerShell'
  $script:ManifestPath = Join-Path $script:ModuleRoot "$script:ModuleName.psd1"
  Remove-Module $script:ModuleName -Force -ErrorAction SilentlyContinue
  Import-Module $script:ManifestPath -Force -ErrorAction Stop
}

Describe 'Stop-ZombieMcpServerProcess' -Tag 'Unit' {
  BeforeEach {
    $script:CatalogPath = Join-Path $TestDrive 'mcp-servers.json'
    @{
      servers = @(
        @{
          serverId = 'ai.mcp.drawio.v1'; nativeKey = 'drawio'; ownership = 'canonical';
          transport = 'stdio'; command = 'pwsh';
          args = @('C:/mcp/drawio/index.js'); expectedListeningPorts = @(3333); env = @()
        },
        @{
          serverId = 'ai.mcp.dab-ro-ataputilities-exp.v1'; nativeKey = 'dab-RO-ataputilities-exp'; ownership = 'canonical';
          transport = 'stdio'; command = 'pwsh'; args = @('-Command', 'Start-DabMcpServer');
          env = @(@{ name = 'ASPNETCORE_URLS'; value = 'http://127.0.0.1:5102' })
          cleanupProcess = @{ executable = 'C:/mcp/dab.exe'; argumentFingerprints = @() }
        },
        @{
          serverId = 'ai.mcp.plantuml.v1'; nativeKey = 'plantuml'; ownership = 'canonical';
          transport = 'stdio'; command = 'C:/Windows/System32/WindowsPowerShell/v1.0/powershell.exe'; args = @('-Command', "& 'pwsh' 'C:/mcp/plantuml/server.js'"); env = @()
          cleanupProcess = @{ executable = (Join-Path $PSHOME 'pwsh.exe'); argumentFingerprints = @('C:/mcp/plantuml/server.js') }
        },
        @{
          serverId = 'ai.mcp.wrapper-no-metadata.v1'; nativeKey = 'wrapper-no-metadata'; ownership = 'canonical';
          transport = 'stdio'; command = 'pwsh'; args = @('-Command', "& 'node' 'C:/mcp/untrusted/server.js'"); env = @()
        },
        @{
          serverId = 'ai.mcp.specific.v1'; nativeKey = 'specific'; ownership = 'canonical';
          transport = 'stdio'; command = 'C:/mcp/specific.exe'; args = @(); env = @()
        },
        @{
          serverId = 'ai.mcp.deferred.v1'; nativeKey = 'deferred'; ownership = 'deferred';
          transport = 'stdio'; command = 'C:/mcp/deferred.exe'; args = @(); env = @()
        }
      )
    } | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $script:CatalogPath -Encoding utf8NoBOM
  }

  It 'stops the exact process owning a declared port' {
    InModuleScope $script:ModuleName -Parameters @{ CatalogPath = $script:CatalogPath } {
      Mock Get-CimInstance { @([pscustomobject]@{ ProcessId = 4100; ExecutablePath = 'C:/other.exe'; CommandLine = 'other'; CreationDate = $null }) }
      Mock Get-NetTCPConnection { @([pscustomobject]@{ LocalPort = 3333; OwningProcess = 4100 }) }
      Mock Stop-Process {}

      $result = Stop-ZombieMcpServerProcess -CatalogPath $CatalogPath -NativeKey drawio -Confirm:$false -PassThru

      $result.Ports | Should -Be @(3333)
      $result.CandidateProcessIds | Should -Be @(4100)
      $result.StoppedProcessIds | Should -Be @(4100)
      Should -Invoke Stop-Process -Times 1 -Exactly -ParameterFilter { $Id -eq 4100 -and $Force }
    }
  }

  It 'derives a DAB port from ASPNETCORE_URLS' {
    InModuleScope $script:ModuleName -Parameters @{ CatalogPath = $script:CatalogPath } {
      Mock Get-CimInstance { @() }
      Mock Get-NetTCPConnection { @() }

      $result = Stop-ZombieMcpServerProcess -CatalogPath $CatalogPath -NativeKey 'dab-RO-ataputilities-exp' -PassThru
      $result.Ports | Should -Be @(5102)
      $result.CandidateProcessIds | Should -BeNullOrEmpty
    }
  }

  It 'uses an exact DAB port without broad-matching every dab.exe process' {
    InModuleScope $script:ModuleName -Parameters @{ CatalogPath = $script:CatalogPath } {
      Mock Get-CimInstance {
        @(
          [pscustomobject]@{ ProcessId = 4150; ExecutablePath = 'C:/mcp/dab.exe'; CommandLine = 'dab start'; CreationDate = $null },
          [pscustomobject]@{ ProcessId = 4151; ExecutablePath = 'C:/mcp/dab.exe'; CommandLine = 'dab start'; CreationDate = $null }
        )
      }
      Mock Get-NetTCPConnection { @([pscustomobject]@{ LocalPort = 5102; OwningProcess = 4150 }) }
      Mock Stop-Process {}

      $result = Stop-ZombieMcpServerProcess -CatalogPath $CatalogPath -NativeKey 'dab-RO-ataputilities-exp' -Confirm:$false -PassThru

      $result.CandidateProcessIds | Should -Be @(4150)
      Should -Invoke Stop-Process -Times 1 -Exactly -ParameterFilter { $Id -eq 4150 -and $Force }
      Should -Invoke Stop-Process -Times 0 -Exactly -ParameterFilter { $Id -eq 4151 }
    }
  }

  It 'requires a server fingerprint before matching a generic runtime binary' {
    InModuleScope $script:ModuleName -Parameters @{ CatalogPath = $script:CatalogPath } {
      $pwshPath = (Get-Command pwsh -ErrorAction Stop).Source
      Mock Get-CimInstance {
        @(
          [pscustomobject]@{ ProcessId = 4200; ExecutablePath = $pwshPath; CommandLine = 'pwsh C:/mcp/drawio/index.js'; CreationDate = $null },
          [pscustomobject]@{ ProcessId = 4201; ExecutablePath = $pwshPath; CommandLine = 'pwsh C:/unrelated/index.js'; CreationDate = $null }
        )
      }
      Mock Get-NetTCPConnection { @() }
      Mock Stop-Process {}

      $result = Stop-ZombieMcpServerProcess -CatalogPath $CatalogPath -NativeKey drawio -Confirm:$false -PassThru
      $result.CandidateProcessIds | Should -Be @(4200)
      Should -Invoke Stop-Process -Times 1 -Exactly -ParameterFilter { $Id -eq 4200 }
      Should -Invoke Stop-Process -Times 0 -Exactly -ParameterFilter { $Id -eq 4201 }
    }
  }


  It 'matches only the explicitly declared child of a portless PowerShell wrapper' {
    InModuleScope $script:ModuleName -Parameters @{ CatalogPath = $script:CatalogPath } {
      $pwshPath = (Get-Command pwsh -ErrorAction Stop).Source
      $wrapperPath = 'C:/Windows/System32/WindowsPowerShell/v1.0/powershell.exe'
      Mock Get-CimInstance {
        @(
          [pscustomobject]@{ ProcessId = 4250; ExecutablePath = $pwshPath.ToUpperInvariant(); CommandLine = 'pwsh.exe C:\MCP\PLANTUML\SERVER.JS'; CreationDate = $null },
          [pscustomobject]@{ ProcessId = 4251; ExecutablePath = $pwshPath; CommandLine = 'pwsh.exe C:/mcp/plantuml/server.js.backup'; CreationDate = $null },
          [pscustomobject]@{ ProcessId = 4252; ExecutablePath = $wrapperPath; CommandLine = "powershell.exe -Command & 'pwsh' 'C:/mcp/plantuml/server.js'"; CreationDate = $null },
          [pscustomobject]@{ ProcessId = 4253; ExecutablePath = $pwshPath; CommandLine = 'pwsh.exe C:/mcp/unrelated/server.js'; CreationDate = $null }
        )
      }
      Mock Get-NetTCPConnection { @() }
      Mock Stop-Process {}

      $result = Stop-ZombieMcpServerProcess -CatalogPath $CatalogPath -NativeKey plantuml -Confirm:$false -PassThru

      $result.ResolvedCommand | Should -Be $pwshPath
      $result.CandidateProcessIds | Should -Be @(4250)
      Should -Invoke Stop-Process -Times 1 -Exactly -ParameterFilter { $Id -eq 4250 }
      Should -Invoke Stop-Process -Times 0 -Exactly -ParameterFilter { $Id -in @(4251, 4252, 4253) }
    }
  }

  It 'does not parse arbitrary PowerShell wrapper command text when cleanup metadata is missing' {
    InModuleScope $script:ModuleName -Parameters @{ CatalogPath = $script:CatalogPath } {
      $pwshPath = (Get-Command pwsh -ErrorAction Stop).Source
      Mock Get-CimInstance {
        @([pscustomobject]@{
            ProcessId = 4260; ExecutablePath = $pwshPath
            CommandLine = "pwsh -Command & 'node' 'C:/mcp/untrusted/server.js'"
            CreationDate = $null
          })
      }
      Mock Get-NetTCPConnection { @() }
      Mock Stop-Process {}

      $result = Stop-ZombieMcpServerProcess -CatalogPath $CatalogPath -NativeKey wrapper-no-metadata -Confirm:$false -PassThru

      $result.CandidateProcessIds | Should -BeNullOrEmpty
      Should -Invoke Stop-Process -Times 0
    }
  }

  It 'de-duplicates port and binary matches while excluding the current process' {
    InModuleScope $script:ModuleName -Parameters @{ CatalogPath = $script:CatalogPath } {
      $pwshPath = (Get-Command pwsh -ErrorAction Stop).Source
      Mock Get-CimInstance {
        @(
          [pscustomobject]@{ ProcessId = 4270; ExecutablePath = $pwshPath; CommandLine = 'pwsh C:/mcp/drawio/index.js'; CreationDate = $null },
          [pscustomobject]@{ ProcessId = $PID; ExecutablePath = $pwshPath; CommandLine = 'pwsh C:/mcp/drawio/index.js'; CreationDate = $null }
        )
      }
      Mock Get-NetTCPConnection {
        @(
          [pscustomobject]@{ LocalPort = 3333; OwningProcess = 4270 },
          [pscustomobject]@{ LocalPort = 3333; OwningProcess = $PID }
        )
      }
      Mock Stop-Process {}

      $result = Stop-ZombieMcpServerProcess -CatalogPath $CatalogPath -NativeKey drawio -Confirm:$false -PassThru

      $result.CandidateProcessIds | Should -Be @(4270)
      Should -Invoke Stop-Process -Times 1 -Exactly -ParameterFilter { $Id -eq 4270 }
      Should -Invoke Stop-Process -Times 0 -Exactly -ParameterFilter { $Id -eq $PID }
    }
  }

  It 'filters candidates younger than MinimumAge' {
    InModuleScope $script:ModuleName -Parameters @{ CatalogPath = $script:CatalogPath } {
      $pwshPath = (Get-Command pwsh -ErrorAction Stop).Source
      Mock Get-CimInstance {
        @(
          [pscustomobject]@{ ProcessId = 4280; ExecutablePath = $pwshPath; CommandLine = 'pwsh C:/mcp/drawio/index.js'; CreationDate = [datetime]::UtcNow.AddHours(-2) },
          [pscustomobject]@{ ProcessId = 4281; ExecutablePath = $pwshPath; CommandLine = 'pwsh C:/mcp/drawio/index.js'; CreationDate = [datetime]::UtcNow.AddMinutes(-1) }
        )
      }
      Mock Get-NetTCPConnection { @() }
      Mock Stop-Process {}

      $result = Stop-ZombieMcpServerProcess -CatalogPath $CatalogPath -NativeKey drawio -MinimumAge ([timespan]::FromHours(1)) -Confirm:$false -PassThru

      $result.CandidateProcessIds | Should -Be @(4280)
      Should -Invoke Stop-Process -Times 1 -Exactly -ParameterFilter { $Id -eq 4280 }
      Should -Invoke Stop-Process -Times 0 -Exactly -ParameterFilter { $Id -eq 4281 }
    }
  }

  It 'propagates a process-stop failure' {
    InModuleScope $script:ModuleName -Parameters @{ CatalogPath = $script:CatalogPath } {
      Mock Get-CimInstance { @([pscustomobject]@{ ProcessId = 4290; ExecutablePath = 'C:/other.exe'; CommandLine = 'other'; CreationDate = $null }) }
      Mock Get-NetTCPConnection { @([pscustomobject]@{ LocalPort = 3333; OwningProcess = 4290 }) }
      Mock Stop-Process { throw 'simulated stop failure' }

      { Stop-ZombieMcpServerProcess -CatalogPath $CatalogPath -NativeKey drawio -Confirm:$false } |
        Should -Throw '*simulated stop failure*'
      Should -Invoke Stop-Process -Times 1 -Exactly -ParameterFilter { $Id -eq 4290 -and $Force }
    }
  }
  It 'matches a dedicated executable by exact resolved path' {
    InModuleScope $script:ModuleName -Parameters @{ CatalogPath = $script:CatalogPath } {
      Mock Get-CimInstance { @([pscustomobject]@{ ProcessId = 4300; ExecutablePath = 'C:/mcp/specific.exe'; CommandLine = 'specific.exe'; CreationDate = $null }) }
      Mock Get-NetTCPConnection { @() }
      Mock Stop-Process {}

      $result = Stop-ZombieMcpServerProcess -CatalogPath $CatalogPath -NativeKey specific -Confirm:$false -PassThru
      $result.CandidateProcessIds | Should -Be @(4300)
      $result.StoppedProcessIds | Should -Be @(4300)
    }
  }

  It 'honors WhatIf without stopping the candidate' {
    InModuleScope $script:ModuleName -Parameters @{ CatalogPath = $script:CatalogPath } {
      Mock Get-CimInstance { @([pscustomobject]@{ ProcessId = 4400; ExecutablePath = 'C:/other.exe'; CommandLine = 'other'; CreationDate = $null }) }
      Mock Get-NetTCPConnection { @([pscustomobject]@{ LocalPort = 3333; OwningProcess = 4400 }) }
      Mock Stop-Process {}

      $result = Stop-ZombieMcpServerProcess -CatalogPath $CatalogPath -NativeKey drawio -WhatIf -PassThru
      $result.StoppedProcessIds | Should -BeNullOrEmpty
      $result.WhatIfProcessIds | Should -Be @(4400)
      Should -Invoke Stop-Process -Times 0
    }
  }

  It 'is a no-op when no stale process matches' {
    InModuleScope $script:ModuleName -Parameters @{ CatalogPath = $script:CatalogPath } {
      Mock Get-CimInstance { @() }
      Mock Get-NetTCPConnection { @() }
      Mock Stop-Process {}

      $result = Stop-ZombieMcpServerProcess -CatalogPath $CatalogPath -NativeKey drawio -Confirm:$false -PassThru
      $result.CandidateProcessIds | Should -BeNullOrEmpty
      $result.StoppedProcessIds | Should -BeNullOrEmpty
      Should -Invoke Stop-Process -Times 0
    }
  }

  It 'rejects a key that is absent or deferred' {
    InModuleScope $script:ModuleName -Parameters @{ CatalogPath = $script:CatalogPath } {
      Mock Get-CimInstance { @() }
      { Stop-ZombieMcpServerProcess -CatalogPath $CatalogPath -NativeKey deferred -Confirm:$false } |
        Should -Throw '*not found*'
    }
  }
}

AfterAll {
  if ($script:CreatedNetTcpConnectionShim) {
    Remove-Item -LiteralPath Function:\Get-NetTCPConnection -ErrorAction SilentlyContinue
  }
}
