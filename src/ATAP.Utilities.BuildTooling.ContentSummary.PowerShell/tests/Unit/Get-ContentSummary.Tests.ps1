BeforeAll {
  $script:moduleRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
  $script:moduleName = 'ATAP.Utilities.BuildTooling.ContentSummary.PowerShell'
  Import-Module -Name 'ATAP.Utilities.Powershell' -MinimumVersion '0.2.1' -Force
  Import-Module -Name 'ATAP.Utilities.BuildTooling.Common.PowerShell' -MinimumVersion '0.1.10' -Force
  Import-Module -Name 'ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell' -MinimumVersion '0.1.34' -Force
  $promotedManifest = [System.Environment]::GetEnvironmentVariable('ATAP_PROMOTED_MODULE_MANIFEST', 'Process')
  $moduleToTest = if ([string]::IsNullOrWhiteSpace($promotedManifest)) {
    Join-Path $script:moduleRoot 'ATAP.Utilities.BuildTooling.ContentSummary.PowerShell.psd1'
  } else {
    $promotedManifest
  }
  Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
  Import-Module -Name $moduleToTest -Force -ErrorAction Stop
}

Describe 'Get-ContentSummary [public]' -Tag 'Unit' {
  It 'loads exactly one target module from the selected manifest' {
    $loadedModules = @(Get-Module -Name $script:moduleName)
    $loadedModules.Count | Should -Be 1

    $promotedManifest = [System.Environment]::GetEnvironmentVariable('ATAP_PROMOTED_MODULE_MANIFEST', 'Process')
    if (-not [string]::IsNullOrWhiteSpace($promotedManifest)) {
      [System.IO.Path]::GetFullPath($loadedModules[0].ModuleBase) |
        Should -BeExactly ([System.IO.Path]::GetFullPath((Split-Path -Path $promotedManifest -Parent)))
    }
  }

  BeforeEach {
    $global:settings = @{
      AceOutpost = @{
        Ingestion = @{
          Scheme = 'https'
          Host = 'localhost'
          Port = 50042
          Path = '/api/v1/gather-content'
        }
      }
    }
    Mock -CommandName Write-PSFMessage -ModuleName $script:moduleName
    Mock -CommandName Get-RepositoryRoot -ModuleName $script:moduleName { 'C:\fixture\ATAP.Utilities-wt-137-Sprint-0015-work-items' }
    Mock -CommandName Write-GatherCallRecord -ModuleName $script:moduleName { [pscustomobject]@{ recorded = $true } }
    Mock -CommandName Invoke-RestMethod -ModuleName $script:moduleName {
      [pscustomobject]@{
        agent = 'gather-content-summary'
        status = 'ok'
        query = $null
        items = @([pscustomobject]@{ id = 'item-1'; text = 'summary' })
        truncated = $false
        error = $null
      }
    }
  }

  It 'exports the public command from the source module' {
    Get-Command -Name Get-ContentSummary -Module $script:moduleName | Should -Not -BeNullOrEmpty
  }

  It 'posts the exact request contract to the default resource path' {
    $result = Get-ContentSummary -Tags @('schema', 'migration') -WorktreeRoot 'C:\fixture\repo'

    $result.status | Should -BeExactly 'ok'
    @($result.items).Count | Should -Be 1
    Should -Invoke Invoke-RestMethod -ModuleName $script:moduleName -Times 1 -ParameterFilter {
      $Method -eq 'Post' -and
      $ContentType -eq 'application/json' -and
      $Uri.AbsoluteUri -eq 'https://localhost:50042/api/v1/gather-content' -and
      $Headers.Count -eq 1 -and
      $Headers.ContainsKey('Idempotency-Key') -and
      [guid]::Parse([string]$Headers['Idempotency-Key']) -ne [guid]::Empty -and
      (($Body | ConvertFrom-Json).PSObject.Properties.Name -join ',') -eq 'tags,depth,width,instance'
    }
    Should -Invoke Write-GatherCallRecord -ModuleName $script:moduleName -Times 1 -ParameterFilter {
      $AgentName -eq 'gather-content-summary' -and $Depth -eq 3 -and $Width -eq 2 -and $Instance -eq 'production'
    }
  }

  It 'gives explicit endpoint parameters precedence over global settings' {
    Get-ContentSummary -Tags @('precedence') -Scheme https -HostName 127.0.0.1 -Port 50041 -Path '/custom/gather' -WorktreeRoot 'C:\fixture\repo' | Out-Null

    Should -Invoke Invoke-RestMethod -ModuleName $script:moduleName -Times 1 -ParameterFilter {
      $Uri.AbsoluteUri -eq 'https://127.0.0.1:50041/custom/gather'
    }
  }

  It 'builds a bracketed IPv6 loopback URI' {
    Get-ContentSummary -Tags @('ipv6') -HostName '::1' -Port 50043 -WorktreeRoot 'C:\fixture\repo' | Out-Null

    Should -Invoke Invoke-RestMethod -ModuleName $script:moduleName -Times 1 -ParameterFilter {
      $Uri.AbsoluteUri -eq 'https://[::1]:50043/api/v1/gather-content'
    }
  }

  It 'rejects non-HTTPS before REST I/O and records a safe error envelope' {
    $result = Get-ContentSummary -Tags @('unsafe') -Scheme http -HostName localhost -Port 50041 -WorktreeRoot 'C:\fixture\repo'

    $result.status | Should -BeExactly 'Error'
    $result.error.code | Should -BeExactly 'GatherContentRequestFailed'
    Should -Invoke Invoke-RestMethod -ModuleName $script:moduleName -Times 0
    Should -Invoke Write-GatherCallRecord -ModuleName $script:moduleName -Times 1 -ParameterFilter { $Response.status -eq 'Error' }
  }

  It 'rejects a remote host before REST I/O' {
    $result = Get-ContentSummary -Tags @('unsafe') -Scheme https -HostName '192.0.2.10' -Port 50041 -WorktreeRoot 'C:\fixture\repo'

    $result.status | Should -BeExactly 'Error'
    Should -Invoke Invoke-RestMethod -ModuleName $script:moduleName -Times 0
  }

  It 'rejects an out-of-range port before REST I/O' {
    $result = Get-ContentSummary -Tags @('unsafe') -Scheme https -HostName localhost -Port 50300 -WorktreeRoot 'C:\fixture\repo'

    $result.status | Should -BeExactly 'Error'
    Should -Invoke Invoke-RestMethod -ModuleName $script:moduleName -Times 0
  }

  It 'rejects a path containing a query before REST I/O' {
    $result = Get-ContentSummary -Tags @('unsafe') -Port 50041 -Path '/api/v1/gather-content?token=value' -WorktreeRoot 'C:\fixture\repo'

    $result.status | Should -BeExactly 'Error'
    Should -Invoke Invoke-RestMethod -ModuleName $script:moduleName -Times 0
  }

  It 'returns and records a generic error without exposing exception text' {
    Mock -CommandName Invoke-RestMethod -ModuleName $script:moduleName { throw 'secret-value-should-never-escape' }

    $result = Get-ContentSummary -Tags @('failure') -Port 50041 -WorktreeRoot 'C:\fixture\repo'
    $serialized = $result | ConvertTo-Json -Depth 8 -Compress

    $result.status | Should -BeExactly 'Error'
    $serialized | Should -Not -Match 'secret-value-should-never-escape'
    Should -Invoke Write-GatherCallRecord -ModuleName $script:moduleName -Times 1 -ParameterFilter {
      $ErrorMessage -eq 'AceOutpost gather-content request failed.'
    }
  }

  It 'fails closed when mandatory recording fails' {
    Mock -CommandName Write-GatherCallRecord -ModuleName $script:moduleName { throw 'record unavailable' }

    { Get-ContentSummary -Tags @('record') -Port 50041 -WorktreeRoot 'C:\fixture\repo' } |
      Should -Throw 'Gather-call recording is mandatory and did not complete.'
  }

  It 'does not send prompt text or secret-shaped values in the REST body' {
    Get-ContentSummary -Tags @('safe') -Port 50041 -Prompt 'token=super-secret' -WorktreeRoot 'C:\fixture\repo' | Out-Null

    Should -Invoke Invoke-RestMethod -ModuleName $script:moduleName -Times 1 -ParameterFilter {
      $Body -notmatch 'super-secret|token|prompt|authorization|connectionstring'
    }
  }

  It 'generates a distinct idempotency UUID for each logical invocation' {
    $script:observedIdempotencyKeys = [System.Collections.Generic.List[string]]::new()
    Mock -CommandName Invoke-RestMethod -ModuleName $script:moduleName {
      $script:observedIdempotencyKeys.Add([string]$Headers['Idempotency-Key'])
      [pscustomobject]@{ agent = 'gather-content-summary'; status = 'success'; items = @(); truncated = $false }
    }

    Get-ContentSummary -Tags @('first') -Port 50041 -WorktreeRoot 'C:\fixture\repo' | Out-Null
    Get-ContentSummary -Tags @('second') -Port 50041 -WorktreeRoot 'C:\fixture\repo' | Out-Null

    $script:observedIdempotencyKeys.Count | Should -Be 2
    [guid]::Parse($script:observedIdempotencyKeys[0]) | Should -Not -Be ([guid]::Empty)
    [guid]::Parse($script:observedIdempotencyKeys[1]) | Should -Not -Be ([guid]::Empty)
    $script:observedIdempotencyKeys[0] | Should -Not -BeExactly $script:observedIdempotencyKeys[1]
  }

  It 'returns the stable six-member agent envelope' {
    $result = Get-ContentSummary -Tags @('shape') -Port 50041 -WorktreeRoot 'C:\fixture\repo'

    ($result.PSObject.Properties.Name -join ',') | Should -BeExactly 'agent,status,query,items,truncated,error'
    ($result.query.PSObject.Properties.Name -join ',') | Should -BeExactly 'tags,depth,width,instance'
  }
}
