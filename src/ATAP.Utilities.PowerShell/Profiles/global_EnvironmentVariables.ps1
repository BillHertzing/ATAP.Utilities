# todo: comment based help

$global:envVars = @{
  'ATAPUtilitiesVersion'                                     = $global:Settings[$global:configRootKeys['ATAPUtilitiesVersionConfigRootKey']]
  'DOTNET_CLI_TELEMETRY_OPTOUT'                              = 1
  $global:configRootKeys['DropboxAccessTokenConfigRootKey']  = 'PopulateViaSecretsOrManually'
  $global:configRootKeys['DropBoxBasePathConfigRootKey']     = $global:Settings[$global:configRootKeys['DropBoxBasePathConfigRootKey']]
  'ERLANG_HOME'                                              = $global:Settings[$global:configRootKeys['ErlangHomeDirConfigRootKey']]
  'Environment'                                              = $global:Settings[$global:configRootKeys['EnvironmentConfigRootKey']]
  $global:configRootKeys['FLYWAY_URLConfigRootKey']          = $global:Settings[$global:configRootKeys['FLYWAY_URLConfigRootKey']]
  'FLYWAY_USER'                                              = $global:Settings[$global:configRootKeys['FLYWAY_USERConfigRootKey']]
  'FLYWAY_LOCATIONS'                                         = $global:Settings[$global:configRootKeys['FLYWAY_LOCATIONSConfigRootKey']]
  'FLYWAY_PASSWORD'                                          = $global:Settings[$global:configRootKeys['FLYWAY_PASSWORDConfigRootKey']]
  # Attribution: https://www.red-gate.com/hub/product-learning/flyway/bulk-loading-data-via-a-powershell-script-in-flyway?topic=database-builds&product=flyway
  'FP__projectName'                                          = $global:Settings[$global:configRootKeys['FP__projectNameConfigRootKey']]
  'FP__projectDescription'                                   = $global:Settings[$global:configRootKeys['FP__projectDescriptionConfigRootKey']]
  $global:configRootKeys['GoogleDriveBasePathConfigRootKey'] = $global:Settings[$global:configRootKeys['GoogleDriveBasePathConfigRootKey']]
  $global:configRootKeys['JENKINS_URLConfigRootKey']         = $global:Settings[$global:configRootKeys['JENKINS_URLConfigRootKey']]
  $global:configRootKeys['JENKINS_USER_IDConfigRootKey']     = $global:Settings[$global:configRootKeys['JENKINS_USER_IDConfigRootKey']]
  $global:configRootKeys['JENKINS_API_TOKENConfigRootKey']   = $global:Settings[$global:configRootKeys['JENKINS_API_TOKENConfigRootKey']]
  $global:configRootKeys['CommonJarsBasePathConfigRootKey']  = $global:Settings[$global:configRootKeys['CommonJarsBasePathConfigRootKey']]
  'CLASSPATH'                                                = (Join-Path ($global:Settings[$global:configRootKeys['CommonJarsBasePathConfigRootKey']]) '*') + ';' + ([Environment]::GetEnvironmentVariable('CLASSPATH'))
}

function Set-EnvironmentVariablesProcess {
  $global:envVars.keys | ForEach-Object { $key = $_
    [System.Environment]::SetEnvironmentVariable($key, $global:envVars[$key], 'Process')
  }

}

