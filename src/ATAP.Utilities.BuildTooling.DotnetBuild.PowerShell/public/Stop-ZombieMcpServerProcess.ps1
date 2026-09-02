function Stop-ZombieMcpServerProcess {
  <#
  .SYNOPSIS
  Stops stale processes owned by canonical stdio MCP server definitions.

  .DESCRIPTION
  Reads the canonical SharedVSCode MCP catalog, resolves each selected stdio
  server's declared local ports and executable, and stops stale matching
  processes before an AI harness launches a replacement. Port owners are exact.
  Binary matching is exact by executable path; generic shared runtimes such as
  node and pwsh additionally require a server-specific path argument fingerprint.

  .PARAMETER CatalogPath
  Path to the canonical mcp-servers.json file.

  .PARAMETER NativeKey
  Optional canonical native keys to clean. When omitted, all canonical stdio
  entries are evaluated.

  .PARAMETER MinimumAge
  Minimum process age. The default of zero permits immediate pre-launch cleanup.

  .PARAMETER PassThru
  Returns one structured result per selected server.

  .PARAMETER Quiet
  Suppresses successful-stop log messages. MCP startup wrappers use this so no
  non-protocol text can reach the server's standard output stream.

  .OUTPUTS
  PSCustomObject when PassThru is specified; otherwise no output.

  .EXAMPLE
  Stop-ZombieMcpServerProcess -CatalogPath $catalog -NativeKey 'drawio' -WhatIf -PassThru

  .NOTES
  Task 15.75.f. Supports ShouldProcess; unattended startup callers use
  -Confirm:$false only with the canonical catalog path.

  .LINK
  https://learn.microsoft.com/powershell/module/nettcpip/get-nettcpconnection
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $CatalogPath,

    [string[]] $NativeKey,

    [ValidateNotNull()]
    [timespan] $MinimumAge = [timespan]::Zero,

    [switch] $PassThru,

    [switch] $Quiet
  )

  begin {
    $fn = 'Stop-ZombieMcpServerProcess'
    $mn = 'ATAP.Utilities.BuildTooling.DotnetBuild.PowerShell'
    $genericRuntimeNames = @('node', 'node.exe', 'npx', 'npx.cmd', 'pwsh', 'pwsh.exe', 'powershell', 'powershell.exe', 'dotnet', 'dotnet.exe', 'python', 'python.exe')
    $now = [datetime]::UtcNow

    try {
      $resolvedCatalogPath = (Resolve-Path -LiteralPath $CatalogPath -ErrorAction Stop).Path
      $catalog = Get-Content -LiteralPath $resolvedCatalogPath -Raw -ErrorAction Stop |
        ConvertFrom-Json -Depth 100 -ErrorAction Stop
    }
    catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Unable to read canonical MCP catalog '$CatalogPath'. Exception: $($_.Exception.Message)"
      throw
    }

    $selectedServers = @($catalog.servers | Where-Object {
        $_.ownership -eq 'canonical' -and
        $_.transport -eq 'stdio' -and
        (-not $NativeKey -or $_.nativeKey -in $NativeKey)
      })
    if ($NativeKey) {
      $missingKeys = @($NativeKey | Where-Object { $_ -notin @($selectedServers.nativeKey) })
      if ($missingKeys.Count -gt 0) {
        throw "Canonical stdio MCP server key not found: $($missingKeys -join ', ')."
      }
    }

    try {
      $processInventory = @(Get-CimInstance -ClassName Win32_Process -ErrorAction Stop)
    }
    catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Unable to inventory MCP server processes. Exception: $($_.Exception.Message)"
      throw
    }
  }

  process {
    foreach ($server in $selectedServers) {
      $ports = [Collections.Generic.HashSet[int]]::new()
      $declaredPorts = if ($server.PSObject.Properties['expectedListeningPorts']) {
        @($server.expectedListeningPorts)
      }
      else {
        @()
      }
      foreach ($port in $declaredPorts) {
        if ($null -ne $port) { [void]$ports.Add([int]$port) }
      }
      $serverEnvironment = if ($server.PSObject.Properties['env']) { @($server.env) } else { @() }
      foreach ($envEntry in @($serverEnvironment | Where-Object name -eq 'ASPNETCORE_URLS')) {
        foreach ($urlText in @([string]$envEntry.value -split ';')) {
          $uri = $null
          if ([uri]::TryCreate($urlText, [UriKind]::Absolute, [ref]$uri) -and $uri.Port -gt 0) {
            [void]$ports.Add([int]$uri.Port)
          }
        }
      }

      $candidateReasons = @{}
      if ($ports.Count -gt 0) {
        try {
          foreach ($connection in @(Get-NetTCPConnection -State Listen -ErrorAction Stop | Where-Object LocalPort -in @($ports))) {
            $ownerPid = [int]$connection.OwningProcess
            if ($ownerPid -gt 0 -and $ownerPid -ne $PID) {
              $candidateReasons[$ownerPid] = @($candidateReasons[$ownerPid]) + "port:$($connection.LocalPort)"
            }
          }
        }
        catch {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Unable to inspect listening ports for '$($server.nativeKey)'. Exception: $($_.Exception.Message)"
          throw
        }
      }

      $resolvedCommand = [string]$server.command
      $resolvedCommand = $resolvedCommand.Replace('${HOME}', [Environment]::GetFolderPath([Environment+SpecialFolder]::UserProfile))
      $ossRoot = [Environment]::GetEnvironmentVariable('OSS_FORKS_ROOT', 'Process')
      if ([string]::IsNullOrWhiteSpace($ossRoot)) {
        $ossRoot = [Environment]::GetEnvironmentVariable('OSS_FORKS_ROOT', 'User')
      }
      if (-not [string]::IsNullOrWhiteSpace($ossRoot)) {
        $resolvedCommand = $resolvedCommand.Replace('${OSS_FORKS_ROOT}', $ossRoot)
      }
      $commandInfo = Get-Command -Name $resolvedCommand -ErrorAction SilentlyContinue
      $commandPath = if ($commandInfo) { [string]$commandInfo.Source } elseif ([IO.Path]::IsPathRooted($resolvedCommand)) { [IO.Path]::GetFullPath($resolvedCommand) } else { $null }
      $commandLeaf = [IO.Path]::GetFileName($resolvedCommand)
      $requiresFingerprint = $commandLeaf -in $genericRuntimeNames
      $serverArguments = if ($server.PSObject.Properties['args']) { @($server.args) } else { @() }
      $fingerprints = @($serverArguments | ForEach-Object {
          $arg = ([string]$_).Replace('${HOME}', [Environment]::GetFolderPath([Environment+SpecialFolder]::UserProfile))
          if (-not [string]::IsNullOrWhiteSpace($ossRoot)) { $arg = $arg.Replace('${OSS_FORKS_ROOT}', $ossRoot) }
          if ($arg -match '(?i)\.(js|mjs|cjs|py|jar|exe)(?:\s|$)' -or [IO.Path]::IsPathRooted($arg)) { $arg }
        })

      if (-not [string]::IsNullOrWhiteSpace($commandPath)) {
        foreach ($process in $processInventory) {
          $processId = [int]$process.ProcessId
          if ($processId -le 0 -or $processId -eq $PID) { continue }
          $sameExecutable = -not [string]::IsNullOrWhiteSpace([string]$process.ExecutablePath) -and
            [string]::Equals([IO.Path]::GetFullPath([string]$process.ExecutablePath), [IO.Path]::GetFullPath($commandPath), [StringComparison]::OrdinalIgnoreCase)
          if (-not $sameExecutable) { continue }
          $hasFingerprint = -not $requiresFingerprint -or @($fingerprints | Where-Object {
              -not [string]::IsNullOrWhiteSpace([string]$process.CommandLine) -and
              ([string]$process.CommandLine).IndexOf([string]$_, [StringComparison]::OrdinalIgnoreCase) -ge 0
            }).Count -gt 0
          if ($hasFingerprint) {
            $candidateReasons[$processId] = @($candidateReasons[$processId]) + 'binary'
          }
        }
      }

      $candidateIds = [Collections.Generic.List[int]]::new()
      foreach ($processId in @($candidateReasons.Keys | Sort-Object)) {
        $processRecord = @($processInventory | Where-Object ProcessId -eq $processId | Select-Object -First 1)
        if ($MinimumAge -gt [timespan]::Zero -and $processRecord.Count -gt 0 -and $processRecord[0].CreationDate) {
          $createdUtc = if ($processRecord[0].CreationDate -is [datetime]) {
            ([datetime]$processRecord[0].CreationDate).ToUniversalTime()
          }
          else {
            ([Management.ManagementDateTimeConverter]::ToDateTime([string]$processRecord[0].CreationDate)).ToUniversalTime()
          }
          if (($now - $createdUtc) -lt $MinimumAge) { continue }
        }
        $candidateIds.Add([int]$processId)
      }

      $stoppedIds = [Collections.Generic.List[int]]::new()
      $whatIfIds = [Collections.Generic.List[int]]::new()
      foreach ($processId in $candidateIds) {
        $target = "PID $processId for canonical MCP server '$($server.nativeKey)' ($(@($candidateReasons[$processId] | Sort-Object -Unique) -join ', '))"
        if ($PSCmdlet.ShouldProcess($target, 'Force-stop stale MCP server process')) {
          try {
            Stop-Process -Id $processId -Force -ErrorAction Stop
            $stoppedIds.Add($processId)
            if (-not $Quiet) {
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Stopped $target."
            }
          }
          catch {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Failed to stop $target. Exception: $($_.Exception.Message)"
            throw
          }
        }
        else {
          $whatIfIds.Add($processId)
        }
      }

      if ($PassThru) {
        [pscustomobject]@{
          NativeKey = [string]$server.nativeKey
          Ports = @($ports | Sort-Object)
          ResolvedCommand = $commandPath
          CandidateProcessIds = $candidateIds.ToArray()
          StoppedProcessIds = $stoppedIds.ToArray()
          WhatIfProcessIds = $whatIfIds.ToArray()
        }
      }
    }
  }

  end {
  }
}
