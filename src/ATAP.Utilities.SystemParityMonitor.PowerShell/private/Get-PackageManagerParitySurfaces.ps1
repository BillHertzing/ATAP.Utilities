function Get-PackageManagerParitySurfaces {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string] $HostName,

    [object[]] $PackageManagerProfiles = @()
  )

  begin {
    $fn = 'Get-PackageManagerParitySurfaces'
    $mn = 'ATAP.Utilities.SystemParityMonitor.PowerShell'
    Write-ParityMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Collecting Chocolatey, pip, npm, and NuGet package surfaces.'
  }

  process {
    $surfaces = [System.Collections.Generic.List[object]]::new()
    $packages = [System.Collections.Generic.List[object]]::new()
    $configuredIdentities = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $managerDefinitions = [System.Collections.Generic.List[object]]::new()
    $managerDefinitions.Add([pscustomobject]@{
        Name = 'Chocolatey'
        Identity = 'Machine'
        ProfilePath = $null
        Command = 'choco'
        Arguments = @('list', '--local-only', '--limit-output', '--no-color')
      })

    foreach ($profile in @($PackageManagerProfiles)) {
      $identity = [string]$profile.Identity
      if ([string]::IsNullOrWhiteSpace($identity)) {
        throw 'Every package-manager profile must specify a non-empty Identity.'
      }
      $identity = $identity.Trim()
      if ($identity -match '[/|]') {
        throw "Package-manager profile identity '$identity' cannot contain '/' or '|'."
      }
      if (-not $configuredIdentities.Add($identity)) {
        throw "Package-manager profile identity '$identity' is configured more than once."
      }

      foreach ($profileDefinition in @(
          [pscustomobject]@{ Name = 'pip'; PathProperty = 'PipPath'; Command = 'python'; ArgumentPrefix = @('-m', 'pip', 'list', '--path'); ArgumentSuffix = @('--format=json', '--disable-pip-version-check') },
          [pscustomobject]@{ Name = 'npm'; PathProperty = 'NpmPrefix'; Command = 'npm'; ArgumentPrefix = @('list', '--global', '--prefix'); ArgumentSuffix = @('--depth=0', '--json') },
          [pscustomobject]@{ Name = 'NuGet'; PathProperty = 'NuGetToolPath'; Command = 'dotnet'; ArgumentPrefix = @('tool', 'list', '--tool-path'); ArgumentSuffix = @() }
        )) {
        $profilePath = [string]$profile.($profileDefinition.PathProperty)
        if ([string]::IsNullOrWhiteSpace($profilePath)) {
          $surfaces.Add([pscustomobject]@{
              Category = 'PackageManagerStatus'
              Item = "$identity/$($profileDefinition.Name)"
              Value = '<profile-path-not-configured>'
              Source = $profileDefinition.PathProperty
            })
          continue
        }
        if (-not [IO.Path]::IsPathFullyQualified($profilePath)) {
          throw "$($profileDefinition.PathProperty) for identity '$identity' must be a fully qualified path."
        }

        $managerDefinitions.Add([pscustomobject]@{
            Name = $profileDefinition.Name
            Identity = $identity
            ProfilePath = $profilePath
            Command = $profileDefinition.Command
            Arguments = @($profileDefinition.ArgumentPrefix) + @($profilePath) + @($profileDefinition.ArgumentSuffix)
          })
      }
    }

    if (@($PackageManagerProfiles).Count -eq 0) {
      foreach ($managerName in @('pip', 'npm', 'NuGet')) {
        $surfaces.Add([pscustomobject]@{
            Category = 'PackageManagerStatus'
            Item = "Unconfigured/$managerName"
            Value = '<profile-paths-not-configured>'
            Source = 'PackageManagerProfiles'
          })
      }
    }

    foreach ($definition in $managerDefinitions) {
      $command = Get-Command -Name $definition.Command -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
      if (-not $command) {
        $surfaces.Add([pscustomobject]@{
            Category = 'PackageManagerStatus'
            Item = "$($definition.Identity)/$($definition.Name)"
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
              Identity = $definition.Identity
              Name = $normalizedName
              ConflictKey = "$($definition.Identity)|$normalizedName"
              DisplayName = $package.Name
              Version = $package.Version
            })
          $surfaces.Add([pscustomobject]@{
              Category = 'PackageManager'
              Item = "$($definition.Identity)/$($definition.Name)/$normalizedName"
              Value = [string] $package.Version
              Source = "$($definition.Command) $($definition.Arguments -join ' ')"
            })
        }

        $surfaces.Add([pscustomobject]@{
            Category = 'PackageManagerStatus'
            Item = "$($definition.Identity)/$($definition.Name)"
            Value = "Available;PackageCount=$(@($managerPackages).Count)"
            Source = $command.Source
          })
      } catch {
        $surfaces.Add([pscustomobject]@{
            Category = 'PackageManagerStatus'
            Item = "$($definition.Identity)/$($definition.Name)"
            Value = "AuditError=$($_.Exception.Message)"
            Source = $command.Source
          })
      }
    }

    $conflicts = @(
      $packages |
        Group-Object -Property ConflictKey |
        Where-Object { @($_.Group.Manager | Sort-Object -Unique).Count -gt 1 }
    )
    foreach ($conflict in $conflicts) {
      $conflictIdentity = [string]$conflict.Group[0].Identity
      $conflictPackageName = [string]$conflict.Group[0].Name
      $owners = @(
        $conflict.Group |
          Sort-Object Manager, DisplayName, Version |
          ForEach-Object { "$($_.Manager):$($_.DisplayName)@$($_.Version)" }
      ) -join '; '
      $surfaces.Add([pscustomobject]@{
          Category = 'PackageManagerConflict'
          Item = "$($HostName.ToLowerInvariant())/$conflictIdentity/$conflictPackageName"
          Value = "ACTION REQUIRED: resolve package ownership conflict ($owners)"
          Source = 'Cross-manager normalized-name check'
        })
      Write-ParityMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Package '$conflictPackageName' for identity '$conflictIdentity' is managed by multiple package managers. Resolve the ownership conflict."
    }

    @($surfaces | Sort-Object Category, Item, Value -Unique)
  }

  end {
  }
}
