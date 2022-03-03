Function Get-DropBoxFolderCursor {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
    # ToDo: Parameter set to suport LiteralPath
    [parameter(Mandatory = $false, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)] $path = $global:Settings[$global:configRootKeys['DropBoxBasePathConfigRootKey']]
    , [parameter(Mandatory = $false, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)] [string] $DropBoxPathPrefix = $global:Settings[$global:configRootKeys['DropBoxBasePathConfigRootKey']]
    , [parameter(Mandatory = $false, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)] [switch] $Recursive
    , [parameter(Mandatory = $false, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)] [string] $Include_deleted = $true
    , [parameter(Mandatory = $false, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)] [string] $URIForGetLatestFolderCursor = 'https://api.dropboxapi.com/2/files/list_folder/get_latest_cursor'

  )
  BEGIN {
    Write-Verbose -Message "Starting $($MyInvocation.Mycommand)"

    # default values for parameters
    $parameters = @{
      # ToDo: Like ConfigurationRoot, these should be env variable then argument
      DropBoxPathPrefix           = $global:Settings[$global:configRootKeys['DropBoxBasePathConfigRootKey']]
      Recursive                   = $false
      Include_deleted             = $true
      URIForGetLatestFolderCursor = 'https://api.dropboxapi.com/2/files/list_folder/get_latest_cursor'
    }

    # Things to be initialized after parameters are processed
    if ($DropBoxPathPrefix) { $parameters.DropBoxPathPrefix = $DropBoxPathPrefix }
    if ($Recursive) { $parameters.Recursive = $Recursive }
    if ($Include_deleted) { $parameters.Include_deleted = $Include_deleted }
    if ($URIForGetLatestFolderCursor) { $parameters.URIForGetLatestFolderCursor = $URIForGetLatestFolderCursor }

    # The Dropbox Access Token is stored in the environment as it is a secret
    $authorization = 'Bearer ' + $env:DropBoxAccessToken
    $headers = New-Object 'System.Collections.Generic.Dictionary[[String],[String]]'
    $headers.Add('Authorization', $authorization)
    $headers.Add('Content-Type', 'application/json')
  
  }

  PROCESS {
    # This is to get one folder cursor value for one string directoryName or DirInfo 
    $aPICallResult = ''
    # ToDo: If path is a single input (string or FileInfo), get the dropboxPath.
    $validatedPath = $(
      if ([string]::IsNullOrEmpty($path)) {
        $parameters.DropBoxPathPrefix
      }
      elseif ($path -is [string]) {
        $path
      }
      elseif ($path -is [System.IO.DirectoryInfo]) {
        $path.fullname
        continue
      }
      else {
        Write-Warning "Only Directories are supported. Skipping $path."
        continue
      }
    )
    # On windows, the '\' DirectorySeperator has to be escaped before it can be used in a pattern matching
    # this strips the DropBoxPrefix from the $validatedPath
    $dropboxPath = $validatedPath -replace [Regex]::Escape($parameters.DropBoxPathPrefix), '' 
    # The Windows directory seperaator has to be replaced with the *nix directory seperator before calling the dropbox api
    $dropboxPath = $dropboxPath -replace '\\', '/' 

    $Body = @{
      path                                = $dropboxPath
      recursive                           = [bool]$parameters.Recursive
      #include_media_info                  = $false
      include_deleted                     = [bool]$parameters.Include_deleted
      include_has_explicit_shared_members = $false
      include_mounted_folders             = $true
      include_non_downloadable_files      = $true
    }
    if ($PSCmdlet.ShouldProcess(($dropboxPath, $parameters.Recursive), "Getting list of folder cursors dropbox for $dropboxPath, recursive = $($parameters.Recursive))")) {
      try {
        # ToDo: add parameters for Proxy
        $aPICallResult = Invoke-RestMethod -Uri $parameters.URIForGetLatestFolderCursor -Method Post -Headers $headers -Body (ConvertTo-Json -InputObject $Body)  -Proxy 'http://127.0.0.1:8888' # for Fiddler capture
      }
      catch {
        $aPICallResultException = $_.Exception
        $aPICallResultExceptionMessage = $aPICallResultException.Message
        Throw $aPICallResultExceptionMessage
      }
      
      # $aPICallResult is a JSON object if there were no errors
      # $aPICallResult.cursor should be notblankAndNotNull
      if ($aPICallResult.cursor) {
        $cursor = $aPICallResult.cursor
        Write-Verbose "dropboxPath = $dropboxPath, cursor = $cursor"
      }
      else {
        # ToDo: No cursor returned?
      }
    }
    # return the cursor
    $cursor
  }
  END {
    Write-Verbose "Ending $($MyInvocation.Mycommand)"
  }
}
