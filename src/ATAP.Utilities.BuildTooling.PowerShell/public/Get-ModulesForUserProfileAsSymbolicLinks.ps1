# ToDo: The following is a 'cheat' for a developer who wants to work on Powershell modules, whose SCM repository is reachable via SymbolicLink
#  ToDo: Usually, an ATAP Powershell package is restored from the NuGet Feed sources, then ipmo'd
#  This Function creates symbolic links from the user's Powershell module directory (target) directly to a local github repository (path)
Function Get-ModulesForUserProfileAsSymbolicLinks {
  #region FunctionParameters
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
    # ToDo: Parameter set to suport LiteralPath
    [alias('source')]
    [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)]
    [ValidateNotNullOrEmpty()][String] $profileModulePath
    , [alias('target')]
    [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)]
    [ValidateNotNullOrEmpty()][String] $targetModulePath
    , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNullOrEmpty()][switch] $Force
  )
  #endregion FunctionParameters
  #region FunctionBeginBlock
  ########################################
  BEGIN {
    Write-Verbose -Message "Starting $($MyInvocation.Mycommand)"

    # default values for settings
    $parameters = @{
      ProfileModulePath    = ''
      TargetModulePath     = ''
      Force                = $false
      UserModulePath       = Join-Path ([Environment]::GetFolderPath('MyDocuments')) '\PowerShell\Modules\'
      LinksToCreatePattern = '(public|private|\.*ps[md]*1)'
    }

    # Things to be initialized after settings are processed
    if ($profileModulePath) { $Settings.profileModulePath = $profileModulePath }
    if ($targetModulePath) { $Settings.targetModulePath = $targetModulePath }
    if ($Force) { $Settings.Force = $Force }
  }
  #endregion FunctionBeginBlock
  #region FunctionProcessBlock
  ########################################
  PROCESS {
    $modpath = Join-Path $settings.userModulePath $profileModulePath
    if (-not (Test-Path $modpath)) { New-Item -Path $modpath -ItemType Directory }
    Set-Location -Path $modPath
    Get-ChildItem $targetModulePath | Where-Object { $_.name -match $Settings.LinksToCreatePattern } |
    ForEach-Object { if (-not (Test-Path $_.name)) {
        # If it doesn't exist, it needs to be created, but only administrator's can create symbolic links
        if ($global:settings[$global:configRootKeys['IsElevatedConfigRootKey']]) {
          if ($PSCmdlet.ShouldProcess(@($_.name, $_.fullname), 'New-Item -ItemType SymbolicLink -Path $_.name -Target $_.fullname > $null')) {
            New-Item -ItemType SymbolicLink -Path $_.name -Target $_.fullname > $null
          }
        }
        else {
          Write-Verbose "$_.name needs to be created as a SymbolicLink, but this user is not an administrator"
          Write-Debug "$_.name needs to be created as a SymbolicLink, but this user is not an administrator"
        }
      }
      else {
        # only recreate it if the -Force argument is set
        if ($settings.Force -and $global:settings[$global:configRootKeys['IsElevatedConfigRootKey']]) {
          if ($PSCmdlet.ShouldProcess(@($_.name, $_.fullname), 'Force: Remove and recreate New-Item -ItemType SymbolicLink -Path $_.name -Target $_.fullname > $null')) {
            Remove-Item $_.name -ErrorAction SilentlyContinue -WhatIf -Verbose # ToDo: remove whatif and verbose after debugging
            New-Item -ItemType SymbolicLink -Path $_.name -Target $_.fullname > $null
          }
        }
      }
    }
  }
  #endregion FunctionProcessBlock
  #region FunctionEndBlock
  ########################################
  END {
    Write-Verbose -Message "Ending $($MyInvocation.Mycommand)"
  }
}
