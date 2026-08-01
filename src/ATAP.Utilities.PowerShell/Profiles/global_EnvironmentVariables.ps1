# todo: comment based help

$global:EnvVars = @{
  'ATAPUtilitiesVersion'                                        = $global:Settings[$global:configRootKeys['ATAPUtilitiesVersionConfigRootKey']]
  'DOTNET_CLI_TELEMETRY_OPTOUT'                                 = 1
  $global:configRootKeys['FastTempBasePathConfigRootKey']       = $global:Settings[$global:configRootKeys['FastTempBasePathConfigRootKey']]
  $global:configRootKeys['DropBoxBasePathConfigRootKey']        = $global:Settings[$global:configRootKeys['DropBoxBasePathConfigRootKey']]
  $global:configRootKeys['ErlangHomeDirConfigRootKey']          = $global:Settings[$global:configRootKeys['ErlangHomeDirConfigRootKey']]
  $global:configRootKeys['ENVIRONMENTConfigRootKey']            = $global:Settings[$global:configRootKeys['ENVIRONMENTConfigRootKey']]
  $global:configRootKeys['GIT_CONFIG_GLOBALConfigRootKey']      = $global:Settings[$global:configRootKeys['GIT_CONFIG_GLOBALConfigRootKey']]
  $global:configRootKeys['GoogleDriveBasePathConfigRootKey']    = $global:Settings[$global:configRootKeys['GoogleDriveBasePathConfigRootKey']]
  # Env variables used by Jenkins
  # JENKINS_HOME applies only to jenkins Controller nodes
  $global:configRootKeys['JENKINS_HOMEConfigRootKey']           = $global:Settings[$global:configRootKeys['JENKINS_HOMEConfigRootKey']]
  # These Jenkins Environment Variables are used to access a Jenkins Controller and Authenticate
  $global:configRootKeys['JENKINS_URLConfigRootKey']            = $global:Settings[$global:configRootKeys['JENKINS_URLConfigRootKey']]
  $global:configRootKeys['JENKINS_USER_IDConfigRootKey']        = $global:Settings[$global:configRootKeys['JENKINS_USER_IDConfigRootKey']]
  $global:configRootKeys['CommonJarsBasePathConfigRootKey']     = $global:Settings[$global:configRootKeys['CommonJarsBasePathConfigRootKey']]
  #'CLASSPATH'                                                   = (Join-Path ($global:Settings[$global:configRootKeys['CommonJarsBasePathConfigRootKey']]) '*') + [IO.Path]::PathSeparator + ([Environment]::GetEnvironmentVariable('CLASSPATH'))

  # Where all things Security and Secrets related are stored
  $global:configRootKeys['SECURE_CLOUD_BASE_PATHConfigRootKey'] = $global:Settings[$global:configRootKeys['SECURE_CLOUD_BASE_PATHConfigRootKey']]


  # Used by Bitwarden
  $global:configRootKeys['BW_EMAILConfigRootKey']               = $global:Settings[$global:configRootKeys['BW_EMAILConfigRootKey']]
  # related to the Hashicorp Vault installation and operations
  $global:configRootKeys['VAULT_ADDRConfigRootKey']             = $global:Settings[$global:configRootKeys['VAULT_ADDRConfigRootKey']]

  # OpenSSL Environment variables
  $global:configRootKeys['OPENSSL_HOMEConfigRootKey']           = $global:Settings[$global:configRootKeys['OPENSSL_HOMEConfigRootKey']]
  $global:configRootKeys['OPENSSL_CONFConfigRootKey']           = $global:Settings[$global:configRootKeys['OPENSSL_CONFConfigRootKey']]
  $global:configRootKeys['RANDFILEConfigRootKey']               = $global:Settings[$global:configRootKeys['RANDFILEConfigRootKey']]

  # Env variables used by ChatGPT
  $global:configRootKeys['CHATGPT_URLConfigRootKey']            = $global:Settings[$global:configRootKeys['CHATGPT_URLConfigRootKey']]
  $global:configRootKeys['CHATGPT_USER_IDConfigRootKey']        = $global:Settings[$global:configRootKeys['CHATGPT_USER_IDConfigRootKey']]
  # Allows Wireshark and other applications to capture the SSL Keys pre-negotiation, so HTTPS SSL traffic can be decrypted
  # $global:configRootKeys['SSLKEYLOGFILEConfigRootKey']          = $global:Settings[$global:configRootKeys['SSLKEYLOGFILEConfigRootKey']]

}

# Root directory holding cloned/forked open-source repositories (e.g. MCP servers).
# Consumed as ${OSS_FORKS_ROOT} by .mcp.json in each repository.
# Guarded: the installed ATAP.Utilities.ConfigRootKeys.PowerShell module may not yet
# carry OSSForksRootConfigRootKey (added in the in-flight sprint source but not yet
# promoted to powershellget-stable). Remove this guard once that module ships and
# the key is confirmed present in the installed module.
if ($global:configRootKeys.ContainsKey('OSSForksRootConfigRootKey')) {
  $global:EnvVars[$global:configRootKeys['OSSForksRootConfigRootKey']] = $global:Settings[$global:configRootKeys['OSSForksRootConfigRootKey']]
}

# Secret values and API keys are deliberately not projected into the process
# environment. Callers resolve them by canonical setting name through Get-PVal
# and Get-SecretATAP. This includes Dropbox access tokens, Jenkins API tokens,
# Bitwarden passwords, Vault tokens, ChatGPT/Perplexity keys, and Hydrus keys.

function Set-EnvironmentVariablesProcess {
  Write-PSFMessage -Level Debug -Message ("setting $(($global:envVars.keys).count) environment variables in global_EnvironmentVariables.ps1")

  $global:envVars.keys | ForEach-Object { $key = $_
    [System.Environment]::SetEnvironmentVariable($key, $global:envVars[$key], 'Process')
  }

}

