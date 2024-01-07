
    # Used by Create-BlogPostImages.
    function Get-UniqueFileBasenames {
      [CmdletBinding()]
      param (
        [parameter(Mandatory = $true, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]  $inFileInfo
        ,[parameter(Mandatory = $true, ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $True)]  $MediaQueryFilenameFragments
      )
      BEGIN {
        $acc = @()
      }
      PROCESS { $acc += $inFileInfo }
      END {
        $pattern = $MediaQueryFilenameFragments.Keys -join '|'
        $acc | Select-Object -ExpandProperty Basename | ForEach-Object { $_ -replace $pattern, '' } | Sort-Object -Uniq
      }
    }
