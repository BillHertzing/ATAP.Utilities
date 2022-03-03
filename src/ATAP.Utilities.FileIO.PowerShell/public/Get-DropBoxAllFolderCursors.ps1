Function Get-DropBoxAllFolderCursors {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
    # ToDo: Parameter set to suport LiteralPath
    [parameter(Mandatory = $false, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)] [string] $RootPath = $global:Settings[$global:configRootKeys['DropBoxBasePathConfigRootKey']]
    , [parameter(Mandatory = $false, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)] [string] $FileStorage
    , [parameter(Mandatory = $false, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)] [int32] $Depth = 0
    , [parameter(Mandatory = $false, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)] [string] $ExcludePattern = 'c:\\dropbox\\(download|music|photos|videos)\\'
    , [parameter(Mandatory = $false, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)] [string] $DropBoxPathPrefix = $global:Settings[$global:configRootKeys['DropBoxBasePathConfigRootKey']]
    , [parameter(Mandatory = $false, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)] [string] $URIForGetLatestFolderCursor = 'https://api.dropboxapi.com/2/files/list_folder/get_latest_cursor'
    , [parameter(Mandatory = $false, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)] [string] $Include_deleted = $true
    #, [parameter(Mandatory = $false, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)] [string] $sharedLinkSettings =  @{requested_visibility = 'public'; audience = 'public'; access = 'viewer' }

  )
  BEGIN {
    Write-Verbose -Message "Starting $($MyInvocation.Mycommand)"

    # default values for parameters
    $parameters = @{
      # ToDo: Like ConfigurationRoot, these should be env variable then argument
      RootPath                    = $global:Settings[$global:configRootKeys['DropBoxBasePathConfigRootKey']]
      FileStorage                 =  Join-Path  ([System.IO.DriveInfo]::GetDrives() | Where-Object { $_.VolumeLabel -eq "Google Drive" } | Select-Object -ExpandProperty 'Name') 'My Drive' 'DatedDropboxCursors.json'
      Depth                       = 2
      ExcludePattern              = 'c:\\dropbox\\(download|music|photos|videos)\\'
      DropBoxPathPrefix           = $global:Settings[$global:configRootKeys['DropBoxBasePathConfigRootKey']]
      URIForGetLatestFolderCursor = 'https://api.dropboxapi.com/2/files/list_folder/get_latest_cursor'
      Include_deleted             = $true
    }

    # Things to be initialized after parameters are processed
    if ($RootPath) { $parameters.RootPath = $RootPath }
    if ($FileStorage) { $parameters.FileStorage = $FileStorage }
    if ($excludePattern) { $parameters.excludePattern = $excludePattern }
    if ($Depth) { $parameters.Depth = $Depth }
    if ($DropBoxPathPrefix) { $parameters.DropBoxPathPrefix = $DropBoxPathPrefix }
    if ($URIForGetLatestFolderCursor) { $parameters.URIForGetLatestFolderCursor = $URIForGetLatestFolderCursor }
    if ($Include_deleted) { $parameters.Include_deleted = $Include_deleted }

    # if the file needed for storage does not exist, create it
    if (!(resolve-path -path ($parameters.FileStorage) -ErrorAction 'SilentlyContinue')) {New-Item -Name ($parameters.FileStorage) -ItemType File}
  }

  PROCESS {
  }
  END {
    $datestr = Get-Date -AsUTC -Format 'yyyy/MM/dd:HH.mm'
    $datedcursorHash = @{$datestr = @{} }
    if ($PSCmdlet.ShouldProcess(($parameters.RootPath, $parameters.Recursive), "Feteching all dropbox folder cursors rooted at $parameters.RootPath, depth = $($parameters.Depth))")) {
      Get-ChildItem $parameters.RootPath -d $parameters.Depth | Where-Object {
        (($_.fullname -notmatch $parameters.excludePattern) -and $_.PsIsContainer)
      } | ForEach-Object { $fullname = $_.fullname
        $cursor = Get-DropBoxFolderCursor -recursive -path $fullname
        $datedcursorHash[$datestr][$fullname] = $cursor
      }
      # Get the old contents of the FileStorage
      $contents = Get-Content $parameters.FileStorage | ConvertFrom-Json -AsHashtable
      # Add the new content,
      $contents += $datedcursorHash
      # write all back out to the file storage
      $contents | ConvertTo-Json | set-content -path $parameters.FileStorage

    }
    Write-Verbose "Ending $($MyInvocation.Mycommand)"
  }
}
