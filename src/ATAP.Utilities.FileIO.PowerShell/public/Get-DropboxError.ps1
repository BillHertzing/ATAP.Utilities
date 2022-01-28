# from https://github.com/dmitrykamchatny/PSDropbox Dropbox.psm1 file

<#
.SYNOPSIS
    Get returned Dropbox Error
.DESCRIPTION
    Currently the Invoke-RestMethod command error response doesn't show the actual response received from Dropbox.

  The catch code block includes the line "$ResultError = $_.Exception.Response.GetResponseStream()" to get the response stream then passes it to this cmdlet to read.
  .EXAMPLE
  Get-DropboxError -Result $ResultError
  #>
function Get-DropboxError {
  [cmdletbinding()]
  param(
    # Invoke-RestMethod error stream.
    $Result
  )

  begin {
    $Reader = New-Object System.IO.StreamReader($Result)
  }
  process {
    $Reader.BaseStream.Position = 0
    $Reader.DiscardBufferedData()
    $DropboxError = ($Reader.ReadToEnd())
  }
  end {
    Write-Output $DropboxError
  }
}
