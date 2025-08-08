function Get-ChocolateyPackagesNeedingUpdate {
  [CmdletBinding()]
  param (
    # [parameter(mandatory = $true)]
    # [ValidateNotNullOrEmpty()]
    # [string]$path
    # , [parameter(mandatory = $false, ParameterSetName = 'Files')]
    # [string[]]$onHostPackagesPaths
    # , [parameter(mandatory = $false, ParameterSetName = 'Computers')]
    # [string[]]$ComputerNames
  )
  ########################################
  BEGIN {
    Write-PSFMessage -Level Debug -Message 'Starting Function Get-ChocolateyPackagesNeedingUpdate in module %ModuleName%' -Tag 'Trace'

    $regexPattern = '^(?<Id>\S+?)\|(?<Version>\S+?)\|(?<AvailableVersion>\S+?)\|(?<Pinned>\S+?)$'
    $discardPreambleLines = 3
    $discardPostambleLines = 2

    $script:lineNumber = 0


    #$excludeRegexPattern = '\.install$|^KB\d|^dotnet|^vcredist|^vscode-|^netfx-|^chocolatey-|^version$'
    $excludeRegexPattern = '\.install$'
    $packages = @{}
    $exeName = 'choco'
    $Arguments = @('outdated')
    # Create the process start info
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $exeName
    $startInfo.Arguments = $Arguments -join ' '
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    # Create the process object (not yet started)
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo

        $outputQueue = [System.Collections.Concurrent.ConcurrentQueue[string]]::new()
    $errorQueue = [System.Collections.Concurrent.ConcurrentQueue[string]]::new()

    $script:ProcessLine = {
      param($line)
      if ($script:lineNumber -lt $discardPreambleLines) {
        # Skip preamble lines
        $script:lineNumber++
        return
      }
      if ($line -match $regexPattern) {
        Write-Output $line
      }
      else {
        Write-PSFMessage -Level Error -Message "$line did not match the pattern $regExPattern. Line number $index was $($lines[$index])"
      }

      $script:lineNumber++
    }

  }

  PROCESS {
#── capture the interactive runspace so we can marshal back to it ─────────────────
    $script:MainRunspace = [runspace]::DefaultRunspace

    #── add event handlers *after* the runspace variable exists ──────────────────────
    $process.add_OutputDataReceived({
        param($sender, $args)
        if ($args.Data) {
            # Marshal enqueue into the main runspace
            $null = $script:MainRunspace.Invoke(
                { param($l, $q) $q.Enqueue($l) },
                $args.Data, $outputQueue
            )
        }
    })

    $process.add_ErrorDataReceived({
        param($sender, $args)
        if ($args.Data) {
            $null = $script:MainRunspace.Invoke(
                { param($l, $q) $q.Enqueue($l) },
                $args.Data, $errorQueue
            )
        }
    })
    # Start process
    $process.Start() | Out-Null

    # Begin asynchronous read of stdout and stderr
    $process.BeginOutputReadLine()
    $process.BeginErrorReadLine()

        # Process lines as they arrive, without waiting for process exit
    while (-not $process.HasExited) {
              $line = $null
      while ($outputQueue.TryDequeue([ref]$line)) {
        & $ProcessLine $line
              $line = $null
      }
      $errLine = $null
      while ($errorQueue.TryDequeue([ref]$errLine)) {
        Write-PSFMessage -Level Warning -Message "Choco warning: $errLine" -Tag 'Trace', 'Get-ChocolateyPackagesNeedingUpdate'
        $errLine = $null
      }

      Start-Sleep -Milliseconds 100
    }

    # Process any remaining lines after exit
    while ($outputQueue.TryDequeue([ref]$line)) {
      & $ProcessLine $line
    }
    while ($errorQueue.TryDequeue([ref]$errLine)) {
      Write-PSFMessage -Level Warning -Message "Choco warning: $errLine" -Tag 'Trace', 'Get-ChocolateyPackagesNeedingUpdate'
    }

    # Wait for exit
    $process.WaitForExit()
    $exitCode = $process.ExitCode

    return $exitCode
  }



  #   if ($matches['Id'] -match $excludeRegexPattern) {
  #     Write-PSFMessage -Level Error -Message "$($matches['Id']) matched the excludeRegexPattern $excludeRegexPattern). Line number $index was $($lines[$index])"
  #     continue
  #   }
  #   $validVersion = $null
  #   $validAvailableVersion = $null
  #   if ($lines[$index] -match $regexPattern) {
  #     if ([System.Version]::tryParse($matches['Version'], [REF] $validVersion)) {
  #       if ([System.Version]::tryParse($matches['AvailableVersion'], [REF] $validAvailableVersion)) {
  #         if ($matches['Pinned'] -match 'true') {
  #           Write-PSFMessage -Level Warning -Message "Package $($matches['Id']) is pinned and cannot be updated. Line number $index was $($lines[$index])"
  #         }
  #         else {
  #           # Add the package to the list of packages needing update
  #           $packages[$matches['Id']] = @{Version = $validVersion; AvailableVersion = $validAvailableVersion }
  #         }
  #       }
  #       else {
  #         Write-PSFMessage -Level Error -Message "$($matches['Version']) did not parse as a [System.Version]. Line number $index was $($lines[$index])"
  #       }
  #       else {
  #         Write-PSFMessage -Level Error -Message "$($matches['AvailableVersion']) did not parse as a [System.Version]. Line number $index was $($lines[$index])"
  #       }
  #     }
  #     else {
  #       Write-PSFMessage -Level Error -Message "$lines[$index] did not match the pattern $regExPattern. Line number $index was $($lines[$index])"
  #     }
  #   }
  # }


  END {
    $packages
    Write-PSFMessage -Level Debug -Message 'Ending Function Get-ChocolateyPackagesNeedingUpdate in module %ModuleName%' -Tag 'Trace'
  }
}
