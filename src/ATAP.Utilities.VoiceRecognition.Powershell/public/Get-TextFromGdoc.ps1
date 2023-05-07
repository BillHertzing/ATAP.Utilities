function Get-TextFromGdoc
 {
  param (
   # OptionalParameters
   $credentialPath
   , $clientID
   , $clientSecret
   , $googleDriveFilePath
  )

# First, install the Google API client library for PowerShell if it has not yet been installed
if ( -not $(Get-Package -Name 'Google.Apis.Drive.v3')) {
  Install-Package Google.Apis.Drive.v3 -ProviderName NuGet -SkipDependencies
}

# ensure it is in filesystem location from which the .dll can be loaded
$packageSourceDirectory = Split-Path -Path $(Get-Package -Name 'Google.Apis.Drive.v3').source -Parent
# ToDo: validate the .dll exists and can be read

# Get the location of the .Net (desktop) DLL
$DLLPath = join-path $packageSourceDirectory 'lib' 'net45','Google.Apis.Drive.v3.dll'

# Load the types from the packages .dlls
Add-Type -Path $DLLPath

# Authenticate with Google Drive API
$credential = Get-GoogleOAuth2Credential -ClientID $clientID -ClientSecret $clientSecret -RedirectUri "urn:ietf:wg:oauth:2.0:oob" -CredentialPath $credentialPath

# Replace "file_id" with the ID of the Google Document you want to access
$file_id = Get-GoogleFileIDFromGoogleDriveFilename -path $googleDriveFilePath

# Call the Google Drive API to download the document as a text file
$service = New-Object Google.Apis.Drive.v3.DriveService
$service.HttpClient.DefaultRequestHeaders.Authorization = New-Object System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", $credential.Token.AccessToken)

$request = $service.Files.Export($file_id, "text/plain")
$stream = New-Object System.IO.MemoryStream
$request.MediaDownloader.ProgressChanged.Add({
    param($progress)
    # ToDo: report progress to somtheing more centralized then stdout
    Write-Host "Download progress: $($progress.BytesDownloaded) bytes downloaded out of $($progress.TotalBytes)"
})
$request.Download($stream)

# Create a stream reader for the downloaded text file
$text_stream = New-Object System.IO.StreamReader($stream)

# return the text as a string to the calling function
$text_stream.ReadToEnd()
}

function Get-GoogleFileIDFromGoogleDriveFilename {
  param (
   $path
   ,[pscredential] $credentialPath
  )

# Call the Google Drive API to search for the document by name
$service = New-Object Google.Apis.Drive.v3.DriveService
$service.HttpClient.DefaultRequestHeaders.Authorization = New-Object System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", $credential.Token.AccessToken)

$query = "mimeType='application/vnd.google-apps.document' and name='$file_path'"
$result = $service.Files.List($query).Execute()

if ($result.Files.Count -eq 0) {
    Write-Error "No Google Document found with path $file_path"
}
else {
    # Print the ID of the first document found (assuming there's only one)
    Write-Host "Document ID: $($result.Files[0].Id)"
}
}
