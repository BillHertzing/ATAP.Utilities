#############################################################################
#region Set_PerceivedTypeInRegistryForPreviewPane
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
function Set-PerceivedTypeInRegistryForPreviewPane {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (

  )
  $suffixesString =
  @'
bak,cache,code-workspace,config,cs,csproj,css,cs-template,dot,editorconfig,eot,gitignore,go,graph,html,info,js,json,liquid,md,nuspec,partial,playlist,pp,proj,props,ps1,psd1,psm1,pssproj,pubxml,rb,reg,resources,saas,sccs,save,sln,sql,targets,tmpl,ts-template,txt,user,vb-template,xml,xsd,xslt,yml
'@
  $perceivedType = 'PerceivedType'
  if ($suffixesString.Length -eq 0) { throw "The $suffixesString is empty" }
  $suffixes = ($suffixesString.Trim() -split (',')).Trim() | % { '.' + $_ }
  $RegHiveType = [Microsoft.Win32.RegistryHive]::'ClassesRoot'
  $OpenBaseRegKey = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey($RegHiveType, $env:COMPUTERNAME)
  $result = @{}
  $accGood = @();
  $accMissingSuffix = @()
  $accMissingPT = @()
  $accWrongPTValue = @{}
  $suffixes | % { $suffix = $_
    $OpenRegSubKey = $OpenBaseRegKey.OpenSubKey($suffix)
    If ($OpenRegSubKey) {
      # If 'PerceivedType' is NOT present in the list of all RegKeyVal (s), add a new Key named PerceivedType of type String with Data (value) of 'text
      # If 'PerceivedType' IS present in the list of all RegKeyVal (s), and -force is true, ensure it is of type String with Data (value) of 'text'
      # If 'PerceivedType' IS present in the list of all RegKeyVal (s), and -force is false, do nothing to the RegSubKey, accumulate it for output later
      if ($OpenRegSubKey.GetValueNames() -match $perceivedType) {
        $GetPerceivedTypeValue = $OpenRegSubKey.GetValue($perceivedType)
        if ($GetPerceivedTypeValue -eq 'text') {
          # This suffix is good
          $accGood += $suffix
          Write-Verbose "Good : $suffix"
        }
        else {
          # the PerceivedType for this suffix is not text
          Write-Verbose "Incorrect 'PerceivedType' Value : $suffix , $GetPerceivedTypeValue"
          $accWrongPTValue[ $suffix] = $GetPerceivedTypeValue
        }
      }
      else {
        # 'PerceivedType' is NOT present in the list of all RegKeyVal
        Write-Verbose "Missing 'PerceivedType' : $suffix"
        $accMissingPT += $suffix
      }
    }
    else {
      # the complete suffix subkey is missing
      $accMissingSuffix += $suffix
      Write-Verbose "Missing completely : $suffix"
    }
  }
  $result['Good'] = $accGood
  $result['MissingSuffix'] = $accMissingSuffix
  $result['MissingPT'] = $accMissingPT
  $result['WrongPTValue'] = $accWrongPTValue
  Write-Verbose "Good = $($result['Good'] -join ', ')"
  Write-Verbose "MissingSuffix = $($result['MissingSuffix'] -join ', ')"
  Write-Verbose "MissingPT = $($result['MissingPT'] -join ', ')"
  # Write-Verbose "WrongPTValue = $($result['WrongPTValue'].keys | %{$_  , $result['WrongPTValue'][$_]})" #  $([environment]::NewLine)

  $result['MissingSuffix'] | % {
    $suffix = $_
    if ($PSCmdlet.ShouldProcess("$suffix", 'Will add suffix')) {
      # Add the suffix
      Write-Verbose "add $suffix"
    }
  }
  $result['MissingPT'] | % {
    $suffix = $_
    if ($PSCmdlet.ShouldProcess("$suffix", 'Will add PerceivedType ')) {
      # If 'PerceivedType' is NOT present in the list of all RegKeyVal (s), add a new Key named PerceivedType of type String with Data (value) of 'text
      Write-Verbose "add PerceivedType for $suffix"
    }
  }
  # don't mess with wrong value of 'PerceivedType'
  $result
}
#endregion Set_PerceivedTypeInRegistryForPreviewPane
#############################################################################

