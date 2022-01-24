# ToDo: The following is a 'cheat' for a developer who wants to work on Powershell modules, whose SCM repository is reachable via SymbolicLink
#  ToDo: Usually, an ATAP Powershell package is restored from the NuGet Feed sources, then ipmo'd
#  This Function creates symbolic links from the user's Powershell module directory (target) directly to a local github repository (path)
# However, Autoload fails if the .psd1 file is a symbolic link, so, the .psd1 file must be copied instead of symlinked
Function Get-ModuleAsSymbolicLink {
  #region FunctionParameters
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
    # ToDo: Parameter set to suport LiteralPath
    [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)]
    [ValidateNotNullOrEmpty()][String] $Name
    , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)]
    [ValidateNotNullOrEmpty()][String] $Version
    , [alias('source')]
    [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)]
    [ValidateNotNullOrEmpty()][String] $sourcePath
    , [alias('target')]
    [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)]
    [ValidateNotNullOrEmpty()][String] $targetPath
    , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNullOrEmpty()][switch] $Force = $false
  )
  #endregion FunctionParameters
  #region FunctionBeginBlock
  ########################################
  BEGIN {
    Write-Verbose -Message "Starting $($MyInvocation.Mycommand)"

    # default values for parameters
    $parameters = @{
      Name    = ''
      Version    = ''
      SourcePath     = ''
      TargetPath     = Join-Path ([Environment]::GetFolderPath('MyDocuments')) '\PowerShell\Modules\'
      Force                = $false
      LinksToCreatePattern = '(public|private|\.*ps[m]*1)'
      FilesToCopyPattern = '\.psd1'
    }

    # Things to be initialized after parameters are processed
    if ($Name) { $parameters.Name = $Name }
    if ($Version) { $parameters.Version = $Version }
    if ($TargetPath) { $parameters.TargetPath = $TargetPath }
    if ($Force) { $parameters.Force = $Force }
  }
  #endregion FunctionBeginBlock
  #region FunctionProcessBlock
  ########################################
  PROCESS {
    # ToDo: validate sourcePath and targetpath
    $moduleTargetPath = Join-Path $parameters.TargetPath $parameters.Name
    if (-not (Test-Path $moduleTargetPath)) { New-Item -Path $moduleTargetPath -ItemType Directory }
    $moduleTargetPath = Join-Path $moduleTargetPath $parameters.Version
    if (-not (Test-Path $moduleTargetPath)) { New-Item -Path $moduleTargetPath -ItemType Directory }
    Set-Location -Path $moduleTargetPath
    Get-ChildItem $SourcePath | Where-Object { $_.name -match $parameters.LinksToCreatePattern } |
    ForEach-Object { if (-not (Test-Path $_.name)) {
        # If it doesn't exist, it needs to be created, but only administrator's can create symbolic links
        if ($global:settings[$global:configRootKeys['IsElevatedConfigRootKey']]) {
          if ($PSCmdlet.ShouldProcess(@($_.name, $_.fullname), 'New-Item -ItemType SymbolicLink -Path $_.name -Target $_.fullname > $null')) {
            New-Item -ItemType SymbolicLink -Path $(Join-path $moduleTargetPath $_.name) -Target $_.fullname > $null
          }
        }
        else {
          Write-Verbose "$_.name needs to be created as a SymbolicLink, but this user is not an administrator"
          Write-Debug "$_.name needs to be created as a SymbolicLink, but this user is not an administrator"
        }
      }
      else {
        # only recreate it if the -Force argument is set
        if ($parameters.Force -and $global:settings[$global:configRootKeys['IsElevatedConfigRootKey']]) {
          if ($PSCmdlet.ShouldProcess(@($_.name, $_.fullname), 'Force: Remove and recreate New-Item -ItemType SymbolicLink -Path $(Join-path $moduleTargetPath $_.name) -Target $_.fullname > $null')) {
            Remove-Item $(Join-path $moduleTargetPath $_.name) -ErrorAction SilentlyContinue
            New-Item -ItemType SymbolicLink -Path $(Join-path $moduleTargetPath $_.name) -Target $_.fullname > $null
          }
        }
      }
    }
    # Copy the .psd1 file, don't SymbolicLink it
    Get-ChildItem $SourcePath | Where-Object { $_.name -match $parameters.FilesToCopyPattern } |
    ForEach-Object {
      if (-not (Test-Path $_.name)) {
        # If it doesn't exist, it needs to be copied
        if ($PSCmdlet.ShouldProcess(@($(Join-path $moduleTargetPath $_.name), $_.fullname), 'Would do Copy-Item $_.fullname -Destination $_.name')) {
          Copy-Item $_.fullname -Destination $(Join-path $moduleTargetPath $_.name) > $null
        }
      } else {
        # if it does exists, use the -Force parameter
        if ($PSCmdlet.ShouldProcess(@($(Join-path $moduleTargetPath $_.name), $_.fullname), 'Would do Copy-Item $_.fullname -Destination $(Join-path $moduleTargetPath $_.name) -Force')) {
            Copy-Item $_.fullname -Destination $(Join-path $moduleTargetPath $_.name) -Force> $null
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
