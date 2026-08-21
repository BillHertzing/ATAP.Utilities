function Test-ApplicationClassification {
  <#
  .SYNOPSIS
    Validates a repository's executable-project classification manifest.
  .DESCRIPTION
    Discovers project files, excludes named paths before reading XML, combines declared
    SDK/OutputType signals with evaluated MSBuild properties, and requires a case-safe
    one-to-one disposition for every executable shape. Shipping topology and the ratified
    AG02 Release/net10.0/RID-less portable publish matrix are fail-closed.
  .PARAMETER RepositoryRoot
    Repository root containing the projects described by the manifest.
  .PARAMETER ManifestPath
    Repository-local application classification manifest.
  .PARAMETER ExcludedProjectPath
    Exact repository-relative project paths excluded before XML parsing or evaluation.
  .PARAMETER SchemaPath
    Central JSON schema path. Defaults to the schema beside this module's Resources folder.
  .PARAMETER EvidencePath
    Optional directory receiving deterministic normalized JSON after successful validation.
  .PARAMETER EvaluationThrottleLimit
    Maximum number of concurrent read-only MSBuild property evaluations.
  .OUTPUTS
    PSCustomObject containing deterministic normalized output and validation counts.
  .EXAMPLE
    Test-ApplicationClassification -RepositoryRoot . -ManifestPath .\Build\ApplicationClassification.json -ExcludedProjectPath OpenHardwareMonitorLib/OpenHardwareMonitorLib.csproj
  .NOTES
    Task 15.180.p.P4. This function never restores, builds, publishes, or deploys a project.
  .LINK
    https://learn.microsoft.com/dotnet/core/tools/dotnet-msbuild
  #>
  [CmdletBinding(SupportsShouldProcess)]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $RepositoryRoot,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $ManifestPath,

    [string[]] $ExcludedProjectPath = @(),

    [string] $SchemaPath = (Join-Path $PSScriptRoot '..\Resources\application-classification.schema.json'),

    [string] $EvidencePath,

    [ValidateRange(1, 32)]
    [int] $EvaluationThrottleLimit = 8
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    $logAvailable = $null -ne (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)
    if ($logAvailable) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Starting application classification validation.'
    }

    $root = (Resolve-Path -LiteralPath $RepositoryRoot -ErrorAction Stop).Path.TrimEnd('\', '/')
    $manifestFile = (Resolve-Path -LiteralPath $ManifestPath -ErrorAction Stop).Path
    $schemaFile = (Resolve-Path -LiteralPath $SchemaPath -ErrorAction Stop).Path
  }

  process {
    $errors = [Collections.Generic.List[string]]::new()
    $normalize = { param([string] $Value) $Value.Replace('\', '/').TrimStart('./') }
    $isUnsafe = {
      param([string] $Value)
      [string]::IsNullOrWhiteSpace($Value) -or
      [IO.Path]::IsPathRooted($Value) -or
      $Value.Contains('\') -or
      @($Value -split '/' | Where-Object { $_ -eq '..' }).Count -gt 0 -or
      $Value.StartsWith('/')
    }

    $manifestRaw = Get-Content -LiteralPath $manifestFile -Raw -ErrorAction Stop
    if (-not ($manifestRaw | Test-Json -SchemaFile $schemaFile -ErrorAction Stop)) {
      throw 'ATAPAPP001: classification manifest does not conform to the central schema.'
    }
    $manifest = $manifestRaw | ConvertFrom-Json -Depth 20

    $ohmPath = 'OpenHardwareMonitorLib/OpenHardwareMonitorLib.csproj'
    $excluded = @((@($ExcludedProjectPath) + $ohmPath) | ForEach-Object { & $normalize $_ } | Sort-Object -Unique)
    foreach ($path in $excluded) {
      if (& $isUnsafe $path) { $errors.Add("ATAPAPP002 unsafe excluded path '$path'.") }
    }

    $allProjectFiles = @(Get-ChildItem -LiteralPath $root -Recurse -Filter '*.csproj' -File -ErrorAction Stop |
        Where-Object { $_.FullName -notmatch '[\\/](bin|obj|_generated|\.git)[\\/]' } |
        ForEach-Object {
          $relative = & $normalize ([IO.Path]::GetRelativePath($root, $_.FullName))
          [pscustomobject]@{ FullName = $_.FullName; RelativePath = $relative }
        } |
        Sort-Object RelativePath)

    $excludedSet = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $excluded | ForEach-Object { $null = $excludedSet.Add($_) }
    $projectFiles = @($allProjectFiles | Where-Object {
        -not $excludedSet.Contains($_.RelativePath) -and
        $_.RelativePath -notmatch '(?i)(^|/)tests/fixtures/'
      })

    $ohmDiscovered = @($allProjectFiles | Where-Object { $_.RelativePath -ieq $ohmPath }).Count -gt 0
    if ($ohmDiscovered -and -not $excludedSet.Contains($ohmPath)) {
      $errors.Add('ATAPAPP003 OpenHardwareMonitorLib must be excluded before XML parsing and evaluation.')
    }

    $declared = [Collections.Generic.List[object]]::new()
    foreach ($project in $projectFiles) {
      try {
        [xml] $xml = Get-Content -LiteralPath $project.FullName -Raw -ErrorAction Stop
        $sdkValues = [Collections.Generic.List[string]]::new()
        if ($xml.Project.HasAttribute('Sdk')) { $sdkValues.Add([string] $xml.Project.GetAttribute('Sdk')) }
        foreach ($sdkNode in @($xml.SelectNodes("/*[local-name()='Project']/*[local-name()='Sdk']"))) {
          if ($sdkNode.Name) { $sdkValues.Add([string] $sdkNode.Name) }
          if ($sdkNode.InnerText) { $sdkValues.Add([string] $sdkNode.InnerText) }
        }
        $outputTypes = @($xml.SelectNodes("//*[local-name()='OutputType']") | ForEach-Object { $_.InnerText.Trim() })
        $applicationSdk = @($sdkValues | Where-Object {
            $_ -match '(^|;)Microsoft\.NET\.Sdk\.(Web|BlazorWebAssembly|Worker)(/|;|$)'
          }).Count -gt 0
        $declaredExecutable = $applicationSdk -or @($outputTypes | Where-Object { $_ -in @('Exe', 'WinExe') }).Count -gt 0
        $declared.Add([pscustomobject]@{
            RelativePath = $project.RelativePath
            DeclaredExecutable = $declaredExecutable
            Sdk = @($sdkValues | Sort-Object -Unique) -join ';'
            OutputType = @($outputTypes | Sort-Object -Unique) -join ';'
          })
      }
      catch {
        $errors.Add("ATAPAPP004 XML parse failed for '$($project.RelativePath)': $($_.Exception.Message)")
      }
    }

    $evaluated = @($projectFiles | ForEach-Object -Parallel {
        $project = $_
        $psi = [Diagnostics.ProcessStartInfo]::new()
        $psi.FileName = 'dotnet'
        $psi.WorkingDirectory = [IO.Path]::GetDirectoryName($project.FullName)
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        foreach ($argument in @(
            'msbuild', $project.FullName, '-nologo', '-getProperty:OutputType',
            '-getProperty:UsingMicrosoftNETSdkWeb', '-getProperty:UsingMicrosoftNETSdkBlazorWebAssembly',
            '-getProperty:UsingMicrosoftNETSdkWorker', '-getProperty:IsTestProject'
          )) { $null = $psi.ArgumentList.Add($argument) }
        $process = [Diagnostics.Process]::new()
        $process.StartInfo = $psi
        $null = $process.Start()
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $process.WaitForExit()
        $stdout = $stdoutTask.GetAwaiter().GetResult()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        if ($process.ExitCode -ne 0) {
          [pscustomobject]@{ RelativePath = $project.RelativePath; Error = $stderr.Trim(); EvaluatedExecutable = $false }
        }
        else {
          try {
            $properties = ($stdout | ConvertFrom-Json -Depth 10).Properties
            $isApplicationShape = $properties.OutputType -in @('Exe', 'WinExe') -or
              $properties.UsingMicrosoftNETSdkWeb -eq 'true' -or
              $properties.UsingMicrosoftNETSdkBlazorWebAssembly -eq 'true' -or
              $properties.UsingMicrosoftNETSdkWorker -eq 'true'
            $isTestProject = $properties.IsTestProject -eq 'true'
            $isExecutable = $isApplicationShape -and -not $isTestProject
            [pscustomobject]@{
              RelativePath = $project.RelativePath
              Error = $null
              EvaluatedExecutable = $isExecutable
              IsTestProject = $isTestProject
              OutputType = [string] $properties.OutputType
            }
          }
          catch {
            [pscustomobject]@{ RelativePath = $project.RelativePath; Error = $_.Exception.Message; EvaluatedExecutable = $false }
          }
        }
      } -ThrottleLimit $EvaluationThrottleLimit)

    foreach ($failure in @($evaluated | Where-Object Error)) {
      $errors.Add("ATAPAPP005 MSBuild evaluation failed for '$($failure.RelativePath)': $($failure.Error)")
    }

    $testProjectSet = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    @($evaluated | Where-Object IsTestProject).RelativePath | ForEach-Object { $null = $testProjectSet.Add($_) }
    $detectedSet = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    @($declared | Where-Object { $_.DeclaredExecutable -and -not $testProjectSet.Contains($_.RelativePath) }).RelativePath |
      ForEach-Object { $null = $detectedSet.Add($_) }
    @($evaluated | Where-Object EvaluatedExecutable).RelativePath | ForEach-Object { $null = $detectedSet.Add($_) }
    $detected = @($detectedSet | Sort-Object)

    $actualPathByCaseFold = @{}
    foreach ($project in $projectFiles) { $actualPathByCaseFold[$project.RelativePath.ToLowerInvariant()] = $project.RelativePath }
    $manifestPaths = [Collections.Generic.List[string]]::new()
    foreach ($application in @($manifest.applications)) {
      $path = [string] $application.projectPath
      $manifestPaths.Add($path)
      if (& $isUnsafe $path) { $errors.Add("ATAPAPP006 unsafe manifest path '$path'.") }
      if ($path -ieq $ohmPath -or $path -match '(^|/)OpenHardwareMonitorLib(/|$)') {
        $errors.Add("ATAPAPP007 OpenHardwareMonitorLib is forbidden in the manifest: '$path'.")
      }
      $folded = $path.ToLowerInvariant()
      if ($actualPathByCaseFold.ContainsKey($folded) -and $actualPathByCaseFold[$folded] -cne $path) {
        $errors.Add("ATAPAPP008 non-canonical path casing '$path'; expected '$($actualPathByCaseFold[$folded])'.")
      }
      if ([string] $application.qualityTier -cne 'Production') {
        $errors.Add("ATAPAPP009 '$path' must declare qualityTier Production.")
      }
    }

    $duplicates = @($manifestPaths | Group-Object { $_.ToLowerInvariant() } | Where-Object Count -gt 1 |
        ForEach-Object { $_.Group | Sort-Object } | Sort-Object -Unique)
    foreach ($duplicate in $duplicates) { $errors.Add("ATAPAPP010 duplicate manifest path '$duplicate'.") }

    $manifestSet = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $manifestPaths | ForEach-Object { $null = $manifestSet.Add($_) }
    $unclassified = @($detected | Where-Object { -not $manifestSet.Contains($_) })
    $stale = @($manifestPaths | Where-Object { -not $detectedSet.Contains($_) } | Sort-Object -Unique)
    $unclassified | ForEach-Object { $errors.Add("ATAPAPP011 unclassified executable '$_'.") }
    $stale | ForEach-Object { $errors.Add("ATAPAPP012 stale manifest entry '$_'.") }

    $roots = @($manifest.applications | Where-Object classification -eq 'ShippingRoot')
    if ($roots.Count -gt 1) { $errors.Add('ATAPAPP013 more than one shipping root is not authorized.') }
    $rootSet = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $roots.projectPath | ForEach-Object { $null = $rootSet.Add([string] $_) }

    foreach ($application in @($manifest.applications)) {
      $path = [string] $application.projectPath
      switch ([string] $application.classification) {
        'ShippingRoot' {
          if (-not $application.shipping -or $null -ne $application.componentOf) {
            $errors.Add("ATAPAPP014 shipping-root topology is invalid for '$path'.")
          }
          $publish = $application.publish
          if ($null -eq $publish -or $publish.configuration -cne 'Release' -or
            $publish.targetFramework -cne 'net10.0' -or $null -ne $publish.runtimeIdentifier -or
            $publish.selfContained -ne $false -or $publish.publishSingleFile -ne $false -or
            $publish.publishTrimmed -ne $false -or $publish.useAppHost -ne $false -or
            $publish.independentComponentPublish -ne $false) {
            $errors.Add("ATAPAPP015 shipping root '$path' does not match exact AG02 metadata.")
          }
        }
        'ShippingComponent' {
          if (-not $application.shipping -or [string]::IsNullOrWhiteSpace([string] $application.componentOf) -or
            -not $rootSet.Contains([string] $application.componentOf) -or $path -ieq [string] $application.componentOf -or
            $null -ne $application.publish) {
            $errors.Add("ATAPAPP016 shipping-component topology is invalid for '$path'.")
          }
        }
        default {
          if ($application.shipping -or $null -ne $application.componentOf -or $null -ne $application.publish) {
            $errors.Add("ATAPAPP017 nonshipping disposition is invalid for '$path'.")
          }
        }
      }
      if ($manifest.repository -eq 'ATAP.Utilities' -and $path.StartsWith('samples/', [StringComparison]::OrdinalIgnoreCase) -and $application.shipping) {
        $errors.Add("ATAPAPP018 ATAP.Utilities sample cannot ship: '$path'.")
      }
      if ($manifest.repository -eq 'Ace' -and $path.StartsWith('AceOutpost.', [StringComparison]::OrdinalIgnoreCase) -and $application.shipping) {
        $errors.Add("ATAPAPP019 AceOutpost cannot ship without a later approval: '$path'.")
      }
    }

    if ($errors.Count -gt 0) {
      $message = @($errors | Sort-Object -Unique) -join [Environment]::NewLine
      if ($logAvailable) { Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $message }
      throw $message
    }

    $normalizedApplications = @($manifest.applications | Sort-Object projectPath | ForEach-Object {
        $ordered = [ordered]@{
          projectPath = [string] $_.projectPath
          classification = [string] $_.classification
          shipping = [bool] $_.shipping
          componentOf = $_.componentOf
          qualityTier = [string] $_.qualityTier
        }
        if ($null -ne $_.publish) {
          $ordered.publish = [ordered]@{
            configuration = [string] $_.publish.configuration
            targetFramework = [string] $_.publish.targetFramework
            runtimeIdentifier = $_.publish.runtimeIdentifier
            selfContained = [bool] $_.publish.selfContained
            publishSingleFile = [bool] $_.publish.publishSingleFile
            publishTrimmed = [bool] $_.publish.publishTrimmed
            useAppHost = [bool] $_.publish.useAppHost
            independentComponentPublish = [bool] $_.publish.independentComponentPublish
          }
        }
        [pscustomobject] $ordered
      })
    $normalized = [ordered]@{
      schemaVersion = [string] $manifest.schemaVersion
      repository = [string] $manifest.repository
      applications = $normalizedApplications
      detectedExecutablePaths = $detected
      excludedProjectPaths = $excluded
    }
    $normalizedJson = $normalized | ConvertTo-Json -Depth 20

    if ($EvidencePath -and $PSCmdlet.ShouldProcess($EvidencePath, 'Write normalized classification evidence')) {
      $evidenceDirectory = [IO.Path]::GetFullPath($EvidencePath)
      $null = [IO.Directory]::CreateDirectory($evidenceDirectory)
      [IO.File]::WriteAllText(
        (Join-Path $evidenceDirectory 'application-classification.normalized.json'),
        $normalizedJson + [Environment]::NewLine,
        [Text.UTF8Encoding]::new($false)
      )
    }

    [pscustomobject]@{
      Success = $true
      Repository = [string] $manifest.repository
      ProjectCount = $projectFiles.Count
      ParsedProjectCount = $declared.Count
      EvaluatedProjectCount = $evaluated.Count
      ExecutableCount = $detected.Count
      ClassifiedCount = $manifest.applications.Count
      UnclassifiedPaths = @()
      StaleManifestPaths = @()
      DuplicatePaths = @()
      ExcludedProjectPaths = $excluded
      OpenHardwareMonitorAbsent = -not $detectedSet.Contains($ohmPath) -and -not $manifestSet.Contains($ohmPath)
      NormalizedJson = $normalizedJson
    }
  }

  end {
    if ($logAvailable) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Completed application classification validation.'
    }
  }
}
