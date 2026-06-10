# AI assisted using Powershell.instructions.md as guidelines
function ConvertFrom-MboxFile {
    <#
  .SYNOPSIS
    Parses an mbox file and exports each message's subject and URLs to a CSV.
  .DESCRIPTION
    Uses MimeKit to stream-parse an mbox file. For each message, extracts the
    subject line and all HTTP/HTTPS URLs from the text or HTML body, then writes
    a CSV. MimeKit.dll is discovered in the following order:
      1. Explicit -MimeKitAssemblyPath parameter.
      2. Module-relative Packages\MimeKit\*\net8.0\MimeKit.dll (newest version).
      3. Throws a clear error if not found.
    The output CSV defaults to a timestamped file under the system temp folder.
  .PARAMETER FilePath
    Full path to the source .mbox file.
  .PARAMETER OutputCsv
    Full path to the output CSV file. Defaults to a timestamped file under
    [System.IO.Path]::GetTempPath().
  .PARAMETER MimeKitAssemblyPath
    Optional explicit path to MimeKit.dll. When omitted the function auto-discovers
    the assembly relative to the module root.
  .OUTPUTS
    [string] The full path to the written CSV file.
  .EXAMPLE
    ConvertFrom-MboxFile -FilePath 'D:\Mail\Drafts.mbox'
  .EXAMPLE
    ConvertFrom-MboxFile -FilePath 'D:\Mail\Drafts.mbox' -OutputCsv 'D:\Mail\drafts.csv'
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  .LINK
    https://github.com/BillHertzing/ATAP.Utilities
  #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$FilePath,

        [Parameter()]
        [string]$OutputCsv,

        [Parameter()]
        [string]$MimeKitAssemblyPath
    )

    begin {
        $fn = $MyInvocation.MyCommand.Name
        $mn = 'ATAP.Utilities.PowerShell'
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "BEGIN: FilePath='$FilePath'"

        # Resolve OutputCsv default: system temp folder with a timestamped name
        if ([string]::IsNullOrWhiteSpace($OutputCsv)) {
            $stamp = (Get-Date -Format 'yyyyMMdd_HHmmss')
            $OutputCsv = Join-Path ([System.IO.Path]::GetTempPath()) "MboxExport_$stamp.csv"
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "OutputCsv defaulted to '$OutputCsv'."
        }

        # Resolve MimeKit assembly
        $resolvedDllPath = $null
        if (-not [string]::IsNullOrWhiteSpace($MimeKitAssemblyPath)) {
            $resolvedDllPath = $MimeKitAssemblyPath
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Using explicit MimeKitAssemblyPath='$resolvedDllPath'."
        } else {
            # Auto-discover relative to module root ($PSScriptRoot is public/, so go up one level)
            $moduleRoot = Split-Path -Parent $PSScriptRoot
            $candidates = Get-ChildItem -Path (Join-Path $moduleRoot 'Packages' 'MimeKit') `
                -Recurse -Filter 'MimeKit.dll' -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName -match 'net8\.0' } |
                Sort-Object { [version]($_.FullName -replace '^.*MimeKit\\V?([0-9.]+)\\.*$', '$1') } -Descending
            if ($candidates) {
                $resolvedDllPath = $candidates[0].FullName
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Auto-discovered MimeKit at '$resolvedDllPath'."
            }
        }
        if (-not $resolvedDllPath -or -not (Test-Path $resolvedDllPath)) {
            $errMsg = "MimeKit.dll not found. Provide -MimeKitAssemblyPath or place MimeKit.dll under the module's Packages\MimeKit\<Version>\net8.0\ folder."
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errMsg
            throw $errMsg
        }

        # Load MimeKit if not already loaded
        if (-not ([System.AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.GetName().Name -eq 'MimeKit' })) {
            try {
                Add-Type -Path $resolvedDllPath -ErrorAction Stop
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Loaded MimeKit from '$resolvedDllPath'."
            } catch {
                $errMsg = "Failed to load MimeKit from '$resolvedDllPath': $_"
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errMsg
                throw $errMsg
            }
        }
    }

    process {
        if (-not (Test-Path $FilePath)) {
            $errMsg = "Mbox file not found: '$FilePath'."
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errMsg
            throw $errMsg
        }

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Parsing mbox '$FilePath' -> '$OutputCsv'."

        $results = New-Object System.Collections.Generic.List[Object]

        try {
            $stream = [System.IO.File]::OpenRead($FilePath)
            $parser = New-Object MimeKit.MimeParser($stream, [MimeKit.MimeFormat]::Mbox)

            while (-not $parser.IsEndOfStream) {
                $message = $parser.ParseMessage()
                $subject = $message.Subject

                $body = $message.TextBody
                if ($null -eq $body) { $body = $message.HtmlBody }
                if ($null -eq $body) { $body = '' }

                $urlPattern = '(https?://[a-zA-Z0-9\-\.]+\.[a-zA-Z]{2,3}(:[0-9]+)?/?([a-zA-Z0-9\-\._\?\,\x27/\\\+&%\$#\=~])*)'
                $urls = [System.Text.RegularExpressions.Regex]::Matches($body, $urlPattern)
                $urlList = $urls | ForEach-Object { $_.Value } | Sort-Object -Unique

                $results.Add([PSCustomObject]@{
                        Subject = $subject
                        URLs    = ($urlList -join ', ')
                    })
            }
        } finally {
            if ($stream) { $stream.Dispose() }
        }

        if ($PSCmdlet.ShouldProcess($OutputCsv, 'Write mbox CSV export')) {
            $results | Export-Csv -Path $OutputCsv -NoTypeInformation
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Exported $($results.Count) messages to '$OutputCsv'."
        }

        return $OutputCsv
    }
}
