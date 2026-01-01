<#
.SYNOPSIS
Installs all approved Chocolatey packages from configuration files.

.DESCRIPTION
Parses ApprovedChocolateyPackagesInfo.yml and Ansible playbook files to discover
Chocolatey packages, then installs the latest version of each with any specified
installation parameters. Skips version constraints and always installs latest.

.PARAMETER ApprovedPackagesPath
Path to ApprovedChocolateyPackagesInfo.yml file.

.PARAMETER AnsiblePlaybookPath
Path to Ansible playbook YAML file containing package definitions.

.PARAMETER WhatIf
Shows what packages would be installed without actually installing them.

.OUTPUTS
None. Logs installation progress via Write-PSFMessage.

.EXAMPLE
Rebuild-Chocolatey -ApprovedPackagesPath 'C:\path\to\ApprovedChocolateyPackagesInfo.yml'

.NOTES
AI assisted using Powershell.instructions.md as guidelines

.LINK
https://github.com/whertzing/ATAP.Utilities
#>
function Rebuild-Chocolatey {
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [Parameter(Mandatory = $false)]
    [string]$ApprovedPackagesPath = 'C:\Dropbox\whertzing\GitHub\ATAP.IAC\Resources\ApprovedChocolateyPackagesInfo.yml',

    [Parameter(Mandatory = $false)]
    [string]$AnsiblePlaybookPath = 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.IAC.Ansible.Powershell\private\New_ExampleHostCompleteBuildoutPlaybook.yml'
  )

  BEGIN {
    $fn = 'Rebuild-Chocolatey'
    $mn = 'ATAP.Utilities.IAC.Ansible.Powershell'

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

    # Snippet: Check and populate simple parameter
    $ApprovedPackagesPath = Get-PVal ApprovedPackagesPath $PSBoundParameters ApprovedPackagesPath

    # Snippet: Check and populate simple parameter
    $AnsiblePlaybookPath = Get-PVal AnsiblePlaybookPath $PSBoundParameters AnsiblePlaybookPath

    # Verify PowerShell-Yaml module is available
    if (-not (Get-Module -ListAvailable -Name 'PowerShell-Yaml')) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message 'PowerShell-Yaml module not found. Install with: Install-Module PowerShell-Yaml'
      throw 'PowerShell-Yaml module required'
    }
    Import-Module PowerShell-Yaml -ErrorAction Stop

    $packages = @{}
    $pkgStartName = 'powertoys'
  }

  PROCESS {
    # Snippet: Try-Catch-Finally
    try {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Parsing approved packages from $ApprovedPackagesPath"

      # Parse ApprovedChocolateyPackagesInfo.yml
      if (Test-Path $ApprovedPackagesPath) {
        $approvedYaml = Get-Content -Path $ApprovedPackagesPath -Raw | ConvertFrom-Yaml
        foreach ($pkg in $approvedYaml.Keys) {
          $addedParams = $approvedYaml[$pkg].AddedParameters
          $paramString = if ($null -eq $addedParams -or $addedParams -eq '') {
            ''
          }
          elseif ($addedParams -is [System.Collections.IEnumerable] -and $addedParams -isnot [string]) {
            ($addedParams | Where-Object { $_ -ne $null -and $_ -ne '' }) -join ' '
          }
          elseif ($addedParams -is [string]) {
            $addedParams.Trim()
          }
          else {
            $addedParams.ToString().Trim()
          }

          $notes = $approvedYaml[$pkg].Notes
          $packages[$pkg] = @{
            Name       = $pkg
            Parameters = $paramString
            Source     = 'ApprovedPackages'
            Notes      = $notes
          }
        }
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Loaded $($packages.Count) packages from ApprovedPackagesInfo"
      }
      else {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Approved packages file not found: $ApprovedPackagesPath"
      }

      # Parse Ansible playbook for additional packages using pattern matching
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Parsing Ansible playbook from $AnsiblePlaybookPath"
      if (Test-Path $AnsiblePlaybookPath) {
        $packagesBeforePlaybook = $packages.Count
        $playbookContent = Get-Content -Path $AnsiblePlaybookPath -Raw

        # Remove the PowerShell modules section to avoid parsing module definitions as packages
        $startMarker = '#- name: install the modules defined for each group'
        $endMarker = '# Define and Trust the default ATAP.Utilities production repository'

        $startIndex = $playbookContent.IndexOf($startMarker)
        $endIndex = $playbookContent.IndexOf($endMarker)

        if ($startIndex -ge 0 -and $endIndex -gt $startIndex) {
          # Exclude the section between markers
          $beforeSection = $playbookContent.Substring(0, $startIndex)
          $afterSection = $playbookContent.Substring($endIndex + $endMarker.Length)
          $playbookContent = $beforeSection + $afterSection
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Excluded PowerShell modules section from parsing"
        }

        # Pattern to match: { name: packagename, version: ..., allowprerelease: ..., addedparameters: ..., Notes: ... }
        # This regex looks for the pattern even in comments
        # Requires package name to be alphanumeric with hyphens/dots (excludes PowerShell variables like $m, $pk)
        $pattern = '\{\s*name:\s*([a-zA-Z0-9][a-zA-Z0-9\-\.]*)[^}]*?(?:addedparameters:\s*([^,}]+?))?[^}]*?(?:Notes:\s*([^}]+?))?\s*\}'

        $matches = [regex]::Matches($playbookContent, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

        foreach ($match in $matches) {
          $pkgName = $match.Groups[1].Value.Trim()

          # Skip if package name looks like a PowerShell variable or is invalid
          if ($pkgName -match '^\$' -or $pkgName.Length -lt 2) {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Skipping invalid package name: $pkgName"
            continue
          }

          if ($pkgName -and -not $packages.ContainsKey($pkgName)) {
            # Extract addedparameters if present
            $addedParams = if ($match.Groups[2].Success) {
              $match.Groups[2].Value.Trim()
            }
            else {
              ''
            }

            # Extract Notes if present
            $notes = if ($match.Groups[3].Success) {
              $match.Groups[3].Value.Trim()
            }
            else {
              ''
            }

            # Process parameters
            $paramString = if ($null -eq $addedParams -or $addedParams -eq '') {
              ''
            }
            else {
              $addedParams.Trim()
            }

            $packages[$pkgName] = @{
              Name       = $pkgName
              Parameters = $paramString
              Source     = 'Ansible'
              Notes      = $notes
            }

            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Found package in playbook: $pkgName"
          }
        }

        $packagesFromPlaybook = $packages.Count - $packagesBeforePlaybook
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Parsed $packagesFromPlaybook packages from Ansible playbook"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Total unique packages: $($packages.Count)"
      }
      else {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Ansible playbook not found: $AnsiblePlaybookPath"
      }

      # Install packages
      $successCount = 0
      $failCount = 0
      $skippedCount = 0

      # Define packages to skip
      $packagesToSkip = @('sql-server-express', 'plexmediaserver', 'logitechgaming', 'flyway.commandline', 'nordvpn', 'Everything')

      # Flag to start processing after $pkgStartName is found
      $startProcessing = $false

      # Build list of commands to execute
      $commandList = @()
      foreach ($pkg in $packages.Values | Sort-Object Name) {
        # Check if we've reached the starting package
        if (-not $startProcessing) {
          if ($pkg.Name -eq $pkgStartName) {
            $startProcessing = $true
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Starting processing from package: $($pkg.Name)"
          }
          else {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Skipping package before $pkgStartName : $($pkg.Name)"
            continue
          }
        }

        # Skip packages in the exclusion list
        if ($packagesToSkip -contains $pkg.Name) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Skipping excluded package: $($pkg.Name)"
          continue
        }

        $chocoArgs = @('install', $pkg.Name, '-y')

        if ($pkg.Parameters) {
          # Split parameters and add them individually
          $paramArray = $pkg.Parameters -split '\s+' | Where-Object { $_ }
          $chocoArgs += $paramArray
        }

        $commandList += [PSCustomObject]@{
          Package    = $pkg.Name
          Command    = "choco $($chocoArgs -join ' ')"
          Parameters = $pkg.Parameters
          Source     = $pkg.Source
          Notes      = $pkg.Notes
        }
      }

      # Display all commands
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "The following $($commandList.Count) commands will be executed:"
      Write-Host "`n========================================" -ForegroundColor Cyan
      $commandList | ForEach-Object -Begin { $i = 1 } -Process {
        Write-Host "[$i] Package: $($_.Package)" -ForegroundColor Yellow
        Write-Host "    Command: $($_.Command)" -ForegroundColor White
        if ($_.Parameters) {
          Write-Host "    Parameters: $($_.Parameters)" -ForegroundColor Gray
        }
        Write-Host "    Source: $($_.Source)" -ForegroundColor Gray
        Write-Host ""
        $i++
      }
      Write-Host "========================================`n" -ForegroundColor Cyan

      # Display package notes if any exist
      $packagesWithNotes = $commandList | Where-Object { $_.Notes }
      if ($packagesWithNotes) {
        Write-Host "`nPackage Notes:" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Cyan
        foreach ($pkg in $packagesWithNotes) {
          Write-Host "Package: $($pkg.Package)" -ForegroundColor Yellow
          Write-Host "Note: $($pkg.Notes)" -ForegroundColor White
          Write-Host ""
        }
        Write-Host "========================================`n" -ForegroundColor Cyan
      }

      # Build JSON output with all packages including excluded ones
      $jsonOutput = @()
      foreach ($pkg in $packages.Values | Sort-Object Name) {
        $isExcluded = $packagesToSkip -contains $pkg.Name
        $note = $pkg.Notes
        if ($isExcluded) {
          $note = if ($note) { "$note - NOT INSTALLED" } else { "NOT INSTALLED" }
        }

        $jsonOutput += [PSCustomObject]@{
          PackageName     = $pkg.Name
          AddedParameters = $pkg.Parameters
          Notes           = $note
          Source          = $pkg.Source
        }
      }

      # Write JSON file
      $jsonFilePath = Join-Path $PWD 'InstalledChocolateyPackages.json'
      try {
        $jsonOutput | ConvertTo-Json -Depth 10 | Set-Content -Path $jsonFilePath -Encoding UTF8
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Package list written to: $jsonFilePath"
        Write-Host "Package list written to: $jsonFilePath" -ForegroundColor Green
      }
      catch {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Failed to write JSON file: $($_.Exception.Message)"
      }

      # Prompt for approval
      $approval = Read-Host "Do you want to proceed with these installations? (Y/N)"
      if ($approval -notmatch '^[Yy]') {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Installation cancelled by user"
        return
      }

      # Execute installations
      $startProcessingExec = $false
      foreach ($pkg in $packages.Values | Sort-Object Name) {
        # Check if we've reached the starting package
        if (-not $startProcessingExec) {
          if ($pkg.Name -eq $pkgStartName) {
            $startProcessingExec = $true
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Starting execution from package: $($pkg.Name)"
          }
          else {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Skipping execution for package before '$pkgStartName': $($pkg.Name)"
            $skippedCount++
            continue
          }
        }

        # Skip packages in the exclusion list
        if ($packagesToSkip -contains $pkg.Name) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Skipping execution for excluded package: $($pkg.Name)"
          $skippedCount++
          continue
        }

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Processing package: $($pkg.Name)"

        if ($PSCmdlet.ShouldProcess($pkg.Name, 'Install Chocolatey package')) {
          try {
            $chocoArgs = @('install', $pkg.Name, '-y')

            if ($pkg.Parameters) {
              # Split parameters and add them individually
              $paramArray = $pkg.Parameters -split '\s+' | Where-Object { $_ }
              $chocoArgs += $paramArray
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Installing $($pkg.Name) with parameters: $($pkg.Parameters)"
            }
            else {
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Installing $($pkg.Name) with no parameters"
            }

            $result = & choco @chocoArgs 2>&1
            if ($LASTEXITCODE -eq 0) {
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Successfully installed: $($pkg.Name)"
              $successCount++
            }
            else {
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Failed to install $($pkg.Name): $result"
              $failCount++
            }
          }
          catch {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Exception installing $($pkg.Name): $($_.Exception.Message)"
            $failCount++
          }
        }
        else {
          $skippedCount++
        }
      }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Installation complete. Success: $successCount, Failed: $failCount, Skipped: $skippedCount"
    }
    catch {
      $errorMessage = "Failed to rebuild Chocolatey packages. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw
    }
    finally {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving Function $fn in module $mn"
    }
  }

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}
