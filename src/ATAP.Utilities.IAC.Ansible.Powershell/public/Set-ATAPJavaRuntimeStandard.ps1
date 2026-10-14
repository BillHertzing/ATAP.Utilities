function Set-ATAPJavaRuntimeStandard {
  <#
  .SYNOPSIS
  Applies the ratified ATAP Java runtime standard to the local Windows host.

  .DESCRIPTION
  Verifies the canonical Temurin JRE, fails closed unless every noncanonical MSI
  has a cached rollback package, removes noncanonical runtimes, normalizes the
  machine JAVA_HOME and PATH values, and returns a structured change record.

  .PARAMETER CanonicalJavaHome
  Machine-wide home of the ratified Java runtime.

  .PARAMETER CanonicalProductCode
  MSI product code of the ratified Java runtime.

  .PARAMETER CanonicalPackageVersion
  Exact Chocolatey Temurinjre version ratified for parity.

  .PARAMETER RemoveNoncanonicalRuntime
  Allows removal of noncanonical Java MSI products and stale Chocolatey package registrations.

  .OUTPUTS
  PSCustomObject describing before state, changes, and remaining drift.

  .EXAMPLE
  Set-ATAPJavaRuntimeStandard -RemoveNoncanonicalRuntime -Confirm:$false

  .NOTES
  Task 15.182.j. Run elevated. The function affects only the local host.

  .LINK
  InformationForTheFuture/Sprint0015/Task15.182/JavaRuntimeParityDecision.md
  #>
  [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
  param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $CanonicalJavaHome = 'C:\Program Files\Eclipse Adoptium\jre-21.0.8.9-hotspot',

    [Parameter()]
    [ValidatePattern('^\{[0-9A-Fa-f-]{36}\}$')]
    [string] $CanonicalProductCode = '{85726190-68A9-48EF-B05C-D527D32A6C1B}',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $CanonicalPackageVersion = '21.0.8.9',

    [Parameter()]
    [switch] $RemoveNoncanonicalRuntime
  )

  begin {
    $fn = 'Set-ATAPJavaRuntimeStandard'
    $mn = 'ATAP.Utilities.IAC.Ansible.Powershell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Starting Java runtime standard enforcement.'

    if (-not $IsWindows) {
      throw 'Set-ATAPJavaRuntimeStandard supports Windows only.'
    }

    $principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
      throw 'Set-ATAPJavaRuntimeStandard requires an elevated administrator token.'
    }
  }

  process {
    $canonicalJavaExe = Join-Path $CanonicalJavaHome 'bin\java.exe'
    if (-not (Test-Path -LiteralPath $canonicalJavaExe)) {
      throw "The ratified Java executable is missing: $canonicalJavaExe"
    }

    $chocoCommand = Get-Command -Name 'choco.exe' -ErrorAction Stop
    $canonicalPackageLine = @(& $chocoCommand.Source list --limit-output --exact 'Temurinjre' 2>&1)
    if ($canonicalPackageLine -notcontains "Temurinjre|$CanonicalPackageVersion") {
      throw "Chocolatey package Temurinjre $CanonicalPackageVersion is not installed."
    }

    $uninstallRoots = @(
      'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
      'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    $javaProducts = @(
      Get-ItemProperty -Path $uninstallRoots -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -match '(?i)(java|jdk|jre|temurin|adoptium|openjdk)' } |
        Select-Object DisplayName, DisplayVersion,
          @{Name = 'ProductCode'; Expression = { $_.PSChildName }} |
        Sort-Object DisplayName, DisplayVersion, ProductCode -Unique
    )
    $noncanonicalProducts = @($javaProducts | Where-Object { $_.ProductCode -ne $CanonicalProductCode })

    $installer = New-Object -ComObject WindowsInstaller.Installer
    $rollbackPackages = @(
      foreach ($product in $noncanonicalProducts) {
        $localPackage = $installer.ProductInfo($product.ProductCode, 'LocalPackage')
        if ([string]::IsNullOrWhiteSpace($localPackage) -or -not (Test-Path -LiteralPath $localPackage)) {
          throw "Rollback MSI is unavailable for $($product.DisplayName) $($product.ProductCode). No mutation was performed."
        }
        [pscustomobject]@{
          DisplayName = $product.DisplayName
          ProductCode = $product.ProductCode
          LocalPackage = $localPackage
          Sha256 = (Get-FileHash -LiteralPath $localPackage -Algorithm SHA256).Hash
        }
      }
    )

    $beforeJavaHome = [Environment]::GetEnvironmentVariable('JAVA_HOME', 'Machine')
    $beforeMachinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $canonicalPathEntry = '%JAVA_HOME%\bin'
    $retainedPathEntries = @(
      $beforeMachinePath -split ';' |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Where-Object {
          $expanded = [Environment]::ExpandEnvironmentVariables($_.Trim())
          $_ -ne $canonicalPathEntry -and
            $expanded -ne (Join-Path $CanonicalJavaHome 'bin') -and
            $_ -notmatch '(?i)(oracle\\java|eclipse adoptium|adoptopenjdk|temurin|\\jdk|\\jre)'
        }
    )
    $proposedMachinePath = (@($canonicalPathEntry) + $retainedPathEntries) -join ';'
    $changes = [System.Collections.Generic.List[string]]::new()

    if ($RemoveNoncanonicalRuntime) {
      foreach ($product in $noncanonicalProducts) {
        if ($PSCmdlet.ShouldProcess($product.DisplayName, "Uninstall MSI product $($product.ProductCode)")) {
          $stillInstalled = Get-ItemProperty -Path $uninstallRoots -ErrorAction SilentlyContinue |
            Where-Object { $_.PSChildName -eq $product.ProductCode }
          if ($stillInstalled) {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Removing noncanonical runtime $($product.DisplayName)."
            $process = Start-Process -FilePath 'msiexec.exe' -ArgumentList @('/x', $product.ProductCode, '/qn', '/norestart') -Wait -PassThru
            if ($process.ExitCode -notin @(0, 1605, 3010)) {
              throw "msiexec failed for $($product.ProductCode) with exit code $($process.ExitCode)."
            }
            $changes.Add("Removed MSI $($product.ProductCode)")
          }
        }
      }

      foreach ($stalePackageId in @('AdoptOpenJDKjre', 'Temurin8jre')) {
        $installedLine = @(& $chocoCommand.Source list --limit-output --exact $stalePackageId 2>&1)
        if ($installedLine -match "^$([regex]::Escape($stalePackageId))\|") {
          if ($PSCmdlet.ShouldProcess($stalePackageId, 'Remove stale Chocolatey package registration')) {
            $chocoOutput = @(& $chocoCommand.Source uninstall $stalePackageId --yes --skip-autouninstaller --force --limit-output 2>&1)
            if ($LASTEXITCODE -notin @(0, 2)) {
              throw "Chocolatey cleanup failed for $stalePackageId with exit code $LASTEXITCODE. Output: $($chocoOutput -join ' ')"
            }
            $changes.Add("Removed Chocolatey registration $stalePackageId")
          }
        }
      }
    }

    if ($beforeJavaHome -ne $CanonicalJavaHome -and $PSCmdlet.ShouldProcess('Machine JAVA_HOME', "Set to $CanonicalJavaHome")) {
      [Environment]::SetEnvironmentVariable('JAVA_HOME', $CanonicalJavaHome, 'Machine')
      $changes.Add('Set machine JAVA_HOME')
    }
    if ($beforeMachinePath -ne $proposedMachinePath -and $PSCmdlet.ShouldProcess('Machine Path', 'Place %JAVA_HOME%\bin first and remove noncanonical Java entries')) {
      [Environment]::SetEnvironmentVariable('Path', $proposedMachinePath, 'Machine')
      $changes.Add('Normalized machine Path')
    }

    $env:JAVA_HOME = $CanonicalJavaHome
    $env:Path = ((Join-Path $CanonicalJavaHome 'bin'), ($proposedMachinePath -replace '^%JAVA_HOME%\\bin;?', '')) -join ';'

    $remainingProducts = @(
      Get-ItemProperty -Path $uninstallRoots -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -match '(?i)(java|jdk|jre|temurin|adoptium|openjdk)' } |
        Select-Object DisplayName, DisplayVersion,
          @{Name = 'ProductCode'; Expression = { $_.PSChildName }} |
        Sort-Object DisplayName, DisplayVersion, ProductCode -Unique
    )

    [pscustomobject]@{
      ComputerName = [Environment]::MachineName
      CanonicalJavaHome = $CanonicalJavaHome
      CanonicalPackageVersion = $CanonicalPackageVersion
      BeforeJavaHome = $beforeJavaHome
      BeforeMachinePath = $beforeMachinePath
      ProposedMachinePath = $proposedMachinePath
      RollbackPackages = $rollbackPackages
      Changes = @($changes)
      RemainingProducts = $remainingProducts
      RestartRequired = $false
      IsCompliant = (
        [Environment]::GetEnvironmentVariable('JAVA_HOME', 'Machine') -eq $CanonicalJavaHome -and
        [Environment]::GetEnvironmentVariable('Path', 'Machine').StartsWith($canonicalPathEntry, [StringComparison]::OrdinalIgnoreCase) -and
        @($remainingProducts | Where-Object { $_.ProductCode -ne $CanonicalProductCode }).Count -eq 0
      )
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Finished Java runtime standard enforcement.'
  }
}
