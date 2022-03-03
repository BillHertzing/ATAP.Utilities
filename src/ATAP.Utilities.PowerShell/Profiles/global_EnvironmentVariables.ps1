# todo: comment based help

$global:envVars = @{
  'Environment'                 = $global:Settings[$global:configRootKeys['EnvironmentConfigRootKey']]
  $global:configRootKeys['DropboxAccessTokenConfigRootKey'] = 'PopulateViaSecretsOrManually'
  'DOTNET_CLI_TELEMETRY_OPTOUT' = 1
  'ERLANG_HOME'                 = $global:Settings[$global:configRootKeys['ErlangHomeDirConfigRootKey']]
  'ATAPUtilitiesVersion'        = $global:Settings[$global:configRootKeys['ATAPUtilitiesVersionConfigRootKey']]
  'FLYWAY_URL'                  = $global:Settings[$global:configRootKeys['FLYWAY_URLConfigRootKey']]
  'FLYWAY_USER'                 = $global:Settings[$global:configRootKeys['FLYWAY_USERConfigRootKey']]
  'FLYWAY_LOCATIONS'            = $global:Settings[$global:configRootKeys['FLYWAY_LOCATIONSConfigRootKey']]
  'FLYWAY_PASSWORD'             = $global:Settings[$global:configRootKeys['FLYWAY_PASSWORDConfigRootKey']]
  # Attribution: https://www.red-gate.com/hub/product-learning/flyway/bulk-loading-data-via-a-powershell-script-in-flyway?topic=database-builds&product=flyway
  'FP__projectName'             = $global:Settings[$global:configRootKeys['FP__projectNameConfigRootKey']]
  'FP__projectDescription'      = $global:Settings[$global:configRootKeys['FP__projectDescriptionConfigRootKey']]
  $global:configRootKeys['GoogleDriveBasePathConfigRootKey'] =  $global:Settings[$global:configRootKeys['GoogleDriveBasePathConfigRootKey']]
}

function Set-Envvars {
  $global:envVars.keys | ForEach-Object { $key = $_
    [System.Environment]::SetEnvironmentVariable($key, $global:envVars[$key], 'Process')
  }

}

