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
  $expectedValueOfPerceivedType = 'text'
  if ($suffixesString.Length -eq 0) { throw "The $suffixesString is empty" }
  $suffixes = ($suffixesString.Trim() -split (',')).Trim() | ForEach-Object { '.' + $_ }
  $RegHiveType = [Microsoft.Win32.RegistryHive]::'ClassesRoot'
  $OpenBaseRegKey = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey($RegHiveType, $env:COMPUTERNAME)
  $result = @{}
  $accGood = @();
  $accMissingSuffix = @()
  $accMissingPT = @()
  $accWrongPTValue = @{}
  $suffixes | ForEach-Object { $suffix = $_
    $OpenRegSubKey = $OpenBaseRegKey.OpenSubKey($suffix)
    If ($OpenRegSubKey) {
      # If 'PerceivedType' is NOT present in the list of all RegKeyVal (s), add a new Key named PerceivedType of type String with Data (value) of 'text
      # If 'PerceivedType' IS present in the list of all RegKeyVal (s), and -force is true, ensure it is of type String with Data (value) of 'text'
      # If 'PerceivedType' IS present in the list of all RegKeyVal (s), and -force is false, do nothing to the RegSubKey, accumulate it for output later
      if ($OpenRegSubKey.GetValueNames() -match $perceivedType) {
        $GetPerceivedTypeValue = $OpenRegSubKey.GetValue($perceivedType)
        if ($GetPerceivedTypeValue -eq $expectedValueOfPerceivedType) {
          # This suffix is good
          $accGood += $suffix
          Write-Verbose "Good : $suffix"
        }
        else {
          # the PerceivedType for this suffix is not the $expectedValueOfPerceivedType
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

  # nneed to define an alias for the Classes_Root hive
  New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT > $null
  $result['MissingSuffix'] | ForEach-Object {
    $suffix = $_
    if ($PSCmdlet.ShouldProcess("$suffix", "New-Item -Path HKCR:$suffix")) {
      # Add the suffix
      New-Item -Path "HKCR:$suffix" > $null
    }
  }
  # All that were MissingSuffix will also now be MissingPT, so add MissingSuffix to MissingPT
  $finalMissingPT = $result['MissingSuffix'] + $result['MissingPT'] 

  $finalMissingPT | ForEach-Object {
    $suffix = $_
    if ($PSCmdlet.ShouldProcess(($suffix, $perceivedType, $expectedValueOfPerceivedType), "New-ItemProperty -Path HKCR:$suffix -Name $perceivedType -Value $expectedValueOfPerceivedType")) {
      # If $perceivedType is NOT present in the list of all RegKeyVal (s), add a new item named $perceivedType of type String with Data (value) of $expectedValueOfPerceivedType
      New-ItemProperty -Path "HKCR:$suffix" -Name $perceivedType -Value $expectedValueOfPerceivedType
      Write-Verbose "add PerceivedType for $suffix"
    }
  }
  # don't mess with wrong value of 'PerceivedType'
  $result
}
#endregion Set_PerceivedTypeInRegistryForPreviewPane
#############################################################################

