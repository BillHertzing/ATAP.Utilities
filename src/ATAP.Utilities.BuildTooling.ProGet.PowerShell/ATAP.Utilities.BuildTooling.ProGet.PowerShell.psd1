@{
  RootModule           = 'ATAP.Utilities.BuildTooling.ProGet.PowerShell.psm1'
  ModuleVersion        = '0.1.0'
  GUID                 = '35EE8B2A-E1D7-4668-8B4A-A6E9F5767303'
  Author               = 'Bill Hertzing for ATAPUtilities.org'
  CompanyName          = 'ATAPUtilities.org'
  Copyright            = '(c) 2018 - 2026 Bill Hertzing. All rights reserved. All code is under the MIT license'
  Description          = 'BuildTooling ProGet package-feed child module.'

  PowerShellVersion    = '7.0'
  CompatiblePSEditions = @('Core')
  RequiredModules      = @(
    @{ ModuleName = 'ATAP.Utilities.BuildTooling.Common.PowerShell'; ModuleVersion = '0.1.7' }
    @{ ModuleName = 'ATAP.Utilities.BuildTooling.AiRendering.PowerShell'; ModuleVersion = '0.1.0' }
    @{ ModuleName = 'ATAP.Utilities.BuildTooling.Secrets.PowerShell'; ModuleVersion = '0.1.0' }
  )

  FunctionsToExport    = @(
    'ConvertTo-BuildPromotionTierName'
    'ConvertTo-ProGetFeedNameAlternateForm'
    'Get-CurrentTierFromStage'
    'Get-PairedPreviousTierName'
    'Get-PairedTierIndex'
    'Get-PairedTierValidationPlan'
    'Get-TierFromNBGVLabel'
    'Get-TierOrder'
    'Grant-ElevationBrokerStartRights'
    'Install-ATAPModuleAllUsers'
    'Invoke-MalwareScan'
    'Invoke-PairedTierPromotion'
    'List-ProGetApiKeys'
    'List-ProGetConnectors'
    'List-ProGetFeeds'
    'Move-ProGetPackageInterTier'
    'Move-ProGetPackageIntraTier'
    'New-ProGetApiKey'
    'New-ProGetConnector'
    'New-ProGetFeedSet'
    'Promote-DatabaseChangePackage'
    'Promote-ProGetPackage'
    'Publish-DatabaseChangePackageToProGet'
    'Publish-NuGetPackageToProGet'
    'Publish-PSModuleToProGet'
    'Publish-PSModuleToProGetFeed'
    'Publish-UniversalPackageToProGet'
    'Register-ElevationBrokerTask'
    'Register-ProGetFeedSet'
    'Remove-ProGetApiKeys'
    'Remove-ProGetFeeds'
    'Rename-ProGetFeed'
    'Request-ElevatedInstall'
    'Resolve-DatabaseFeedTier'
    'Resolve-PairedTierFeedName'
    'Resolve-ProGetFeedFromSettings'
    'Resolve-PromotionTierFromFeedName'
    'Set-FloatingPackagePins'
    'Test-ProGetFeedSet'
    'Test-PromotionWithinCeiling'
  )
  CmdletsToExport      = @()
  VariablesToExport    = @()
  AliasesToExport      = @()

  PrivateData          = @{
    PSData = @{
      Tags       = @('ATAP', 'BuildTooling', 'ProGet', 'PowerShell')
      ProjectUri = 'https://github.com/whertzing/ATAP.Utilities'
    }
  }
}
