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
