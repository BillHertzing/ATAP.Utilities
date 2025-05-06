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
  # Env variables used by Jenkins
  # JENKINS_HOME applies only to jenkins Controller nodes
  $global:configRootKeys['JENKINS_HOMEConfigRootKey']           = $global:Settings[$global:configRootKeys['JENKINS_HOMEConfigRootKey']]
  # These Jenkins Environment Variables are used to access a Jenkins Controller and Authenticate
  $global:configRootKeys['JENKINS_URLConfigRootKey']            = $global:Settings[$global:configRootKeys['JENKINS_URLConfigRootKey']]
  $global:configRootKeys['JENKINS_USER_IDConfigRootKey']        = $global:Settings[$global:configRootKeys['JENKINS_USER_IDConfigRootKey']]
  $global:configRootKeys['JENKINS_API_TOKENConfigRootKey']      = $global:Settings[$global:configRootKeys['JENKINS_API_TOKENConfigRootKey']]
  $global:configRootKeys['CommonJarsBasePathConfigRootKey']     = $global:Settings[$global:configRootKeys['CommonJarsBasePathConfigRootKey']]
  #'CLASSPATH'                                                   = (Join-Path ($global:Settings[$global:configRootKeys['CommonJarsBasePathConfigRootKey']]) '*') + [IO.Path]::PathSeparator + ([Environment]::GetEnvironmentVariable('CLASSPATH'))

  # Where all things Security and Secrets related are stored
  $global:configRootKeys['SECURE_CLOUD_BASE_PATHConfigRootKey'] = $global:Settings[$global:configRootKeys['SECURE_CLOUD_BASE_PATHConfigRootKey']]

  # related to the Hashicorp Vault installation and operations
  $global:configRootKeys['VAULT_TOKENConfigRootKey']            = $global:Settings[$global:configRootKeys['VAULT_TOKENConfigRootKey']]
  $global:configRootKeys['VAULT_ADDRConfigRootKey']             = $global:Settings[$global:configRootKeys['VAULT_ADDRConfigRootKey']]

  # OpenSSL Environment variables
  $global:configRootKeys['OPENSSL_HOMEConfigRootKey']           = $global:Settings[$global:configRootKeys['OPENSSL_HOMEConfigRootKey']]
  $global:configRootKeys['OPENSSL_CONFConfigRootKey']           = $global:Settings[$global:configRootKeys['OPENSSL_CONFConfigRootKey']]
  $global:configRootKeys['RANDFILEConfigRootKey']               = $global:Settings[$global:configRootKeys['RANDFILEConfigRootKey']]


  # Env variables used by ChatGPT
  $global:configRootKeys['CHATGPT_URLConfigRootKey']            = $global:Settings[$global:configRootKeys['CHATGPT_URLConfigRootKey']]
  $global:configRootKeys['CHATGPT_USER_IDConfigRootKey']        = $global:Settings[$global:configRootKeys['CHATGPT_USER_IDConfigRootKey']]
  $global:configRootKeys['CHATGPT_API_TOKENConfigRootKey']      = $global:Settings[$global:configRootKeys['CHATGPT_API_TOKENConfigRootKey']]

  # related to the Hydrus-Network application
  $global:configRootKeys['HYDRUS_ACCESS_KEYConfigRootKey']      = $global:Settings[$global:configRootKeys['HYDRUS_ACCESS_KEYConfigRootKey']]

  # Allows Wireshark and other applications to capture the SSL Keys pre-negotiation, so HTTPS SSL traffic can be decrypted
  $global:configRootKeys['SSLKEYLOGFILEConfigRootKey']          = $global:Settings[$global:configRootKeys['SSLKEYLOGFILEConfigRootKey']]

}

function Set-EnvironmentVariablesProcess {
  Write-PSFMessage -Level Debug -Message ("setting $(($global:envVars.keys).count) environment variables in global_EnvironmentVariables.ps1")

  $global:envVars.keys | ForEach-Object { $key = $_
    [System.Environment]::SetEnvironmentVariable($key, $global:envVars[$key], 'Process')
  }

}

