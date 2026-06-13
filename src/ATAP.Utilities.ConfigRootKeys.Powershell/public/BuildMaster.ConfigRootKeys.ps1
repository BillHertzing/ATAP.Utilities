###################################################
## ConfigRootKeys.ps1
## Defines BuildMaster pipeline and OtterScript plan settings keys.
###################################################

$global:configRootKeys.Add('BuildMasterBaseUrlConfigRootKey', 'BuildMasterBaseUrl')
$global:configRootKeys.Add('BuildMasterAdminApiKeySecretNameConfigRootKey', 'BuildMasterAdminApiKeySecretName')
$global:configRootKeys.Add('BuildMasterDefaultRaftIdConfigRootKey', 'BuildMasterDefaultRaftId')
$global:configRootKeys.Add('BuildMasterDefaultRaftItemTypeCodeConfigRootKey', 'BuildMasterDefaultRaftItemTypeCode')
# these folders are relative to the repo root
$global:configRootKeys.Add('BuildMasterFilesFolderRelativePathConfigRootKey', 'BuildMasterFilesFolderRelativePath')
$global:configRootKeys.Add('BuildMasterPlansFolderRelativePathConfigRootKey', 'BuildMasterPlansFolderRelativePath')
$global:configRootKeys.Add('BuildMasterPipelinesFolderRelativePathConfigRootKey', 'BuildMasterPipelinesFolderRelativePath')
$global:configRootKeys.Add('BuildMasterScriptsFolderRelativePathConfigRootKey', 'BuildMasterScriptsFolderRelativePath')
# absolute path of the OtterScript plans directory on this host
$global:configRootKeys.Add('BuildMasterPlansDirectoryConfigRootKey', 'BuildMasterPlansDirectory')
$global:configRootKeys.Add('BuildMasterCSharpPerProjectPlanPathConfigRootKey', 'BuildMasterCSharpPerProjectPlanPath')
