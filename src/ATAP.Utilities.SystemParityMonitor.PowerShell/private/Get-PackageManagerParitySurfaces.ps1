function Get-PackageManagerParitySurfaces {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string] $HostName
  )

  begin {
    $fn = 'Get-PackageManagerParitySurfaces'
    $mn = 'ATAP.Utilities.SystemParityMonitor.PowerShell'
    Write-ParityMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Collecting Chocolatey, pip, npm, and NuGet package surfaces.'
  }

  process {
    $surfaces = [System.Collections.Generic.List[object]]::new()
    $packages = [System.Collections.Generic.List[object]]::new()
    $managerDefinitions = @(
      [pscustomobject]@{ Name = 'Chocolatey'; Command = 'choco'; Arguments = @('list', '--local-only', '--limit-output', '--no-color') },
      [pscustomobject]@{ Name = 'pip'; Command = 'python'; Arguments = @('-m', 'pip', 'list', '--format=json', '--disable-pip-version-check') },
      [pscustomobject]@{ Name = 'npm'; Command = 'npm'; Arguments = @('list', '--global', '--depth=0', '--json') },
      [pscustomobject]@{ Name = 'NuGet'; Command = 'dotnet'; Arguments = @('tool', 'list', '--global') }
    )

    foreach ($definition in $managerDefinitions) {
      $command = Get-Command -Name $definition.Command -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
      if (-not $command) {
        $surfaces.Add([pscustomobject]@{
            Category = 'PackageManagerStatus'
            Item = $definition.Name
            Value = '<not-installed>'
            Source = 'Get-Command'
          })
        continue
      }

      try {
        $result = Invoke-ParityNativeCommand -Command $command.Source -ArgumentList $definition.Arguments
        if ($definition.Name -eq 'Chocolatey' -and $result.ExitCode -ne 0) {
          # Chocolatey 2.x removed --local-only because `list` is local-only.
          $result = Invoke-ParityNativeCommand -Command $command.Source -ArgumentList @('list', '--limit-output', '--no-color')
        }

        if ($result.ExitCode -ne 0) {
          throw "$($definition.Name) exited with code $($result.ExitCode)."
        }

        $managerPackages = switch ($definition.Name) {
          'Chocolatey' {
            foreach ($line in @($result.Output)) {
              if ($line -match '^(?<Name>[^|]+)\|(?<Version>.+)$') {
                [pscustomobject]@{ Name = $Matches.Name; Version = $Matches.Version }
              }
            }
          }
          'pip' {
            $json = ($result.Output -join [Environment]::NewLine) | ConvertFrom-Json
            foreach ($package in @($json)) {
              [pscustomobject]@{ Name = [string] $package.name; Version = [string] $package.version }
            }
          }
          'npm' {
            $json = ($result.Output -join [Environment]::NewLine) | ConvertFrom-Json
            foreach ($property in @($json.dependencies.PSObject.Properties)) {
              [pscustomobject]@{ Name = [string] $property.Name; Version = [string] $property.Value.version }
            }
          }
          'NuGet' {
            foreach ($line in @($result.Output)) {
              if ($line -match '^\s*(?<Name>\S+)\s+(?<Version>\S+)\s+.+$' -and
                $Matches.Name -notmatch '(?i)^(Package|-+)$') {
                [pscustomobject]@{ Name = $Matches.Name; Version = $Matches.Version }
              }
            }
          }
        }

        foreach ($package in @($managerPackages)) {
          if ([string]::IsNullOrWhiteSpace($package.Name)) {
            continue
          }

          $normalizedName = ConvertTo-ParityPackageName -Name $package.Name
          $packages.Add([pscustomobject]@{
              Manager = $definition.Name
              Name = $normalizedName
              DisplayName = $package.Name
              Version = $package.Version
            })
          $surfaces.Add([pscustomobject]@{
              Category = 'PackageManager'
              Item = "$($definition.Name)/$normalizedName"
              Value = [string] $package.Version
              Source = "$($definition.Command) $($definition.Arguments -join ' ')"
            })
        }

        $surfaces.Add([pscustomobject]@{
            Category = 'PackageManagerStatus'
            Item = $definition.Name
            Value = "Available;PackageCount=$(@($managerPackages).Count)"
            Source = $command.Source
          })
      } catch {
        $surfaces.Add([pscustomobject]@{
            Category = 'PackageManagerStatus'
            Item = $definition.Name
            Value = "AuditError=$($_.Exception.Message)"
            Source = $command.Source
          })
      }
    }

    $conflicts = @(
      $packages |
        Group-Object -Property Name |
        Where-Object { @($_.Group.Manager | Sort-Object -Unique).Count -gt 1 }
    )
    foreach ($conflict in $conflicts) {
      $owners = @(
        $conflict.Group |
          Sort-Object Manager, DisplayName, Version |
          ForEach-Object { "$($_.Manager):$($_.DisplayName)@$($_.Version)" }
      ) -join '; '
      $surfaces.Add([pscustomobject]@{
          Category = 'PackageManagerConflict'
          Item = "$($HostName.ToLowerInvariant())/$($conflict.Name)"
          Value = "ACTION REQUIRED: resolve package ownership conflict ($owners)"
          Source = 'Cross-manager normalized-name check'
        })
      Write-ParityMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Package '$($conflict.Name)' is managed by multiple package managers. Resolve the ownership conflict."
    }

    @($surfaces | Sort-Object Category, Item, Value -Unique)
  }

  end {
  }
}
