$publicFunctions = @(Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'public') -Filter '*.ps1' -File -ErrorAction SilentlyContinue)
$privateFunctions = @(Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'private') -Filter '*.ps1' -File -ErrorAction SilentlyContinue)
foreach ($import in @($publicFunctions + $privateFunctions)) {
  . $import.FullName
}

Export-ModuleMember -Function @(
  'ConvertTo-BuildPromotionTierName'
  'ConvertTo-ProGetFeedNameAlternateForm'
  'Get-CurrentTierFromStage'
  'Get-PairedPreviousTierName'
  'Get-PairedTierIndex'
  'Get-PairedTierValidationPlan'
  'Get-TierFromNBGVLabel'
  'Get-TierOrder'
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
  'Register-ProGetFeedSet'
  'Remove-ProGetApiKeys'
  'Remove-ProGetFeeds'
  'Rename-ProGetFeed'
  'Resolve-DatabaseFeedTier'
  'Resolve-PairedTierFeedName'
  'Resolve-ProGetFeedFromSettings'
  'Resolve-PromotionTierFromFeedName'
  'Set-FloatingPackagePins'
  'Test-ProGetFeedSet'
  'Test-PromotionWithinCeiling'
) -Cmdlet @() -Variable @() -Alias @()
