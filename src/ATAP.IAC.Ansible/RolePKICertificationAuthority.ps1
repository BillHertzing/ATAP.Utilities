# The script that creates the PKI Certification Authority Role
param(
  [string] $ymlGenericTemplate
  , [string] $roleDirectoryPath
  , [string] $roleName
  , [string[]] $roleSubdirectoryNames

)

[System.Text.StringBuilder]$sbAddedParameters = [System.Text.StringBuilder]::new()

$addedParametersScriptblock = {
  param(
    [string[]]$addedParameters
  )
  if ($addedParameters) {
    [void]$sbAddedParameters.Append('Params: "')
    foreach ($ap in $addedParameters) { [void]$sbAddedParameters.Append("/$ap ") }
    [void]$sbAddedParameters.Append('"')
    $sbAddedParameters.ToString()
    [void]$sbAddedParameters.Clear()
  }
}

function ContentsTask {
  [System.Text.StringBuilder]$sb = [System.Text.StringBuilder]::new()
  [void]$sb.Append(
    @"

  # ToDo Validate the OpenSSL.Light package is loaded and on the $PATH ("C:\Program Files\OpenSSL\bin")
  # ToDo Validate the ATAP.Utilities.Security.Powershell module is available
- name: Create the directory structure for a PKI Certificate Authority
  ansible.windows.win_file:
    path: {{  $global:configRootKeys['SecureCertificatesBasePathConfigRootKey'] }}
    state: directory

- name: Copy the various Certificate Configuration Files
  win_copy:
    src: "{{ ServiceAccountPowershellDesktopProfileSourcePath }}"
    dest: C:\Users\{{ServiceAccountName}}\WindowsPowershell\profile.ps1

- name: Install or Uninstall the ATAP PKIInfrastructure script using chocolatey
  win_dsc:
    resource_name: cChocoPackageInstaller
    Name: "{{ JenkinsName }}"
    Version: "{{ JenkinsVersion }}"
    Ensure: "{{ 'Absent' if (action_type == 'Uninstall') else 'Present'}}"
    $(. $addedParametersScriptblock)

- name: Create a CA with the organizations informationm


# Deploy the root CA with this script, or a separate one?



"@)
  $sb.ToString()
}

# These will be the global settings as setup for WSindowsHost that creates the Ansible Directory structure. It doesnt take into account any machine that has ProgramFiles anyplace other than C: It doesnt' account for varying locaiton sof the
function ContentsVars {
  $variablesToSet = @(
    , 'SECURE_CLOUD_BASE_PATHConfigRootKey'
    , 'OPENSSL_HOMEConfigRootKey'
    , 'OPENSSL_CONFConfigRootKey'
    , 'RANDFILEConfigRootKey'
    , 'SecureCertificatesBasePathConfigRootKey'
    , 'SecureCertificatesEncryptionPassPhraseFilesPathConfigRootKey'
    , 'SecureCertificatesEncryptedKeysPathConfigRootKey'
    , 'SecureCertificatesCertificateRequestsPathConfigRootKey'
    , 'SecureCertificatesCertificatesPathConfigRootKey'
    , 'SecureCertificatesDataEncryptionCertificatesPathConfigRootKey'
    , 'SecureCertificatesOpenSSLConfigsPathConfigRootKey'
    , 'SecureCertificatesCrossReferenceFilenameConfigRootKey'
    , 'SecureCertificatesSigningCertificatesCertificatesIssuedDBRelativePathConfigRootKey'
    , 'SecureCertificatesCAPassPhraseFileBaseFileNameConfigRootKey'
    , 'SecureCertificatesCAEncryptedPrivateKeyBaseFileNameConfigRootKey'
    , 'SecureCertificatesCACertificateBaseFileNameConfigRootKey'
    , 'SecureCertificatesSSLServerPassPhraseFileBaseFileNameConfigRootKey'
    , 'SecureCertificatesSSLServerEncryptedPrivateKeyBaseFileNameConfigRootKey'
    , 'SecureCertificatesSSLServerCertificateRequestBaseFileNameConfigRootKey'
    , 'SecureCertificatesSSLServerCertificateBaseFileNameConfigRootKey'
    , 'SecureCertificatesCodeSigningPassPhraseFileBaseFileNameConfigRootKey'
    , 'SecureCertificatesCodeSigningEncryptedPrivateKeyBaseFileNameConfigRootKey'
    , 'SecureCertificatesCodeSigningCertificateRequestBaseFileNameConfigRootKey'
    , 'SecureCertificatesCodeSigningCertificateBaseFileNameConfigRootKey'
  )
  [System.Text.StringBuilder]$sb = [System.Text.StringBuilder]::new()
  for ($index = 0; $index -lt $variablesToSet.count; $index++) {
    [void]$sb.AppendLine("  - $global:configRootKeys['$variablesToSet[$index]'] = $global:settings[$global:configRootKeys['$variablesToSet[$index]']]'")
  }
  $sb.ToString()
}

function ContentsMeta {
  @'
  dependencies:
  # - role: RoleChocolateyInstallAndConfigure
'@
}

# exclude these role subdirectores
$excludedSubDirectoriesPattern = '^handlers | defaults | files | templates | library | module_utils | lookup_plugins | scripts$'
$subDirectoriesToBuild = $roleSubdirectoryNames | Where-Object { $_ -notmatch $excludedSubDirectoriesPattern }  # minus the excluded ones
for ($index = 0; $index -lt $subDirectoriesToBuild.count; $index++) {
  $roleSubdirectoryName = $subDirectoriesToBuild[$index]
  $roleSubdirectoryPath = $(Join-Path $roleDirectoryPath $roleSubdirectoryName)
  New-Item -ItemType Directory -Path $roleSubdirectoryPath -ErrorAction SilentlyContinue >$null
  $ymlContents = $($ymlGenericTemplate -replace '\{ 1 }', $roleSubdirectoryName ) -replace '\ { 2 }', $roleName
  switch -regex ($roleSubdirectoryName) {
    '^tasks$' {
      $ymlContents += ContentsTask
      Set-Content -Path "$roleSubdirectoryPath\main.yml" -Value $ymlContents
    }
    '^vars$' {
      $ymlContents += ContentsVars
      Set-Content -Path "$roleSubdirectoryPath\main.yml" -Value $ymlContents
    }
    '^meta$' {
      $ymlContents += ContentsMeta
      Set-Content -Path "$roleSubdirectoryPath\main.yml" -Value $ymlContents
    }
    default {
      Write-PSFMessage -Level Error -Message " role $roleName has no template to create any files in the $roleSubdirectoryName subDirectory"
      break
    }
  }
}

 # name of JRE package should be a parameter
 # version of JRE package should be a parameter
