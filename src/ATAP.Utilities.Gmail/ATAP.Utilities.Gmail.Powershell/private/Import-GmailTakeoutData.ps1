<#
.SYNOPSIS
Private function that processes Gmail Takeout data and imports it into SQL Server.

.DESCRIPTION
This private function handles the actual parsing and importing of Gmail data from an extracted
Google Takeout archive. It expects the standard Google Takeout folder structure and processes
the mbox files and metadata to populate the database tables.

The caller is responsible for opening and closing the SQL connection.

.PARAMETER SqlConnection
An open Microsoft.Data.SqlClient.SqlConnection object. The connection must be open and
connected to the target database. The caller is responsible for managing the connection lifecycle.

.PARAMETER TakeoutDataPath
Path to the directory containing the extracted Google Takeout data.

.PARAMETER BatchSize
Number of messages to insert per database transaction. Default is 100.
Larger batch sizes improve performance but use more memory.

.OUTPUTS
System.Object
Returns a summary object with counts of imported items and any errors encountered.

.EXAMPLE
$connection = New-Object Microsoft.Data.SqlClient.SqlConnection($connectionString)
$connection.Open()
try {
    Import-GmailTakeoutData -SqlConnection $connection -TakeoutDataPath "C:\Temp\Gmail" -BatchSize 100
} finally {
    $connection.Close()
    $connection.Dispose()
}
Uses an open SQL connection managed by the caller with batch size of 100 messages per transaction.

.NOTES
AI assisted using Powershell.instructions.md as guidelines
This is a private function called by Load-GmailToDatabase.
The caller must manage the connection lifecycle (open before calling, close after).

.LINK
https://github.com/whertzing/ATAP.Utilities
#>
function Import-GmailTakeoutData {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateNotNull()]
    [Microsoft.Data.SqlClient.SqlConnection]$SqlConnection,

    [Parameter(Mandatory = $true, Position = 1)]
    [ValidateScript({ Test-Path $_ -PathType Container })]
    [string]$TakeoutDataPath,

    [Parameter(Mandatory = $false, Position = 2)]
    [int]$BatchSize = 100
  )

  $fn = 'Import-GmailTakeoutData'
  $mn = 'ATAP.Utilities.Gmail.Powershell'

  Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Private function started'
  Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "TakeoutDataPath: $TakeoutDataPath"

  # Validate the connection is open
  if ($SqlConnection.State -ne [System.Data.ConnectionState]::Open) {
    throw "SqlConnection must be open. Current state: $($SqlConnection.State)"
  }

  Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Using provided SQL connection to database: $($SqlConnection.Database)"

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

        # Process messages in batches
        $batch = @()
        $batchNumber = 0

        foreach ($message in $messages) {
          $result.TotalMessages++
          $batch += $message

          if ($batch.Count -ge $BatchSize) {
            $batchNumber++

            $batchResult = Import-MessageBatch -SqlConnection $SqlConnection -Messages $batch -FunctionName $fn -ModuleName $mn
            $result.ImportedMessages += $batchResult.InsertedCount
            $result.SkippedMessages += ($batch.Count - $batchResult.InsertedCount)
            $result.Errors += $batchResult.DateParseErrors

            # Progress update every 2 batches
            if ($batchNumber % 2 -eq 0) {
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Progress: $batchNumber batches completed, $($result.ImportedMessages) messages imported"
            }

            $batch = @()
          }
        }

        # Insert remaining messages in final batch
        if ($batch.Count -gt 0) {
          $batchNumber++
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Inserting final batch $batchNumber ($($batch.Count) messages)"

          $batchResult = Import-MessageBatch -SqlConnection $SqlConnection -Messages $batch -FunctionName $fn -ModuleName $mn
          $result.ImportedMessages += $batchResult.InsertedCount
          $result.SkippedMessages += ($batch.Count - $batchResult.InsertedCount)
          $result.Errors += $batchResult.DateParseErrors
        }

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Completed $($mboxFile.Name): $batchNumber batches processed"
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
    # Connection lifecycle is managed by caller - do not close here
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
Extracts headers (Subject, From, To, Date, MessageId, Labels) and the full body content.

.PARAMETER FilePath
Path to the mbox file to parse.

.OUTPUTS
System.Object[]
Returns an array of message objects with the following properties:
- Subject: The email subject line
- From: The sender address
- To: The recipient address
- Date: The email date
- MessageId: The unique message identifier
- Labels: Array of Gmail labels
- Body: The full body content of the email
- URL: The first URL extracted from the body (null if no URL found)

.NOTES
AI assisted using Powershell.instructions.md as guidelines
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
  $bodyBuilder = $null

  try {
    # Read file line by line to handle large mbox files
    $reader = [System.IO.StreamReader]::new($FilePath, [System.Text.Encoding]::UTF8)

    while ($null -ne ($line = $reader.ReadLine())) {
      # New message starts with "From " at the beginning of a line
      if ($line -match '^From ') {
        # Save previous message if exists
        if ($currentMessage) {
          # Finalize body content and extract URL
          if ($bodyBuilder) {
            $currentMessage.Body = $bodyBuilder.ToString()
            # Extract URL from body using regex pattern for http/https URLs
            $urlPattern = 'https?://[^\s<>\"\''`\]\[)(\}{\|\\]+'
            if ($currentMessage.Body -match $urlPattern) {
              $currentMessage.URL = $matches[0]
            }
          }
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
          Body      = $null
          URL       = $null
        }
        $inHeaders = $true
        $bodyBuilder = [System.Text.StringBuilder]::new()
      }
      elseif ($currentMessage) {
        if ($inHeaders) {
          if ([string]::IsNullOrWhiteSpace($line)) {
            # End of headers, start of body
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
        else {
          # Capture body content
          [void]$bodyBuilder.AppendLine($line)
        }
      }
    }

    # Don't forget the last message
    if ($currentMessage) {
      # Finalize body content and extract URL for last message
      if ($bodyBuilder) {
        $currentMessage.Body = $bodyBuilder.ToString()
        # Extract URL from body using regex pattern for http/https URLs
        $urlPattern = 'https?://[^\s<>\"\''`\]\[)(\}{\|\\]+'
        if ($currentMessage.Body -match $urlPattern) {
          $currentMessage.URL = $matches[0]
        }
      }
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

<#
.SYNOPSIS
Inserts a batch of messages into the database using SqlBulkCopy.

.DESCRIPTION
Helper function that uses SqlBulkCopy to efficiently bulk insert multiple messages
into the database in a single operation. Parses date header strings to DateTime values.
Falls back to individual inserts if bulk copy fails.

.PARAMETER SqlConnection
An open Microsoft.Data.SqlClient.SqlConnection object.

.PARAMETER Messages
An array of message objects to insert.

.PARAMETER FunctionName
The calling function name for logging.

.PARAMETER ModuleName
The module name for logging.

.OUTPUTS
PSCustomObject
Returns an object with InsertedCount (int) and DateParseErrors (string[]).

.NOTES
AI assisted using Powershell.instructions.md as guidelines
Uses SqlBulkCopy for efficient batch inserts instead of individual INSERT statements.
Parses RFC 2822 date headers to DateTime values for the Date column.
#>
function Import-MessageBatch {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true, Position = 0)]
    [Microsoft.Data.SqlClient.SqlConnection]$SqlConnection,

    [Parameter(Mandatory = $true, Position = 1)]
    [object[]]$Messages,

    [Parameter(Mandatory = $true, Position = 2)]
    [string]$FunctionName,

    [Parameter(Mandatory = $true, Position = 3)]
    [string]$ModuleName
  )

  $fn = $FunctionName
  $mn = $ModuleName
  $insertedCount = 0
  $dateParseErrors = @()

  try {
    # Create a DataTable matching the target table schema
    $dataTable = [System.Data.DataTable]::new('gmailMessages')

    # Add columns matching the database table (excluding ID which is IDENTITY)
    [void]$dataTable.Columns.Add('Subject', [string])
    [void]$dataTable.Columns.Add('MessageId', [string])
    [void]$dataTable.Columns.Add('FromAddress', [string])
    [void]$dataTable.Columns.Add('ToAddress', [string])
    [void]$dataTable.Columns.Add('Date', [datetime])
    [void]$dataTable.Columns.Add('Labels', [string])
    [void]$dataTable.Columns.Add('Body', [string])
    [void]$dataTable.Columns.Add('URL', [string])

    # Populate the DataTable with message data
    foreach ($message in $Messages) {
      $row = $dataTable.NewRow()
      $row['Subject'] = if ($message.Subject) { $message.Subject } else { [DBNull]::Value }
      $row['MessageId'] = if ($message.MessageId) { $message.MessageId } else { [DBNull]::Value }
      $row['FromAddress'] = if ($message.From) { $message.From } else { [DBNull]::Value }
      $row['ToAddress'] = if ($message.To) { $message.To } else { [DBNull]::Value }

      # Parse the date header to DateTime
      if ($message.Date) {
        $parsedDate = [datetime]::MinValue
        # Try parsing with RFC 2822 format and other common email date formats
        $parseSuccess = [System.DateTime]::TryParse($message.Date, [ref]$parsedDate)
        if ($parseSuccess) {
          $row['Date'] = $parsedDate
        }
        else {
          $row['Date'] = [DBNull]::Value
          $msgId = if ($message.MessageId) { $message.MessageId } else { 'unknown' }
          $dateParseErrors += "Failed to parse date '$($message.Date)' for message $msgId"
        }
      }
      else {
        $row['Date'] = [DBNull]::Value
      }

      $row['Labels'] = if ($message.Labels -and $message.Labels.Count -gt 0) { ($message.Labels -join ',') } else { [DBNull]::Value }
      $row['Body'] = if ($message.Body) { $message.Body } else { [DBNull]::Value }
      $row['URL'] = if ($message.URL) { $message.URL } else { [DBNull]::Value }
      $dataTable.Rows.Add($row)
    }

    # Use SqlBulkCopy for efficient batch insert
    $bulkCopy = [Microsoft.Data.SqlClient.SqlBulkCopy]::new($SqlConnection)
    try {
      $bulkCopy.DestinationTableName = 'dbo.gmailMessages'

      # Map DataTable columns to database columns
      [void]$bulkCopy.ColumnMappings.Add('Subject', 'Subject')
      [void]$bulkCopy.ColumnMappings.Add('MessageId', 'MessageId')
      [void]$bulkCopy.ColumnMappings.Add('FromAddress', 'FromAddress')
      [void]$bulkCopy.ColumnMappings.Add('ToAddress', 'ToAddress')
      [void]$bulkCopy.ColumnMappings.Add('Date', 'Date')
      [void]$bulkCopy.ColumnMappings.Add('Labels', 'Labels')
      [void]$bulkCopy.ColumnMappings.Add('Body', 'Body')
      [void]$bulkCopy.ColumnMappings.Add('URL', 'URL')

      $bulkCopy.WriteToServer($dataTable)
      $insertedCount = $dataTable.Rows.Count

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Bulk insert completed: $insertedCount messages"
    }
    finally {
      $bulkCopy.Close()
    }
  }
  catch {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message "Bulk insert failed, falling back to individual inserts: $($_.Exception.Message)"

    # Fallback to individual inserts
    $insertedCount = 0
    foreach ($message in $Messages) {
      $insertCmd = $null
      try {
        $insertCmd = $SqlConnection.CreateCommand()
        $insertCmd.CommandText = @"
INSERT INTO dbo.gmailMessages ([Subject], [MessageId], [FromAddress], [ToAddress], [Date], [Labels], [Body], [URL])
VALUES (@Subject, @MessageId, @FromAddress, @ToAddress, @Date, @Labels, @Body, @URL)
"@
        $insertCmd.Parameters.AddWithValue('@Subject', $(if ($message.Subject) { $message.Subject } else { [DBNull]::Value })) | Out-Null
        $insertCmd.Parameters.AddWithValue('@MessageId', $(if ($message.MessageId) { $message.MessageId } else { [DBNull]::Value })) | Out-Null
        $insertCmd.Parameters.AddWithValue('@FromAddress', $(if ($message.From) { $message.From } else { [DBNull]::Value })) | Out-Null
        $insertCmd.Parameters.AddWithValue('@ToAddress', $(if ($message.To) { $message.To } else { [DBNull]::Value })) | Out-Null

        # Parse the date header to DateTime
        if ($message.Date) {
          $parsedDate = [datetime]::MinValue
          $parseSuccess = [System.DateTime]::TryParse($message.Date, [ref]$parsedDate)
          if ($parseSuccess) {
            $insertCmd.Parameters.AddWithValue('@Date', $parsedDate) | Out-Null
          }
          else {
            $insertCmd.Parameters.AddWithValue('@Date', [DBNull]::Value) | Out-Null
            $msgId = if ($message.MessageId) { $message.MessageId } else { 'unknown' }
            # Only add error if not already tracked (from bulk insert attempt)
            if (-not ($dateParseErrors -contains "Failed to parse date '$($message.Date)' for message $msgId")) {
              $dateParseErrors += "Failed to parse date '$($message.Date)' for message $msgId"
            }
          }
        }
        else {
          $insertCmd.Parameters.AddWithValue('@Date', [DBNull]::Value) | Out-Null
        }

        $insertCmd.Parameters.AddWithValue('@Labels', $(if ($message.Labels -and $message.Labels.Count -gt 0) { ($message.Labels -join ',') } else { [DBNull]::Value })) | Out-Null
        $insertCmd.Parameters.AddWithValue('@Body', $(if ($message.Body) { $message.Body } else { [DBNull]::Value })) | Out-Null
        $insertCmd.Parameters.AddWithValue('@URL', $(if ($message.URL) { $message.URL } else { [DBNull]::Value })) | Out-Null

        $insertCmd.ExecuteNonQuery() | Out-Null
        $insertedCount++
      }
      catch {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message "Failed to import message: $($_.Exception.Message)"
      }
      finally {
        if ($insertCmd) { $insertCmd.Dispose() }
      }
    }
  }

  return [PSCustomObject]@{
    InsertedCount   = $insertedCount
    DateParseErrors = $dateParseErrors
  }
}
