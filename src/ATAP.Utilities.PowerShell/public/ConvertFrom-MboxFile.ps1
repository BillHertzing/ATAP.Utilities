# Load the MimeKit assembly
$pathToMimeKitAssemblyDirectory = 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Powershell\Packages\MimeKit\V4.5.0\net8.0'
$FilenameOFMimeKitAssembly = 'MimeKit.dll'
Add-Type -Path (join-path $pathToMimeKitAssemblyDirectory $FilenameOFMimeKitAssembly)

# Define the function to parse the mbox file and extract data
function ConvertFrom-MboxFile {
    param([string]$filePath, [string]$outputCsv )

    # Create a list to hold the results
    $results = New-Object System.Collections.Generic.List[Object]

    # Create a file stream
    $stream = [System.IO.File]::OpenRead($filePath)
    $parser = New-Object MimeKit.MimeParser($stream, [MimeKit.MimeFormat]::Mbox)

    while (-not $parser.IsEndOfStream) {
        $message = $parser.ParseMessage()
        $subject = $message.Subject

        # Extract URLs from the message body
        $body = $message.TextBody
        if ($null -eq $body) {
            $body = $message.HtmlBody
        }
        $urls = [Regex]::Matches($body, "(http|https)://[a-zA-Z0-9\-\.]+\.[a-zA-Z]{2,3}(:[a-zA-Z0-9]*)?/?([a-zA-Z0-9\-\._\?\,\'/\\\+&%\$#\=~])*")
        $urlList = $urls | ForEach-Object { $_.Value } | Sort-Object -Unique

        # Create an object for each email with subject and URL list
        $results.Add([PSCustomObject]@{
            Subject = $subject
            URLs = ($urlList -join ", ")
        })
    }

    $stream.Close()

    # Export results to CSV
    $results | Export-Csv -Path $outputCsv -NoTypeInformation
}

# Call the function with the path to your mbox file and desired output CSV file
ConvertFrom-MboxFile 'C:\Temp\gmaildrafts\Takeout\Mail\Drafts.mbox' 'C:\Temp\gmaildrafts\Takeout\Mail\drafts.csv'
