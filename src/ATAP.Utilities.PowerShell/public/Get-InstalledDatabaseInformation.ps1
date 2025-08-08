function Get-InstalledDatabaseInformation {
  [CmdletBinding()]
  param ()

  Write-PSFMessage -Level Verbose -Message 'Starting Get-InstalledDatabaseInformation'

  $databaseProcesses = @(
    'mysqld', 'sqlservr', 'postgres', 'pg_ctl',
    'mysqld.exe', 'sqlservr.exe', 'postgres.exe', 'pg_ctl.exe'
  )

  try {
    $runningDBProcesses = Get-Process -ErrorAction SilentlyContinue | Where-Object {
      $databaseProcesses -contains $_.Name
    }

    if ($runningDBProcesses) {
      Write-PSFMessage -Level Important -Message 'Detected running database processes:'
      $runningDBProcesses | ForEach-Object {
        Write-PSFMessage -Level Important -Message "Process: $($_.Name) | ID: $($_.Id) | StartTime: $($_.StartTime)"
      }
    } else {
      Write-PSFMessage -Level Important -Message 'No running database-related processes detected.'
    }

    $possiblePaths = @(
      'C:\Program Files\Microsoft SQL Server',
      'C:\Program Files (x86)\Microsoft SQL Server',
      "$env:ProgramData\chocolatey\lib\sql-server-express",
      'C:\Program Files\MySQL',
      'C:\Program Files (x86)\MySQL',
      "$env:ProgramData\chocolatey\lib\mysql",
      'C:\Program Files\PostgreSQL',
      'C:\Program Files (x86)\PostgreSQL',
      "$env:ProgramData\chocolatey\lib\postgresql"
    )

    $foundPaths = $possiblePaths | Where-Object { Test-Path $_ }

    $registryPaths = @(
      'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
      'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )

    $registrySoftwareMatches = $registryPaths | ForEach-Object {
      Get-ItemProperty $_ -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -match 'MySQL|PostgreSQL|SQL Server' }
      }

      if ($registrySoftwareMatches -or $foundPaths) {
        Write-PSFMessage -Level Important -Message 'Detected installed database software:'
        $registrySoftwareMatches | ForEach-Object {
          Write-PSFMessage -Level Important -Message "Installed: $($_.DisplayName) | Version: $($_.DisplayVersion) | Location: $($_.InstallLocation)"
        }

        foreach ($path in $foundPaths) {
          Write-PSFMessage -Level Important -Message "Detected install folder: $path"
        }
      } else {
        Write-PSFMessage -Level Warning -Message 'No database software found in default or Chocolatey locations.'
      }
    } catch {
      Write-PSFMessage -Level Error -Message "Error occurred while retrieving database info: $($_.Exception.Message)" -Exception $_.Exception
      throw $_
    } finally {
      Write-PSFMessage -Level Verbose -Message 'Completed Get-InstalledDatabaseInformation'
    }
  }
