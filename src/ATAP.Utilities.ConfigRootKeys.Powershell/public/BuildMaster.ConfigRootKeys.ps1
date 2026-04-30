###################################################
## BuildMaster.ConfigRootKeys.ps1
## Defines BuildMaster pipeline and OtterScript plan settings keys.
###################################################

$global:configRootKeys.Add('BuildMasterBaseUrlConfigRootKey', 'BuildMaster.BaseUrl')
$global:configRootKeys.Add('BuildMasterAdminApiKeySecretNameConfigRootKey', 'BuildMaster.AdminApiKeySecretName')
$global:configRootKeys.Add('BuildMasterPlansDirectoryConfigRootKey', 'BuildMaster.PlansDirectory')
$global:configRootKeys.Add('BuildMasterCSharpPerProjectPlanPathConfigRootKey', 'BuildMaster.CSharpPerProjectPlanPath')
$global:configRootKeys.Add('BuildMasterDefaultRaftIdConfigRootKey', 'BuildMaster.DefaultRaftId')
$global:configRootKeys.Add('BuildMasterDefaultRaftItemTypeCodeConfigRootKey', 'BuildMaster.DefaultRaftItemTypeCode')
