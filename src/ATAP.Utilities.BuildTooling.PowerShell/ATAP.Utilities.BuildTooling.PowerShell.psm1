
#############################################################################
#region Remove-ObjAndBinSubdirs
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
ToDo: write Help For example 2 of using this function
.ATTRIBUTION
ToDo: write text describing the ideas and codes that are attributed to others
.LINK
ToDo: insert link to internet articles that contributed ideas / code used in this function e.g. http://www.somewhere.com/attribution.html
.LINK
ToDo: insert link to internet articles that contributed ideas / code used in this function e.g. http://www.somewhere.com/attribution.html
.SCM
ToDo: insert SCM keywords markers that are automatically inserted <Configuration Management Keywords>
#>
Function Remove-ObjAndBinSubdirs {
  #region FunctionParameters
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
    [parameter()]
    [string] $path = './'
  )
  #endregion FunctionParameters
  #region FunctionBeginBlock
  ########################################
  BEGIN {
    $dirsToDelete = 'obj', 'bin'
    Write-Verbose "path = $path"
    # validate path exists
    if (!(Test-Path -Path $path)) { throw "$path was not found" }
    Write-Verbose "Removing obj and bin subdirs recursively below $path"
    # build alternation (OR) pattern for directory names as returned by gci, anchored to the end : (\\obj|\\bin)$
    $MatchRegex = '(' + (($dirstodelete | ForEach-Object { '\\' + $_ }) -Join ('|')) + ')$'
    $pathsToDelete = Get-ChildItem -Recurse -Directory $path | Where-Object { $_.psISContainer -and ($_.fullname -match $MatchRegex) }
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
    Write-Verbose "Removing $($pathsToDelete.Length) directories:  $($pathsToDelete -join [environment]::NewLine)"
    $pathsToDelete | ForEach-Object {
      $dirToDelete = $_
      if ($PSCmdlet.ShouldProcess("$dirToDelete", 'remove-item -recurse -force ')) {
        Remove-Item -Recurse -Force $dirToDelete -WhatIf:$WhatIfPreference -Verbose:$Verbosepreference
        #write-verbose "remove-item -recurse -force $dirToDelete -WhatIf:$WhatIfPreference -Verbose:$Verbosepreference"
      }
    }
  }
  #endregion FunctionEndBlock
}
#endregion Remove-ObjAndBinSubdirs
#############################################################################


# useage: $results = Get-BrokenGitSubDirs ; $results.keys | %{$key = $_;  $results[$key].keys | %{"$key $_ $($($($results[$key])[$_]) -join [environment]::NewLine)" }}
# does not get any stderr message
Function Get-BrokenGitSubDirs {
  [CmdletBinding(SupportsShouldProcess = $true)]
  $results = @{}
  Get-ChildItem |
  Where-Object { $_.psiscontainer -and ($_.name -notmatch '^\.') -and (Test-Path -Path $(Join-Path -Path $_.name -ChildPath '.git')) } |
  ForEach-Object { Set-Location $_.name
    $errors = git fsck
    $results[$_.name] = @{'ErrorCount' = $errors.length; 'ErrorList' = $errors }
    Set-Location ..
  }
  $results
}


#############################################################################
#region Get-CoreInfo
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
ToDo: write Help For example 2 of using this function
.ATTRIBUTION
ToDo: write text describing the ideas and codes that are attributed to others
.LINK
ToDo: insert link to internet articles that contributed ideas / code used in this function e.g. http://www.somewhere.com/attribution.html
.LINK
ToDo: insert link to internet articles that contributed ideas / code used in this function e.g. http://www.somewhere.com/attribution.html
.SCM
ToDo: insert SCM keywords markers that are automatically inserted <Configuration Management Keywords>
#>
Function Get-CoreInfo {
  #region FunctionParameters
  param (
  )
  #endregion FunctionParameters
  #region FunctionBeginBlock
  ########################################
  BEGIN {
    Write-Verbose -Message "Starting $($MyInvocation.Mycommand)"
    Write-Verbose "path = $path"
    # validate path exists
    if (!(Test-Path -Path $path)) { throw "$path was not found" }
  }
  #endregion FunctionBeginBlock

  #region FunctionProcessBlock
  ########################################
  PROCESS {
    #
  }
  #endregion FunctionProcessBlock

  #region FunctionEndBlock
  ########################################
  END {
    if (Test-Path "$env:programfiles/dotnet/") {
      try {

        [Collections.Generic.List[string]] $info = dotnet --info

        # the line after the line containing this string holds the DotNet version
        $DotNetSDKVersionLineIndex = $info.FindIndex( { $args[0].ToString().ToLower() -like '.NET SDK (reflecting any global.json):' } ) + 1
        # to the right of the colon and trimmed
        $DotNetSDKVersion = (($info[$DotNetSDKVersionLineIndex]).Split(':')[1]).Trim()

        # the line after the line containing this string holds the DotNet Core version
        $DotNetCoreSDKVersionLineIndex = $info.FindIndex( { $args[0].ToString().ToLower() -like '.NET Core SDK (reflecting any global.json):' } ) + 1
        # to the right of the colon and trimmed
        $DotNetCoreSDKVersion = (($info[$DotNetCoreSDKVersionLineIndex]).Split(':')[1]).Trim()

        $OSVersionLineIndex = $info.FindIndex( { $args[0].ToString().ToLower() -match '^\s+OS\s+Version:\s+' } )
        $OSVersion = (($info[$OSVersionLineIndex]).Split(':')[1]).Trim()
        $OSNameLineIndex = $info.FindIndex( { $args[0].ToString().ToLower() -match '^\s+OS\s+Name:\s+' } )
        $OSName = (($info[$OSNameLineIndex]).Split(':')[1]).Trim()
        $OSPlatformLineIndex = $info.FindIndex( { $args[0].ToString().ToLower() -match '^\s+OS\s+Platform:\s+' } )
        $OSPlatform = (($info[$OSPlatformLineIndex]).Split(':')[1]).Trim()
        $RIDLineIndex = $info.FindIndex( { $args[0].ToString().ToLower() -match '^\s+RID:\s+' } )
        $RID = (($info[$RIDLineIndex]).Split(':')[1]).Trim()

        # the lines after the line containing this string holds the installed runtimes
        $DotNetCoreSDKVersionLineIndex = $info.FindIndex( { $args[0].ToString().ToLower() -like '.NET Core runtimes installed:' } ) + 1
        # ToDo: Include the list of DotNet sdk s and the list of DotNet runtimes installed
        # ToDo: validate the information returned byt dotnet --info matches the subdirectories  found on disk
        $runtimes = (Get-ChildItem "$env:programfiles/dotnet/shared/Microsoft.NETCore.App").Name | Out-String
        $object = New-Object -TypeName pscustomobject -Property (@{
            'DotNetSDKVersion'     = $DotNetSDKVersion;
            'DotNetCoreSDKVersion' = $DotNetCoreSDKVersion;
            'OSName'               = $OSName;
            'OSVersion'            = $OSVersion;
            'OSPlatform'           = $OSPlatform;
            'RID'                  = $RID;
            'BIOSSerial'           = $bios.SerialNumber
          })

        return  $object
      }
      catch {
        $errorMessage = $_.Exception.Message
        Write-Host "Something went wrong`r`nError: $errorMessage"
        return ''
      }
    }
    else {
      Write-Host 'No SDK installed'
      return ''
    }

    Write-Verbose -Message "Ending $($MyInvocation.Mycommand)"
  }
  #endregion FunctionEndBlock
}
#endregion Get-CoreInfo
#############################################################################

#############################################################################


Function Get-FileEncoding {
  ##############################################################################
  ##
  ## Get-FileEncoding
  ##
  ## From Windows PowerShell Cookbook (O'Reilly)
  ## by Lee Holmes (http://www.leeholmes.com/guide)
  ##
  ##############################################################################

  <#

.SYNOPSIS

Gets the encoding of a file

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

#>

  param(
    ## The path of the file to get the encoding of.
    $Path
  )


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
  foreach ($encodingLength in $encodingLengths | sort -Descending) {
    $bytes = Get-Content -Encoding byte -ReadCount $encodingLength $path | select -First 1
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

# Function Remove_VSComponentCache {
#   [CmdletBinding(SupportsShouldProcess = $true)]

#   write-verbose "starting Remove_VSComponentCache"
#   write-verbose "Removing ($ENV:\AppData)\Local\Microsoft\VisualStudio\15.0\ComponentModelCache"
#   if ($PSCmdlet.ShouldProcess("($ENV:\AppData)\Local\Microsoft\VisualStudio\15.0\ComponentModelCache", 'Delete')) {
# 				write-host "really would delete ($ENV:\AppData)\Local\Microsoft\VisualStudio\15.0\ComponentModelCache"
# 		}
# }

# #
# Function Empty-NuGetCaches {
#   [CmdletBinding(SupportsShouldProcess = $true)]

#   # ToDo: rewrite using powershell NuGet or dotnet nuget commands?
#   write-verbose "starting Empty-NuGetCaches"
#   write-verbose "Removing ($ENV:\AppData)\Local\NuGet\v3-cache"
#   if ($PSCmdlet.ShouldProcess("($ENV:\AppData)\Local\NuGet\v3-cache", 'Delete')) {
# 				write-host "really would delete ($ENV:\AppData)\Local\NuGet\v3-cache"
# 		}
#   write-verbose "Removing ($ENV:\USERPROFILE)\.nuget\packages"
#   if ($PSCmdlet.ShouldProcess("($ENV:\USERPROFILE)\.nuget\packages", 'Delete')) {
# 				write-host "really would delete ($ENV:\USERPROFILE)\.nuget\packages"
# 		}
#   write-verbose "Removing ($ENV:\AppData)\Local\Temp\NuGetScratch"
#   if ($PSCmdlet.ShouldProcess("($ENV:\AppData)\Local\Temp\NuGetScratch", 'Delete')) {
# 				write-host "really would delete ($ENV:\AppData)\Local\Temp\NuGetScratch"
# 		}
# }

# Function create-DocFolderIfNotPresent {
#   [CmdletBinding(SupportsShouldProcess = $true)]
#   param (
#     [parameter(mandatory = $true)]
#     [ValidateNotNullOrEmpty()]
#     [string]$ProjectPath
#   )
#   write-verbose "ProjectPath is $ProjectPath, adding a DOC folder if not present"
#   if ($PSCmdlet.ShouldProcess("$ProjectPath\Docs", 'Create')) {
# 				New-Item -Path "$ProjectPath\Docs" -ItemType Directory -Force
# 		}
# }

# Function create-DocFilesIfNotPresent {
#   [CmdletBinding(SupportsShouldProcess = $true)]
#   param (
#     [parameter(mandatory = $true)]
#     [ValidateNotNullOrEmpty()]
#     [string]$DocsPath
#     , [parameter(mandatory = $true)]
#     [ValidateNotNullOrEmpty()]
#     [string[]]$DocFileNames
#   )
#   write-verbose "DocsPath is $DocsPath, error if not present"
#   if (!Test-Path -Path $DocsPath) { throw "$DocsPath is not present" }
#   $DocFileNames | % { $dfn = $_;
#     $dfp = Join-path $DocsPath $dfn
#     if (Test-Path -Path $dfp) {
#       write-verbose "DocFullPath $dfp already exists"
#     }
#     else {
#       if ($PSCmdlet.ShouldProcess("$dfp", 'Create')) {
#         write-verbose "Creating empty file $dfp, utf-8 encoding, no BOM"
#         [io.file]::WriteAllText($dfp, "", (new-object  System.Text.UTF8Encoding($false)))
#       }
#     }
#   }
# }


