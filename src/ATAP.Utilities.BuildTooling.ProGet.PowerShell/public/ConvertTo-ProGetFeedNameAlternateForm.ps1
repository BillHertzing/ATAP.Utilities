function ConvertTo-ProGetFeedNameAlternateForm {
  [CmdletBinding(DefaultParameterSetName = 'FromIndividual')]
  param(
    # FromIndividual Parameter Set
    [Parameter(ParameterSetName = 'FromIndividual', Mandatory = $true)]
    [string]$ExternalInternal, # 'External' or 'Internal'

    [Parameter(ParameterSetName = 'FromIndividual', Mandatory = $true)]
    [string]$ReleasedPrerelease, # 'Released' or 'Prerelease'

    [Parameter(ParameterSetName = 'FromIndividual', Mandatory = $true)]
    [string]$PackageType, # 'NuGet', 'PSResourceGet', or 'ChocolateyGet'

    [Parameter(ParameterSetName = 'FromIndividual', Mandatory = $true)]
    [string]$ProductionQualityAssurance, # 'Production', 'QualityAssurance', or 'Integration'

    [Parameter(ParameterSetName = 'FromIndividual', Mandatory = $true)]
    [string]$PullPush, # 'Pull' or 'Push'

    # FromShort Parameter Set
    [Parameter(ParameterSetName = 'FromShort', Mandatory = $true)]
    [string]$ShortName,

    # LongName Parameter Set
    [Parameter(ParameterSetName = 'LongName', Mandatory = $true)]
    [string]$LongName
  )

  Begin {
    Write-PSFMessage -Level Verbose -Message 'Entering function: ConvertTo-ProGetFeedNameAlternateForm' -Tag 'ConvertTo-ProGetFeedNameAlternateForm', 'Trace'

    if (-not (Get-Command -Name 'Convert-ProGetFeedType' -CommandType Function -ErrorAction SilentlyContinue)) {
      . (Join-Path $PSScriptRoot '..\private\Convert-ProGetFeedType.ps1')
    }

    $longToShort = @{
      ExternalInternal           = @{ 'External' = 'Ext'; 'Internal' = 'Int' }
      ReleasedPrerelease         = @{ 'Released' = 'Rel'; 'Prerelease' = 'Pre' }
      PackageType                = @{ 'NuGet' = 'Nug'; 'PSResourceGet' = 'PSR'; 'ChocolateyGet' = 'Cho' }
      ProductionQualityAssurance = @{ 'Production' = 'Prod'; 'QualityAssurance' = 'QA'; 'Integration' = 'Intg' }
      PullPush                   = @{ 'Pull' = 'Pull'; 'Push' = 'Push' }
    }

    $shortToLong = @{
      Ext = 'External'; Int = 'Internal'
      Rel = 'Released'; Pre = 'Prerelease'
      Nug = 'NuGet'; PSR = 'PSResourceGet'; Cho = 'ChocolateyGet'
      Prod = 'Production'; QA = 'QualityAssurance'; Intg = 'Integration'
      Pull = 'Pull'; Push = 'Push'
    }

    # ToDO: Rethink this: now it uses the actual language-specific feed name - figure out how to use the universal key instead
    # ToDo: put this someplace common where it can be used by other functions
    $regExPattern = '^PackageRepository(?<LocationType>Internal|External)(?<VersionType>Released|Prerelease)(?<PackageProviderName>PSResourceGet|ChocolateyGet|NuGet)(?<PackageType>Production|QualityAssurance|Integration)(?<PushPullType>Pull|Push)Feed$'

    $result = $null
  }

  Process {
    switch ($PSCmdlet.ParameterSetName) {

      'FromIndividual' {
        try {
          if (-not $longToShort.ExternalInternal.ContainsKey($ExternalInternal)) {
            throw "Invalid ExternalInternal: $ExternalInternal"
          }
          if (-not $longToShort.ReleasedPrerelease.ContainsKey($ReleasedPrerelease)) {
            throw "Invalid ReleasedPrerelease: $ReleasedPrerelease"
          }
          if (-not $longToShort.PackageType.ContainsKey($PackageType)) {
            throw "Invalid PackageType: $PackageType"
          }
          if (-not $longToShort.ProductionQualityAssurance.ContainsKey($ProductionQualityAssurance)) {
            throw "Invalid ProductionQualityAssurance: $ProductionQualityAssurance"
          }
          if (-not $longToShort.PullPush.ContainsKey($PullPush)) {
            throw "Invalid PullPush: $PullPush"
          }

          $ShortExternalInternal = $longToShort.ExternalInternal[$ExternalInternal]
          $ShortReleasedPrerelease = $longToShort.ReleasedPrerelease[$ReleasedPrerelease]
          $ShortPackageType = $longToShort.PackageType[$PackageType]
          $ShortProdQA = $longToShort.ProductionQualityAssurance[$ProductionQualityAssurance]
          $ShortPullPush = $longToShort.PullPush[$PullPush]
        }
        catch {
          $errorMessage = "One of the individual values is invalid. Exception: $($_.Exception.Message)"
          Write-PSFMessage -Level Error -Message $errorMessage -Tag 'ConvertTo-ProGetFeedNameAlternateForm', 'Trace', 'Error'
          throw $errorMessage
        }
        $result = "$ShortExternalInternal$ShortReleasedPrerelease$ShortPackageType$ShortProdQA$ShortPullPush"
      }

      'FromShort' {
        if ($ShortName.Length -lt 15) {
          $errorMessage = "ShortName '$ShortName' is too short to parse (expected >=15 characters)."
          Write-PSFMessage -Level Error -Message $errorMessage -Tag 'ConvertTo-ProGetFeedNameAlternateForm', 'Trace', 'Error'
          throw $errorMessage
        }

        try {
          $parsed = @{
            ShortExternalInternal   = $ShortName.Substring(0, 3)
            ShortReleasedPrerelease = $ShortName.Substring(3, 3)
            ShortPackageType        = $ShortName.Substring(6, 3)
            ShortProdQA             = $ShortName.Substring(9, 4)
            ShortPullPush           = $ShortName.Substring(13)
          }
        }
        catch {
          $errorMessage = "ShortName '$ShortName' did not parse."
          Write-PSFMessage -Level Error -Message $errorMessage -Tag 'ConvertTo-ProGetFeedNameAlternateForm', 'Trace', 'Error'
          throw $errorMessage
        }

        $result = [PSCustomObject]@{
          ExternalInternal           = $shortToLong[$parsed.ShortExternalInternal]
          ReleasedPrerelease         = $shortToLong[$parsed.ShortReleasedPrerelease]
          PackageType                = $shortToLong[$parsed.ShortPackageType]
          ProductionQualityAssurance = $shortToLong[$parsed.ShortProdQA]
          PullPush                   = $shortToLong[$parsed.ShortPullPush]
          LongName                   = 'PackageRepository' + $($shortToLong[$parsed.ShortExternalInternal]) + $($shortToLong[$parsed.ShortReleasedPrerelease]) +
          $($shortToLong[$parsed.ShortPackageType]) + $($shortToLong[$parsed.ShortProdQA]) +
          $($shortToLong[$parsed.ShortPullPush]) + 'Feed'
        }
      }

      'LongName' {
        # use $regExPattern to pull apart the $feedName into its components
        if ($LongName -notmatch $regExPattern) {
          $errorMessage = "Long feed name '$LongName' does not match expected pattern."
          Write-PSFMessage -Level Error -Message $errorMessage -Tag 'ConvertTo-ProGetFeedNameAlternateForm', 'Trace', 'Error'
          throw $errorMessage
        }
        $locationType = $matches['LocationType']
        $versionType = $matches['VersionType']
        $packageProviderName = $matches['PackageProviderName']
        $packageType = $matches['PackageType']
        $proGetFeedType = Convert-ProGetFeedType $packageProviderName
        $pushPullType = $matches['PushPullType']
        $result = [PSCustomObject]@{
          ExternalInternal           = $locationType
          ReleasedPrerelease         = $versionType
          PackageType                = $packageProviderName
          ProductionQualityAssurance = $packageType
          PullPush                   = $pushPullType
        }
      }
    }
  }
  End {
    Write-PSFMessage -Level Verbose -Message 'Leaving function: ConvertTo-ProGetFeedNameAlternateForm' -Tag 'ConvertTo-ProGetFeedNameAlternateForm', 'Trace'
    return $result
  }
}
