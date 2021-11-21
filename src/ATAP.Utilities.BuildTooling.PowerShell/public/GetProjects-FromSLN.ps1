
Function GetProjects-FromSLN {

  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
    [string]$path = 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\*.sln'
  )
  Function ParseStructure-FromSLN {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
      [string]$path = 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\*.sln'
    )

    function New-Tuple { #https://stackoverflow.com/questions/54373785/tuples-arraylist-of-pairs
      Param(
        [Parameter(
          Mandatory = $true,
          ValueFromPipeline = $true,
          ValueFromPipelineByPropertyName = $true
        )]
        [ValidateCount(2, 20)]
        [array]$Values
      )

      Process {
        $types = ($Values | ForEach-Object { $_.GetType().Name }) -join ','
        New-Object "Tuple[$types]" $Values
      }
    }

    function Convert-WhitespaceToRegex {
      Param(
        [Parameter(
          Mandatory = $true,
          ValueFromPipeline = $true,
          ValueFromPipelineByPropertyName = $true
        )]
        $string
      )

      Process {
        $string -replace '(\\\s+)+', '\s*'
      }
    }
    function Add-LeadingAndTrailingWhitespace {
      Param(
        [Parameter(
          Mandatory = $true,
          ValueFromPipeline = $true,
          ValueFromPipelineByPropertyName = $true
        )]
        $string
      )

      Process {
        ' ' + $string:' '
      }
    }

    $extractlist = (
      #
      (Convert-WhitespaceToRegex([Regex]::Escape(Add-LeadingAndTrailingWhitespace(@'
" VisualStudioVersion = (?<CurrentVisualStudioVersion>16.0.28729.10)  "
'@))), 'CurrentVisualStudioVersion')
      #
      (Convert-WhitespaceToRegex([Regex]::Escape(Add-LeadingAndTrailingWhitespace(@'
<PackageReference Include="MedallionShell" Version="1.5.1" />
'@))), "<PackageReference Include=""MedallionShell"" />`n"
      )
    ) | New-Tuple

    $sln = gci $path '*.sln';
    # gc *.sln | ?{$_ -match 'project\('} | %{$_ -replace 'project\(.+?\) = (.+?), (.+?), .*', '$1 at $2'} | sort
    #ToDo validate only one
    $text = [IO.File]::ReadAllText($sln)
    foreach ($line in $text) {
      foreach ($kvp in $extractlist) {
        # replace each
        $m = $kvp.Item1.Match($line)
        $line = ' ' + $line
        $text = $text -replace $kvp.Item1, $kvp.Item2
      }
    }
    #$text
  }
}


}

}
