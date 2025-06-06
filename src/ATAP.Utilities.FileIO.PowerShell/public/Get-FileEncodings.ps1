#############################################################################
#region Get-FileEncoding
<#
.SYNOPSIS
Gets the encoding of a file
.DESCRIPTION
ToDo: write Help DESCRIPTION For this function
.PARAMETER Name
ToDo: write Help For the parameter X
.PARAMETER Extension
ToDo: write Help For the parameter X
.INPUTS
ToDo: write Help For the function's inputs
.OUTPUTS
ToDo: write Help For the function's outputs
.EXAMPLE
Get-FileEncoding.ps1 .\UnicodeScript.ps1

BodyName          : unicodeFFFE
EncodingName      : Unicode (Big-Endian)
HeaderName        : unicodeFFFE
WebName           : unicodeFFFE
WindowsCodePage   : 1200
IsBrowserDisplay  : False
IsBrowserSave     : False
IsMailNewsDisplay : False
IsMailNewsSave    : False
IsSingleByte      : False
EncoderFallback   : System.Text.EncoderReplacementFallback
DecoderFallback   : System.Text.DecoderReplacementFallback
IsReadOnly        : True
CodePage          : 1201

.EXAMPLE
ToDo: write Help For example 2 of using this function
.EXAMPLE
ToDo: write Help For example 2 of using this function
.ATTRIBUTION
 From Windows PowerShell Cookbook (O'Reilly) by Lee Holmes
.LINK
 (http://www.leeholmes.com/guide)
.SCM
ToDo: insert SCM keywords markers that are automatically inserted <Configuration Management Keywords>
#>
Function Get-FileEncoding {

  #region FunctionParameters
  #region FunctionParameters
  [CmdletBinding(SupportsShouldProcess = $true)]
  param(
    # The path of the file to get the encoding of.
    $Path
  )
  #endregion FunctionParameters
  #region FunctionBeginBlock
  ########################################
  BEGIN {
    Write-Verbose -Message "Starting $($MyInvocation.Mycommand)"
    Set-StrictMode -Version 3
  }
  #endregion FunctionBeginBlock

  #region FunctionProcessBlock
  ########################################
  PROCESS {
  }
  #endregion FunctionProcessBlock
  #region FunctionEndBlock
  ########################################
  END {
    ## First, check if the file is binary. That is, if the first
    ## 5 lines contain any non-printable characters.
    $nonPrintable = [char[]] (0..8 + 10..31 + 127 + 129 + 141 + 143 + 144 + 157)
    $lines = Get-Content $Path -ErrorAction Ignore -TotalCount 5
    $result = @($lines | Where-Object { $_.IndexOfAny($nonPrintable) -ge 0 })
    if ($result.Count -gt 0) {
      'Binary'
      return
    }

    ## Next, check if it matches a well-known encoding.

    ## The hashtable used to store our mapping of encoding bytes to their
    ## name. For example, "255-254 = Unicode"
    $encodings = @{}

    ## Find all of the encodings understood by the .NET Framework. For each,
    ## determine the bytes at the start of the file (the preamble) that the .NET
    ## Framework uses to identify that encoding.
    foreach ($encoding in [System.Text.Encoding]::GetEncodings()) {
      $preamble = $encoding.GetEncoding().GetPreamble()
      if ($preamble) {
        $encodingBytes = $preamble -join '-'
        $encodings[$encodingBytes] = $encoding.GetEncoding()
      }
    }

    ## Find out the lengths of all of the preambles.
    $encodingLengths = $encodings.Keys | Where-Object { $_ } |
    ForEach-Object { ($_ -split '-').Count }

    ## Assume the encoding is UTF7 by default
    $result = [System.Text.Encoding]::UTF7

    ## Go through each of the possible preamble lengths, read that many
    ## bytes from the file, and then see if it matches one of the encodings
    ## we know about.
    foreach ($encodingLength in $encodingLengths | Sort-Object -Descending) {
      $bytes = Get-Content -Encoding byte -ReadCount $encodingLength $path | Select-Object -First 1
      $encoding = $encodings[$bytes -join '-']

      ## If we found an encoding that had the same preamble bytes,
      ## save that output and break.
      if ($encoding) {
        $result = $encoding
        break
      }
    }

    ## Finally, output the encoding.
    $result
  }
}
