# todo: comment based help

$global:EnvVars = @{
  'ATAPUtilitiesVersion'                                        = $global:Settings[$global:configRootKeys['ATAPUtilitiesVersionConfigRootKey']]
  'DOTNET_CLI_TELEMETRY_OPTOUT'                                 = 1
  $global:configRootKeys['FastTempBasePathConfigRootKey']       = $global:Settings[$global:configRootKeys['FastTempBasePathConfigRootKey']]
  $global:configRootKeys['DropboxAccessTokenConfigRootKey']     = 'PopulateViaSecretsOrManually'
  $global:configRootKeys['DropBoxBasePathConfigRootKey']        = $global:Settings[$global:configRootKeys['DropBoxBasePathConfigRootKey']]
  $global:configRootKeys['ErlangHomeDirConfigRootKey']          = $global:Settings[$global:configRootKeys['ErlangHomeDirConfigRootKey']]
  $global:configRootKeys['ENVIRONMENTConfigRootKey']            = $global:Settings[$global:configRootKeys['ENVIRONMENTConfigRootKey']]
  $global:configRootKeys['FLYWAY_URLConfigRootKey']             = $global:Settings[$global:configRootKeys['FLYWAY_URLConfigRootKey']]
  $global:configRootKeys['FLYWAY_USERConfigRootKey']            = $global:Settings[$global:configRootKeys['FLYWAY_USERConfigRootKey']]
  $global:configRootKeys['FLYWAY_LOCATIONSConfigRootKey']       = $global:Settings[$global:configRootKeys['FLYWAY_LOCATIONSConfigRootKey']]
  $global:configRootKeys['FLYWAY_PASSWORDConfigRootKey']        = $global:Settings[$global:configRootKeys['FLYWAY_PASSWORDConfigRootKey']]
  # Attribution: https://www.red-gate.com/hub/product-learning/flyway/bulk-loading-data-via-a-powershell-script-in-flyway?topic=database-builds&product=flyway
  'FP__projectName'                                             = $global:Settings[$global:configRootKeys['FP__projectNameConfigRootKey']]
  'FP__projectDescription'                                      = $global:Settings[$global:configRootKeys['FP__projectDescriptionConfigRootKey']]
  $global:configRootKeys['GIT_CONFIG_GLOBALConfigRootKey']      = $global:Settings[$global:configRootKeys['GIT_CONFIG_GLOBALConfigRootKey']]
  $global:configRootKeys['GoogleDriveBasePathConfigRootKey']    = $global:Settings[$global:configRootKeys['GoogleDriveBasePathConfigRootKey']]
  $global:configRootKeys['JENKINS_URLConfigRootKey']            = $global:Settings[$global:configRootKeys['JENKINS_URLConfigRootKey']]
  $global:configRootKeys['JENKINS_USER_IDConfigRootKey']        = $global:Settings[$global:configRootKeys['JENKINS_USER_IDConfigRootKey']]
  $global:configRootKeys['JENKINS_API_TOKENConfigRootKey']      = $global:Settings[$global:configRootKeys['JENKINS_API_TOKENConfigRootKey']]
  $global:configRootKeys['CommonJarsBasePathConfigRootKey']     = $global:Settings[$global:configRootKeys['CommonJarsBasePathConfigRootKey']]
  'CLASSPATH'                                                   = (Join-Path ($global:Settings[$global:configRootKeys['CommonJarsBasePathConfigRootKey']]) '*') + [IO.Path]::PathSeparator + ([Environment]::GetEnvironmentVariable('CLASSPATH'))

  # Where all things Security and Secrets related are stored
  $global:configRootKeys['SECURE_CLOUD_BASE_PATHConfigRootKey'] = $global:Settings[$global:configRootKeys['SECURE_CLOUD_BASE_PATHConfigRootKey']]
  # OpenSSL Environment variables
  $global:configRootKeys['OPENSSL_HOMEConfigRootKey']           = $global:Settings[$global:configRootKeys['OPENSSL_HOMEConfigRootKey']]
  $global:configRootKeys['OPENSSL_CONFConfigRootKey']           = $global:Settings[$global:configRootKeys['OPENSSL_CONFConfigRootKey']]
  $global:configRootKeys['RANDFILEConfigRootKey']               = $global:Settings[$global:configRootKeys['RANDFILEConfigRootKey']]

}

function Set-EnvironmentVariablesProcess {
  $global:envVars.keys | ForEach-Object { $key = $_
    [System.Environment]::SetEnvironmentVariable($key, $global:envVars[$key], 'Process')
  }

}

