Function Get-DropBoxFolderList {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
    # ToDo: Parameter set to suport LiteralPath
    [parameter(Mandatory = $true, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)] $path
    , [parameter(Mandatory = $false, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)] [string] $DropBoxPathPrefix = 'C:\\DropBox'
    , [parameter(Mandatory = $false, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)] [string] $URIForListFolder = 'https://api.dropboxapi.com/2/files/list_folder'
    , [parameter(Mandatory = $false, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)] [string] $URIForListFolderContinue = 'https://api.dropboxapi.com/2/files/list_folder/continue'
    , [parameter(Mandatory = $false, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)] [string] $Include_deleted = $false
    , [parameter(Mandatory = $false, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)] [string] $LimitPerQuery = 1000
    , [parameter(Mandatory = $false, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)] [string] $MaxLimit = 2000
    #, [parameter(Mandatory = $false, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)] [string] $sharedLinkSettings =  @{requested_visibility = 'public'; audience = 'public'; access = 'viewer' }

  )
  BEGIN {
    Write-Verbose -Message "Starting $($MyInvocation.Mycommand)"

    # default values for parameters
    $parameters = @{
      # ToDo: Like ConfigurationRoot, these should be env variable then argument
      DropBoxPathPrefix        = 'C:\\DropBox'
      URIForListFolder         = 'https://api.dropboxapi.com/2/files/list_folder'
      URIForListFolderContinue = 'https://api.dropboxapi.com/2/files/list_folder/continue'
      Include_deleted          = $false
      LimitPerQuery            = 1000
      MaxLimit                 = 2000
    }

    # Things to be initialized after parameters are processed
    if ($DropBoxPathPrefix) { $parameters.DropBoxPathPrefix = $DropBoxPathPrefix }
    if ($URIForListSharedLinks) { $parameters.URIForListSharedLinks = $URIForListSharedLinks }
    if ($URIForListFolderContinue) { $parameters.URIForListFolderContinue = $URIForListFolderContinue }
    if ($Include_deleted) { $parameters.Include_deleted = $Include_deleted }
    if ($LimitPerQuery) { $parameters.LimitPerQuery = $LimitPerQuery }
    if ($MaxLimit) { $parameters.MaxLimit = $MaxLimit }

    # The Dropbox Access Token is stored in the environment as it is a secret
    $authorization = 'Bearer ' + $env:DropBoxAccessToken
    $headers = New-Object 'System.Collections.Generic.Dictionary[[String],[String]]'
    $headers.Add('Authorization', $authorization)
    $headers.Add('Content-Type', 'application/json')
  }

  PROCESS {
    # ToDo: If path is a single input (string or FileInfo), get the link.
    # ToDo: If path is a collection (strings or FileInfos), get a batch of links
    # ToDo: If path is from pipeline (string or FileInfo), accumulate a batch and get a batch of links
    # ToDo: If path is from pipeline (collection of string or collection of FileInfo) accumulate a batch and get a batch of links
    # This is to get one link for one string filename
    $result = ''
    $sharingLink = ''
    # ToDo: If path is a single input (string or FileInfo), get the dropboxPath.
    $validatedPath = $(
      if ($path -is [string]) {
        $path
      }
      elseif ($path -is [System.IO.DirectoryInfo]) {
        $path.fullname
        continue
      }
      elseif ($path -is [System.IO.FileInfo]) {
        Write-Warning "Get-DropBoxFolderList - Files are not supported. Skipping $path."
      }
      else {
        Write-Warning "Only Directories are supported. Skipping $path."
        continue
      }
    )
    Write-Host
    $dropboxPath = $validatedPath -replace $parameters.DropBoxPathPrefix, '' -replace '\\', '/'
    $Body = @{
      path                                = $dropboxPath
      recursive                           = $true
      include_deleted                     = [bool]$parameters.Include_deleted
      limit                               = [int]$parameters.LimitPerQuery #100
      include_has_explicit_shared_members = $false
      include_mounted_folders             = $true
      include_non_downloadable_files      = $true
    }
    $progressLoopCount = 0
    if ($PSCmdlet.ShouldProcess($dropboxPath, 'Getting initial folder list from dropbox for <target>')) {
      Write-Progress -Activity 'Fetching Initial Folder List' -Status 'Waiting...' -PercentComplete $progressLoopCount
      try {
        # ToDo: add parameters for Proxy
        $result = Invoke-RestMethod -Uri $parameters.URIForListFolder -Method Post -Headers $headers -Body (ConvertTo-Json -InputObject $Body) # -Proxy 'http://127.0.0.1:8888' # for Fiddler capture
      }
      catch {
        $resultException = $_.Exception
        $ResultExceptionMessage = $resultException.Message #$ResultError = $resultException.Response.GetResponseStream()
        Throw $ResultExceptionMessage # Get-DropboxError -Result $ResultError
      }
      $folderlist = @{}
      # $result is a JSON object if there were no errors
      # $result.entries is non-zero if the folder has anything
      if ($result.entries.Length) {
        $folderlist = $result.entries
        Write-Verbose "dropboxPath = {$dropboxPath}, folderlist = {$folderlist}"
      }
      else {
        # ToDo: empty folderlist?
      }
      # Loop as long as has_more in the results is true, and the total retrieved has not exceeded maxlimit
      while ( $result.has_more -and $folderlist.count -lt $parameters.MaxLimit) {
        $progressLoopCount++
        Write-Progress -Activity 'Fetching Continued Folder List' -Status 'Waiting...' -PercentComplete $progressLoopCount
        $Body = @{
          cursor = $result.cursor
        }
        try {
          # ToDo: add parameters for Proxy
          $result = Invoke-RestMethod -Uri $parameters.URIForListFolderContinue -Method Post -Headers $headers -Body (ConvertTo-Json -InputObject $Body) # -Proxy 'http://127.0.0.1:8888' # for Fiddler capture
        }
        catch {
          $resultException = $_.Exception
          $ResultExceptionMessage = $resultException.Message #$ResultError = $resultException.Response.GetResponseStream()
          Throw $ResultExceptionMessage # Get-DropboxError -Result $ResultError
        }
        $folderlist += $result.entries
      }
    }
    Write-Progress -Activity 'Completed Fetching Folder List' -Status 'Completed' -PercentComplete 100

    $folderlist
  }
  END {
    Write-Verbose "Ending $($MyInvocation.Mycommand)"
  }
}
