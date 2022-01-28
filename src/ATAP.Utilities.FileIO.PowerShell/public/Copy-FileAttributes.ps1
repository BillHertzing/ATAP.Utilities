
#############################################################################
#region Copy-FileAttributes
<#
.SYNOPSIS
ToDo: write Help SYNOPSIS For this function
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
ToDo: write Help For example 1 of using this function
.EXAMPLE
ToDo: write Help For example 2 of using this function
.EXAMPLE
  ToDo: add examples
.ATTRIBUTION
ToDo: write text describing the ideas and codes that are attributed to others
.LINK
ToDo: insert link to internet articles that contributed ideas / code used in this function e.g. http://www.somewhere.com/attribution.html
.LINK
ToDo: insert link to internet articles that contributed ideas / code used in this function e.g. http://www.somewhere.com/attribution.html
.SCM
ToDo: insert SCM keywords markers that are automatically inserted <Configuration Management Keywords>
#>
Function Copy-FileAttributes {
  #region FunctionParameters
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
    [parameter(Mandatory = $true, ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $True)]
    [ValidateNotNullOrEmpty()] $source
    , [parameter(Mandatory = $true, ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $True)]
    [ValidateNotNullOrEmpty()] $target
    , [alias('Attr')]
    [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $True)]
    $Attributes = @('CreationTimeUtc', 'LastWriteTimeUtc')
  )
  #endregion FunctionParameters

  #region FunctionBeginBlock
  ########################################
  BEGIN {
    Write-Verbose -Message "Starting $($MyInvocation.Mycommand)"
    ########################################
    #region local private function
    function Private:Get-FileInfo {
      param (
        $source
      )
      if ($source -is [string]) {
        Get-Item -Path $source
      } elseif ($source -is [System.IO.DirectoryInfo]) {
        Write-Warning "Directories are not supported. Skipping $source."
        continue
      } elseif ($source -is [System.IO.FileInfo]) {
        $source
      } else {
        Write-Warning "Only files are supported. Skipping $source."
        continue
      }
    }

    function Private:Copy-Attrs {
      [CmdletBinding(SupportsShouldProcess = $true)]
      param (
        $sFileInfo
        , $tFileInfo
        , $Attributes
      )
      $Attributes | ForEach-Object {$attr = $_;
        if ($sFileInfo.$attr -ne $tFileInfo.$attr) {
          if ($PSCmdlet.ShouldProcess(@($sfileInfo,$tFileInfo,$attr), "$tFileInfo.$attr = $sfileInfo.$attr")) {
            $tFileInfo.$attr = $sfileInfo.$attr
          }
        }
      }
    }
    #endregion local private function

  }
  #endregion FunctionBeginBlock

  #region FunctionProcessBlock
  ########################################
  PROCESS {
    # ToDo: convert to a pipeline cmdlet
  }
  #endregion FunctionProcessBlock

  #region FunctionEndBlock
  ########################################
  END {
    if ((($source -is [String]) -or ($source -is [System.IO.FileInfo])) -and (($target -is [String]) -or ($target -is [System.IO.FileInfo]))) {
      $sFileInfo = Get-FileInfo $source
      $tFileInfo = Get-FileInfo $target
      copy-Attrs $sFileInfo $tFileInfo $Attributes
    }
    elseif (($source -is [Object[]]) -and ($target -is [Object[]]) -and ($source.count -eq $target.count) ) {
      for ($i = 0; $i -lt $source.Count; $i++) {
        $sFileInfo = Get-FileInfo $source[$i]
        $tFileInfo = Get-FileInfo $target[$i];
        copy-Attrs $sFileInfo $tFileInfo $Attributes
      }
    }
    else {
      # ToDo: improve warning, show what's what
      throw 'Copy-FileAttributes source and target must both be single files or must both be same-sized arrays'
    }
    Write-Verbose -Message "Ending $($MyInvocation.Mycommand)"
  }
  #endregion FunctionEndBlock
}
#endregion Copy-FileAttributes
#############################################################################

