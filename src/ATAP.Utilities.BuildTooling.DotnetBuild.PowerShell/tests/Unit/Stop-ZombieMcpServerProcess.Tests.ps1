#Requires -Module Pester

BeforeAll {
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
          transport = 'stdio'; command = 'node';
          args = @('C:/mcp/drawio/index.js'); expectedListeningPorts = @(3333); env = @()
        },
        @{
          serverId = 'ai.mcp.dab-ro-ataputilities-exp.v1'; nativeKey = 'dab-RO-ataputilities-exp'; ownership = 'canonical';
          transport = 'stdio'; command = 'pwsh'; args = @('-Command', 'Start-DabMcpServer');
          env = @(@{ name = 'ASPNETCORE_URLS'; value = 'http://127.0.0.1:5102' })
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

  It 'requires a server fingerprint before matching a generic runtime binary' {
    InModuleScope $script:ModuleName -Parameters @{ CatalogPath = $script:CatalogPath } {
      $nodePath = (Get-Command node -ErrorAction Stop).Source
      Mock Get-CimInstance {
        @(
          [pscustomobject]@{ ProcessId = 4200; ExecutablePath = $nodePath; CommandLine = 'node C:/mcp/drawio/index.js'; CreationDate = $null },
          [pscustomobject]@{ ProcessId = 4201; ExecutablePath = $nodePath; CommandLine = 'node C:/unrelated/index.js'; CreationDate = $null }
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
