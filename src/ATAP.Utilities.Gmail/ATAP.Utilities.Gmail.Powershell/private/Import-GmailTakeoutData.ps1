<#
.SYNOPSIS
Private function that processes Gmail Takeout data and imports it into SQL Server.

.DESCRIPTION
This private function handles the actual parsing and importing of Gmail data from an extracted
Google Takeout archive. It expects the standard Google Takeout folder structure and processes
the mbox files and metadata to populate the database tables.

.PARAMETER ConnectionString
The SQL Server connection string to use for database operations.

.PARAMETER TakeoutDataPath
Path to the directory containing the extracted Google Takeout data.

.OUTPUTS
System.Object
Returns a summary object with counts of imported items and any errors encountered.

.NOTES
AI assisted using Powershell.instructions.md as guidelines
This is a private function called by Load-GmailToDatabase.

.LINK
https://github.com/whertzing/ATAP.Utilities
#>
function Import-GmailTakeoutData {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$ConnectionString,

    [Parameter(Mandatory = $true, Position = 1)]
    [ValidateScript({ Test-Path $_ -PathType Container })]
    [string]$TakeoutDataPath
  )

  $fn = 'Import-GmailTakeoutData'
  $mn = 'ATAP.Utilities.Gmail.Powershell'

  Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Private function started'
  Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "TakeoutDataPath: $TakeoutDataPath"

  # Initialize result object
  $result = [PSCustomObject]@{
    StartTime        = Get-Date
    EndTime          = $null
    TotalMessages    = 0
    ImportedMessages = 0
    SkippedMessages  = 0
    Errors           = @()
    Success          = $false
  }

  try {
    # Create SQL connection
    $sqlConnection = New-Object System.Data.SqlClient.SqlConnection
    $sqlConnection.ConnectionString = $ConnectionString

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Opening SQL connection..."
    $sqlConnection.Open()
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "SQL connection opened successfully"

    # Find the Gmail data directory within the Takeout structure
    # Google Takeout typically extracts to: Takeout/Mail/
    $possiblePaths = @(
      (Join-Path $TakeoutDataPath 'Takeout\Mail')
      (Join-Path $TakeoutDataPath 'Mail')
      (Join-Path $TakeoutDataPath 'Takeout\Gmail')
      (Join-Path $TakeoutDataPath 'Gmail')
      $TakeoutDataPath
    )

    $gmailDataPath = $null
    foreach ($path in $possiblePaths) {
      if (Test-Path $path) {
        # Check if this directory contains mbox files or email data
        $mboxFiles = Get-ChildItem -Path $path -Filter '*.mbox' -Recurse -ErrorAction SilentlyContinue
        if ($mboxFiles -or (Test-Path (Join-Path $path 'All mail Including Spam and Trash.mbox'))) {
          $gmailDataPath = $path
          break
        }
      }
    }

    if (-not $gmailDataPath) {
      throw "Could not find Gmail data in the extracted Takeout. Searched paths: $($possiblePaths -join ', ')"
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Found Gmail data at: $gmailDataPath"

    # Find all mbox files
    $mboxFiles = Get-ChildItem -Path $gmailDataPath -Filter '*.mbox' -Recurse -ErrorAction SilentlyContinue

    if (-not $mboxFiles -or $mboxFiles.Count -eq 0) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message "No .mbox files found in: $gmailDataPath"
      # Try to find other data formats (JSON, etc.)
      $jsonFiles = Get-ChildItem -Path $gmailDataPath -Filter '*.json' -Recurse -ErrorAction SilentlyContinue
      if ($jsonFiles) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Found $($jsonFiles.Count) JSON files to process"
      }
    }
    else {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Found $($mboxFiles.Count) mbox file(s) to process"
    }

    # Process each mbox file
    foreach ($mboxFile in $mboxFiles) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Processing: $($mboxFile.Name)"

      try {
        # Parse the mbox file and extract messages
        $messages = Read-MboxFile -FilePath $mboxFile.FullName

        foreach ($message in $messages) {
          $result.TotalMessages++

          try {
            # Insert message into database
            $insertCmd = $sqlConnection.CreateCommand()
            $insertCmd.CommandText = @"
INSERT INTO dbo.gmailMessages ([Subject], [URL])
VALUES (@Subject, @URL)
"@
            $insertCmd.Parameters.AddWithValue('@Subject', $(if ($message.Subject) { $message.Subject } else { [DBNull]::Value })) | Out-Null
            $insertCmd.Parameters.AddWithValue('@URL', $(if ($message.MessageId) { $message.MessageId } else { [DBNull]::Value })) | Out-Null

            $insertCmd.ExecuteNonQuery() | Out-Null
            $result.ImportedMessages++
          }
          catch {
            $result.SkippedMessages++
            $result.Errors += "Failed to import message: $($_.Exception.Message)"
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message "Failed to import message: $($_.Exception.Message)"
          }
          finally {
            if ($insertCmd) { $insertCmd.Dispose() }
          }
        }
      }
      catch {
        $errorMsg = "Failed to process mbox file $($mboxFile.Name): $($_.Exception.Message)"
        $result.Errors += $errorMsg
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMsg
      }
    }

    $result.Success = $true
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Import completed. Total: $($result.TotalMessages), Imported: $($result.ImportedMessages), Skipped: $($result.SkippedMessages)"
  }
  catch {
    $errorMessage = "Import-GmailTakeoutData failed: $($_.Exception.Message)"
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
    $result.Errors += $errorMessage
    $result.Success = $false
    throw
  }
  finally {
    # Close and dispose connection
    if ($sqlConnection -and $sqlConnection.State -eq [System.Data.ConnectionState]::Open) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Closing SQL connection"
      $sqlConnection.Close()
      $sqlConnection.Dispose()
    }

    $result.EndTime = Get-Date
  }

  Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Private function completed'

  return $result
}

<#
.SYNOPSIS
Parses an mbox file and returns message objects.

.DESCRIPTION
Helper function to parse mbox format files and extract individual email messages.

.PARAMETER FilePath
Path to the mbox file to parse.

.OUTPUTS
System.Object[]
Returns an array of message objects with properties like Subject, From, Date, MessageId, etc.
#>
function Read-MboxFile {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$FilePath
  )

  $fn = 'Read-MboxFile'
  $mn = 'ATAP.Utilities.Gmail.Powershell'

  Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Parsing mbox file: $FilePath"

  $messages = @()
  $currentMessage = $null
  $inHeaders = $true
  $headerBuffer = @()

  try {
    # Read file line by line to handle large mbox files
    $reader = [System.IO.StreamReader]::new($FilePath, [System.Text.Encoding]::UTF8)

    while ($null -ne ($line = $reader.ReadLine())) {
      # New message starts with "From " at the beginning of a line
      if ($line -match '^From ') {
        # Save previous message if exists
        if ($currentMessage) {
          $messages += $currentMessage
        }

        # Start new message
        $currentMessage = [PSCustomObject]@{
          Subject   = $null
          From      = $null
          To        = $null
          Date      = $null
          MessageId = $null
          Labels    = @()
        }
        $inHeaders = $true
        $headerBuffer = @()
      }
      elseif ($currentMessage) {
        if ($inHeaders) {
          if ([string]::IsNullOrWhiteSpace($line)) {
            # End of headers
            $inHeaders = $false
          }
          else {
            # Parse header lines
            if ($line -match '^Subject:\s*(.*)$') {
              $currentMessage.Subject = $matches[1]
            }
            elseif ($line -match '^From:\s*(.*)$') {
              $currentMessage.From = $matches[1]
            }
            elseif ($line -match '^To:\s*(.*)$') {
              $currentMessage.To = $matches[1]
            }
            elseif ($line -match '^Date:\s*(.*)$') {
              $currentMessage.Date = $matches[1]
            }
            elseif ($line -match '^Message-ID:\s*(.*)$') {
              $currentMessage.MessageId = $matches[1]
            }
            elseif ($line -match '^X-Gmail-Labels:\s*(.*)$') {
              $currentMessage.Labels = $matches[1] -split ','
            }
          }
        }
      }
    }

    # Don't forget the last message
    if ($currentMessage) {
      $messages += $currentMessage
    }
  }
  finally {
    if ($reader) {
      $reader.Close()
      $reader.Dispose()
    }
  }

  Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Parsed $($messages.Count) messages from mbox file"

  return $messages
}
