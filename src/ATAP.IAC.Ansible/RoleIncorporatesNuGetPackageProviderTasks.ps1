
param(
    [string] $ymlGenericTemplate
  , [string] $directoryPath
  , [string] $dSCConfigurationName
  , [string] $dSCConfigurationFilename
  , [string] $dSCConfigurationSourcePath
  , [string] $dSCConfigurationAnsibleSourcePath
  , [string] $dSCConfigurationTargetDestinationDirectory
)

function Contents {

return @"
- name: show the ansible_user
  debug:
    var: ansible_user

- name: Copy DSC configuration script to target system
  win_copy:
    src: $dSCConfigurationAnsibleSourcePath
    dest:  $dSCConfigurationTargetDestinationDirectory

- name: Apply DSC configuration
  ansible.windows.win_powershell:
    executable: pwsh.exe
    script:
      #Invoke-DscResource -Path $dSCConfigurationTargetDestinationDirectory -Name $dSCConfigurationName -Method Set -Verbose
    #   $commonParams = @{
    #     Name = 'WindowsFeature'
    #     Property = @{ Name = 'cChocoInstaller'; InstallDir = 'C:/temp/chocotesting'}
    #     ModuleName = 'cChoco'
    #     Verbose = $true
    # }
      Invoke-DscResource -Name 'cChoco' -Method Test -Property @{
          Name   = 'cChocoInstaller'
          InstallDir = 'C:/temp/chocotesting'
          Ensure = 'Present'
          #Value  = 'Desired State Configuration'
          Target = 'Process'
      }
    # args:
    #   chdir: .
"@
}

  $ymlContents= $ymlGenericTemplate -replace '\{2}', $dSCConfigurationName
  $ymlContents += Contents
  Set-Content -Path $(Join-Path $directoryPath "main.yml") -Value $ymlContents


