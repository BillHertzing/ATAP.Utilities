

# from https://github.com/dmitrykamchatny/PSDropbox Dropbox.psm1 file

<#
.Synopsis
 Short description
.DESCRIPTION
 Long description
.EXAMPLE
 Example of how to use this cmdlet
.EXAMPLE
 Another example of how to use this cmdlet
#>
function Get-DropboxAccount {
  [CmdletBinding()]
  Param(
    # Dropbox API access token.
    [parameter(Mandatory, HelpMessage = 'Enter access token')]
    [string]$Token
  )

  Begin {
    $URI = 'https://api.dropboxapi.com/2/users/get_current_account'
    $Header = @{'Authorization' = "Bearer $Token" }
  }
  Process {
    try {
      $Result = Invoke-RestMethod -Uri $URI -ContentType 'application/json' -Method Post -Body 'null' -Headers $Header
      Write-Output $Result
    }
    catch {
      $ResultError = $_.Exception.Response.GetResponseStream()
      Get-DropboxError -Result $ResultError
    }
  }
  End {}
}
