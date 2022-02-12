Function Get-DropboxSharingLink {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
    # ToDo: Parameter set to suport LiteralPath
    [parameter(Mandatory = $true, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)] $path
    , [parameter(Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)] [string] $DropBoxPathPrefix = 'C:\\DropBox'
    , [parameter(Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)] [string] $URIForListSharedLinks = 'https://api.dropboxapi.com/2/sharing/list_shared_links'
    , [parameter(Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)] [string] $URIForCreateSharedLinks = 'https://api.dropboxapi.com/2/sharing/create_shared_link_with_settings'
    , [parameter(Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)] [string] $sharedLinkSettings = @{requested_visibility = 'public'; audience = 'public'; access = 'viewer' }
    , [parameter(Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)] [string] $proxyAddress = 'http://127.0.0.1:8888'
    , [parameter(Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)] [switch] $Proxy = $false

  )
  BEGIN {
    Write-Verbose -Message "Starting $($MyInvocation.Mycommand)"

    # default values for parameters
    $parameters = @{
      Path                    = @()
      # ToDo: Like ConfigurationRoot, these should be env variable then argument
      DropBoxPathPrefix       = 'C:\\DropBox'
      URIForListSharedLinks   = 'https://api.dropboxapi.com/2/sharing/list_shared_links'
      URIForCreateSharedLinks = 'https://api.dropboxapi.com/2/sharing/create_shared_link_with_settings'
      SharedLinkSettings      = @{requested_visibility = 'public'; audience = 'public'; access = 'viewer' }
      ProxyString             = if ($Proxy) { "-Proxy '$proxyAddress'" } else { '' }
    }

    # Things to be initialized after parameters are processed
    if ($DropBoxPathPrefix) { $parameters.DropBoxPathPrefix = $DropBoxPathPrefix }
    if ($URIForListSharedLinks) { $parameters.URIForListSharedLinks = $URIForListSharedLinks }
    if ($URIForCreateSharedLinks) { $parameters.URIForCreateSharedLinks = $URIForCreateSharedLinks }
    if ($SharedLinkSettings) { $parameters.SharedLinkSettings = $SharedLinkSettings }

    # The Dropbox Access Token is stored in the environment as it is a secret
    $authorization = 'Bearer ' + $env:DropBoxAccessToken
    $headers = New-Object 'System.Collections.Generic.Dictionary[[String],[String]]'
    $headers.Add('Authorization', $authorization)
    $headers.Add('Content-Type', 'application/json')
    $debugpreference = 'Continue' # REMOVE BEFORE PRODUCTION
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
    $dropboxPath = $(
      if ($path -is [string]) {
        $path
      }
      elseif ($path -is [System.IO.DirectoryInfo]) {
        Write-Warning "Get-FileMetaData - Directories are not supported. Skipping $path."
        continue
      }
      elseif ($path -is [System.IO.FileInfo]) {
        $path.fullname
      }
      else {
        Write-Warning "Only files are supported. Skipping $path."
        continue
      }
    )
    $dropboxPath = $dropboxPath -replace $parameters.DropBoxPathPrefix, '' -replace '\\', '/'
    $Body = @{
      path = $dropboxPath
    }
    if ($PSCmdlet.ShouldProcess($dropboxPath, 'Create sharing link')) {
      try {
        # Is there already a sharing link to the file at $dropboxPath?
        $command = "Invoke-RestMethod -Uri $parameters.URIForListSharedLinks -Method Post -Headers $headers -Body (ConvertTo-Json -InputObject $Body) $paramters.ProxyString"
        # ToDo: add parameters for Proxy
         $result = Invoke-RestMethod -Uri $parameters.URIForListSharedLinks -Method Post -Headers $headers -Body (ConvertTo-Json -InputObject $Body) -Proxy 'http://127.0.0.1:8888' # for Fiddler capture
        #$result = Invoke-Command $command
      }
      catch {
        $resultException = $_.Exception
        $ResultExceptionMessage = $resultException.Message
        Write-Error $ResultExceptionMessage
      }
      # $result is a JSON object if there were no errors
      # $result.links is non-zero if a shared link already exists
      if ($result.links.Length) {
        $sharingLink = $result.links[0].url -replace 'dl=0', 'raw=1'
        Write-Verbose "path = {$dropboxPath}, sharingLink = {$sharingLink}"
      }
      else {
        # A shared link does not yet exist, so ask Dropbox to create and return one
        try {
          $Body = @{
            path     = $dropboxPath
            settings = $parameters.SharedLinkSettings
          }
          # ToDo: add parameters for Proxy

          $result = Invoke-RestMethod -Uri $parameters.URIForCreateSharedLinks -Method Post -Headers $headers -Body (ConvertTo-Json -InputObject $Body) -Proxy 'http://127.0.0.1:8888' # for Fiddler capture
          $sharingLink = $result.url -replace 'dl=0', 'raw=1'
          Write-Verbose "path = {$dropboxPath}, sharingLink = {$sharingLink}"
        }
        catch {
          $resultException = $_.Exception
           $ResultExceptionMessage = $resultException.Message
          # $dmsg = $_.Exception.InnerException.Message
          Write-Error $ResultExceptionMessage
        }
      }
    }
    $sharingLink

  }
  END {
    Write-Verbose "Ending $($MyInvocation.Mycommand)"
  }
}
