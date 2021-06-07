[CmdletBinding(SupportsShouldProcess = $true)]
param (
  [string]$include = '\.csproj$',
  [string]$path = 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\',
  [string]$exclude = '*.bin,*.obj,*Backup*,*OpenHardwareMonitorLib*',
  [string]$excludeRegEx = '(?:\.bin|\.obj|Backup|OpenHardwareMonitorLib)'
)
Function Replace-InCsproj {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
    [string]$include = '*.csproj',
    [string]$path = 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\',
    [string]$exclude = '*.bin,*.obj,*Backup*,*OpenHardwareMonitorLib*',
    [string]$excludeRegEx = '(?:\.bin|\.obj|Backup|OpenHardwareMonitorLib)'
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


  $replacementlist = (
    #
    (Convert-WhitespaceToRegex([Regex]::Escape(@'
  <PackageReference Include="Microsoft.CodeAnalysis.FxCopAnalyzers" Version="2.9.8">
      <PrivateAssets>all</PrivateAssets>
      <IncludeAssets>runtime; build; native; contentfiles; analyzers; buildtransitive</IncludeAssets>
    </PackageReference>
'@)), "`n`n"), #
    (Convert-WhitespaceToRegex([Regex]::Escape(@'
 <!-- Roslyn Code Analysis -->
  <ItemGroup>
    <PackageReference Include="Microsoft.CodeAnalysis.FxCopAnalyzers" Version="2.9.8"></PackageReference>
  </ItemGroup>
'@)), "`n`n"),

    #
    (Convert-WhitespaceToRegex([Regex]::Escape(@'
 <!-- Roslyn Code Analysis -->
  <ItemGroup>
    <PackageReference Include="Microsoft.CodeAnalysis.FxCopAnalyzers"></PackageReference>
  </ItemGroup>
'@)), "`n`n"),
    #
    (Convert-WhitespaceToRegex([Regex]::Escape(@'
  <!-- Documentation generation -->
  <ItemGroup>
    <PackageReference Include="docfx" Version="2.40.2" />
    <Folder Include="Documentation\" />
  </ItemGroup>
'@)), "`n`n"),
    #
    (Convert-WhitespaceToRegex([Regex]::Escape(@'
  <!-- Documentation generation -->
  <ItemGroup>
    <PackageReference Include="docfx" Version="*" />
    <Folder Include="Documentation\" />
  </ItemGroup>
'@)), "`n`n"),
    #
    (Convert-WhitespaceToRegex([Regex]::Escape(@'
  <!-- Documentation generation -->
  <ItemGroup>
    <PackageReference Include="docfx" />
    <Folder Include="Documentation\" />
  </ItemGroup>
'@)), "`n`n"),
    #
    (Convert-WhitespaceToRegex([Regex]::Escape(@'
  <ItemGroup>
    <PackageReference Include="docfx" Version="2.40.2" />
    <Folder Include="Documentation\" />
  </ItemGroup>
'@)), "`n`n"),
    #
    (Convert-WhitespaceToRegex([Regex]::Escape(@'
  <ItemGroup>
    <Folder Include="Documentation\" />
  </ItemGroup>
'@)), "`n`n"),
    #
    (Convert-WhitespaceToRegex([Regex]::Escape(@'
<PackageReference Include="MedallionShell" Version="1.5.1" />
'@)), "<PackageReference Include=""MedallionShell"" />`n"
    ),
    (Convert-WhitespaceToRegex([Regex]::Escape(@'
<PackageReference Include="ServiceStack.Text" Version="5.8.1" />
'@)), "<PackageReference Include=""ServiceStack.Text"" />`n"
    ),
    (Convert-WhitespaceToRegex([Regex]::Escape(@'
<PackageReference Include="ServiceStack.HttpClient" Version="5.8.1" />
'@)), "<PackageReference Include=""ServiceStack.HttpClient"" />`n"
    ),
    (Convert-WhitespaceToRegex([Regex]::Escape(@'
<PackageReference Include="ServiceStack.Text.EnumMemberSerializer" Version="3.0.0.50044" />
'@)), "<PackageReference Include=""ServiceStack.Text.EnumMemberSerializer"" />`n"
    ),
    (Convert-WhitespaceToRegex([Regex]::Escape(@'
<PackageReference Include="TimePeriodLibrary.NET" Version="2.1.1" />
'@)), "<PackageReference Include=""TimePeriodLibrary.NET"" />`n"
    ),
    (Convert-WhitespaceToRegex([Regex]::Escape(@'
<PackageReference Include="UnitsNet" Version="4.43.0" />
'@)), "<PackageReference Include=""UnitsNet"" />`n"
    ),
    (Convert-WhitespaceToRegex([Regex]::Escape(@'
<PackageReference Include="UnitsNet" Version="4.51.0" />
'@)), "<PackageReference Include=""UnitsNet"" />`n"
    ),
    (Convert-WhitespaceToRegex([Regex]::Escape(@'
<PackageReference Include="UnitsNet" Version="4.52.0" />
'@)), "<PackageReference Include=""UnitsNet"" />`n"
    ),
    (Convert-WhitespaceToRegex([Regex]::Escape(@'
<PackageReference Include="YC.QuickGraph" Version="3.7.4" />
'@)), "<PackageReference Include=""YC.QuickGraph"" />`n"
    ),
    (Convert-WhitespaceToRegex([Regex]::Escape(@'
<PackageReference Include="DotNet.Contracts" Version="1.10.20606.1" />
'@)), "<PackageReference Include=""DotNet.Contracts"" />`n"
    ),
    (Convert-WhitespaceToRegex([Regex]::Escape(@'
<PackageReference Include="FSharp.Core" Version="4.7.1" />
'@)), "<PackageReference Include=""FSharp.Core"" />`n"
    ),
    (Convert-WhitespaceToRegex([Regex]::Escape(@'
<PackageReference Include="FSharpx.Collections.Experimental" Version="1.7.3" />
'@)), "<PackageReference Include=""FSharpx.Collections.Experimental"" />`n"
    ),
    (Convert-WhitespaceToRegex([Regex]::Escape(@'
<PackageReference Include="System.Collections.Immutable" Version="1.7.0" />
'@)), "<PackageReference Include=""System.Collections.Immutable"" />`n"
    ),
    (Convert-WhitespaceToRegex([Regex]::Escape(@'
<PackageReference Include="Newtonsoft.Json" Version="12.0.3" />
'@)), "<PackageReference Include=""Newtonsoft.Json"" />`n"
    ),
    (Convert-WhitespaceToRegex([Regex]::Escape(@'
<PackageReference Include="Microsoft.CSharp" Version="4.7.0" />
'@)), "<PackageReference Include=""Microsoft.CSharp"" />`n"
    ),
    (Convert-WhitespaceToRegex([Regex]::Escape(@'
<PackageReference Include="NLog" Version="4.6.8" />
'@)), "<PackageReference Include=""NLog"" />`n"
    ),
    (Convert-WhitespaceToRegex([Regex]::Escape(@'
<PackageReference Include="NLog.Config" Version="4.6.8" />
'@)), "<PackageReference Include=""NLog.Config"" />`n"
    ),
    (Convert-WhitespaceToRegex([Regex]::Escape(@'
<PackageReference Include="System.Dynamic.Runtime" Version="4.3.0" />
'@)), "<PackageReference Include=""System.Dynamic.Runtime"" />`n"
    ),
    (Convert-WhitespaceToRegex([Regex]::Escape(@'
<PackageReference Include="Polly" Version="6.1.1" />
'@)), "<PackageReference Include=""Polly"" />`n"
    ),
    (Convert-WhitespaceToRegex([Regex]::Escape(@'
<PackageReference Include="Ninject" Version="3.3.4" />
'@)), "<PackageReference Include=""Ninject"" />`n"
    ),
    (Convert-WhitespaceToRegex([Regex]::Escape(@'
<PackageReference Include="System.Reactive" Version="4.3.2" />
'@)), "<PackageReference Include=""System.Reactive"" />`n"
    )
  ) | New-Tuple



  $files = Get-ChildItem $path -Recurse -Include $include -Exclude $exclude | ? { $_.fullname -notmatch $excludeRegex }
  foreach ($fn in $files) {
    $text = [IO.File]::ReadAllText($fn)
    foreach ($kvp in $replacementlist) {
      # replace each
      $text = $text -replace $kvp.Item1, $kvp.Item2
    }
    [IO.File]::WriteAllText($fn, $text)
    #$text
  }

}
Replace-InCsproj
