# Pester test for an individual Powershell public function in the ATAP.Utilities monorepo
# expects Pester V5

BeforeAll {
  Import-Module -Name Assert
  $datafilePath = 'Get-FileMetadata10.TestData.yml'
  $FileMetadataHashtables = [System.Collections.Generic.List[hashtable]]::new()
  $RawMetadataFromFile = Get-Content $datafilePath -Raw | ConvertFrom-Yaml
  for ($MetadataHashtablesIndex = 0; $MetadataHashtablesIndex -lt $RawMetadataFromFile.Count; $MetadataHashtablesIndex++) {
    $MetadataHashtable = $RawMetadataFromFile[$MetadataHashtablesIndex]
    $FileMetadataHashtables.Add($MetadataHashtable)
  }
}
Describe 'ScriptOrModuleUnderTest' -ForEach @( # ToDo: figure out how to use the $sUTFileName
  @{Name            = 'TagMetadata'
    SourceYamlFile  = 'Get-SidecarHydrusTagging10.TestData.yml'
    ExpectedResults = 0

  }
  , @{Name          = 'DateTimeMetadata'
    SourceYamlFile  = 'Get-SidecarFileEXIFMetadata10.TestData.yml'
    ExpectedResults = 10
  }
) {
  param(
    [string] $Name
    , [string] $SourceYamlFile
    , [Func[PSCustomObject, bool]]  $Delegate
    , [string[]] $ExpectedResults
  )

  BeforeEach {
    $Results = @{}
  }

  It '<name> has the expected value' {
    # Test settings for this specific test case
    if (further -eq 'Continue') {
      Write-Host $name
    }
    if (-not $skipTests) {
    # ToDo: support additional SourceYAMLFiles. For Now, just use the $FileMetadataHashtables collection
    }
  }
}
