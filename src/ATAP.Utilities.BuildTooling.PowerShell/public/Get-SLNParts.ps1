
######################################################
<#
.SYNOPSIS
Create structured representation of a .sln file
.DESCRIPTION
This utility will create a Powershell Object representing the parts of a SLN file
#Boilerblate
For every InputFilenamePattern below, the utility will look (in the inputdir) for all files that match the pattern, then select the one with the latest FileModifyTime
Every argument below that allows the InputFilenamePattern like '(InFnPatrn1,InFnPatrn2,...,InFnPaternN)', the utility will look (in the inputdir) for all files that match each pattern in the array, then select, for each pattern in the array, the one with the latest FileModifyTime
.PARAMETER InDir
Where the input files reside
Defaults to .\
.PARAMETER OutDir
Where the files created by this utility reside
Defaults to .\outputs
.PARAMETER InFnFilePattern
A pattern for the input file name
Defaults to "\.sln$" which matches all files ending in .sln (Solution files)
It will look (in the inputdir) for all files that match the pattern, then select the one with the latest FileModifyTime
It allows the InputFilenamePattern like '(InFnPatrn1,InFnPatrn2,...,InFnPaternN)', the utility will look (in the inputdir) for all files that match each pattern in the array, then select, for each pattern in the array, the one with the latest FileModifyTime
It will expand any gzipped files that match the input filename pattern
.PARAMETER OutFn
Name of the output file
Defaults to 'Statistic <SLNName> <daterangeofdata>.csv'

.EXAMPLE

# Run this in a Solution directory
# Add this file to a Direcotry ./Build, ensure there is a directory   ./Artifacts
./Build/Get-SLNParts.ps1 -InDir '.' -OutDir './Artifacts' -InFnFilePattern '*.sln' -OutFn ReconstitutedSLN.sln
#>

Function Get-SLNParts {
  [CmdletBinding(SupportsShouldProcess = $true)]
  [CmdletBinding(DefaultParameterSetName = 'Min')]
  Param(
    [parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)] $InDir
    , [alias('InFnFilePattern')]
    [parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)] $InFn1
    , [parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)] $OutDir
    , [alias('OutFn')]
    [parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)] $OutFn1
  )
  $settings = @{
    InDir             = 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities'
    InFnFilePattern   = '.sln$'
    OutDir            = Join-Path $Env:Temp $MyInvocation.MyCommand.Name
    OutFn             = 'slnstructures.txt'
    OrderedProperties = 'Projects,BuildConfigurations'
    Zip7ZipPath       = 'C:\Program Files\7-Zip\7z.exe'
  }
  # Things to be initialized after settings are processed
  if ($InDir) { $Settings.InDir = $InDir }
  if ($InFn1) { $Settings.InFnFilePattern = $InFn1 }
  if ($OutDir) { $Settings.OutDir = $OutDir }
  if ($OutFn1) { $Settings.OutFn = $OutFn1 }
  Write-Verbose "InDir: $($Settings.InDir)"
  Write-Verbose "InFn1: $($Settings.InFn1)"
  Write-Verbose "OutDir: $($Settings.OutDir)"
  Write-Verbose "OutFn1: $($Settings.OutFn1)"

  $DebugPreference = 'Continue'

  # Turn any input file name patterns that are of the form (..[,..]*) into arrays
  if ($settings.InFnFilePattern -match '^\(.*\)$') { $settings.InFnFilePattern = $settings.InFnFilePattern -replace ',', '|' }

  # In and out directory and file validations
  if (-not (Test-Path -Path $settings.InDir -PathType Container)) { throw "$settings.InDir is not a directory" }
  if (-not(Get-ChildItem $settings.InDir | Where-Object { $_ -match $settings.InFnFilePattern })) { throw 'there are no files matching {0} in directory {1}' -f $settings.InFnFilePattern, $settings.InDir }

  # Output tests
  if (-not (Test-Path -Path $settings.OutDir -PathType Container)) {
    # ToDo rewrite to add -Force paramter and don't create a non-existent directory unless -Force is true
    New-Item -ItemType directory -Path $settings.OutDir
  }  # else { throw "$settings.OutDir is not a directory" }
  # Validate that the $Settings.OutDir is writeable
  $testOutFn = $settings.OutDir + 'test.txt'
  try { New-Item $testOutFn -Force -type file >$null }
  catch { #Log('Error', "Can't write to file $testOutFn");
    throw "Can't write to file $testOutFn"
  }
  # Remove the test file
  Remove-Item $testOutFn
  $OutFn = Join-Path $settings.OutDir $settings.OutFn

  # expand any gzipped files that match the input filename pattern
  if (Test-Path $settings.Zip7ZipPath) {
    Set-Alias sz $settings.Zip7ZipPath
  }
  else {
    throw "7z.exe not found at $settings.Zip7ZipPath"
  }
  function Expand-7ZipFile {
    [CmdletBinding()]
    param(
      [parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)] $InFn1
      , [parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)] $OutDir
    )
    $outputOption = "-o$OutDir"
    sz x "$InFn1" $outputOption -r -y
  }
  # list the directory and expand the gzip files
  Get-ChildItem $settings.InDir | Where-Object { $_ -match $settings.InFnFilePattern } | Where-Object { $_.fullname -match '\.gz$' } | % {
    Expand-7ZipFile $_.fullname $settings.InDir
  }

  # get all of the input files to parse
  $filesToProcess = @(Get-ChildItem $settings.InDir | Where-Object { $_ -match $settings.InFnFilePattern } | Where-Object { $_.fullname -notmatch '\.gz$' })

  # create an empty output file, overwrite one if it already exists
  Set-Content -Force $Outfn ''

  # ToDo: Move the next few lines into a library function
  # Set the default output file Encoding and line endings
  #lineEnding
  # [ValidateSet("mac","unix","win")]
  $lineEnding = 'win'
  # Convert the friendly name into a PowerShell EOL character
  Switch ($lineEnding) {
    'mac' { $eol = "`r" }
    'unix' { $eol = "`n" }
    'win' { $eol = "`r`n" }
  }
  # MSBuild sln files seem to be UTF8WithBOM, and *nix line endings
  # UTF8 encoded with a ByteOrdermark(BOM)
  $encoding = New-Object System.Text.UTF8Encoding($true)

  # move this function to a library for reuse
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

  # function to parse one file into the AllParts structure
  function ParseOneSLNFile ($AllParts, $InFn) {

    $OneProject = @{}
    $OneProjectSection = @{}
    $OneGlobal = @{}
    $OneInstance = @{}
    $InstanceID = 0
    $state = 'Top'

    $FileStream = New-Object 'System.IO.FileStream' $InFn, 'Open', 'Read', 'ReadWrite'
    $reader = New-Object 'System.IO.StreamReader' $FileStream
    try {
      while (!$reader.EndOfStream) {
        $l = $reader.ReadLine()

        switch -regex ($state) {
          '^TOP$' {
            switch -regex ($l) {
              '^\s*Project\("\{(?<ParentGUID>[0-9A-Fa-f]{8}-?([0-9A-Fa-f]{4}-?){3}[0-9A-Fa-f]{12})}"\)\s*=\s*(?<NLP>.*?)\s*,\s*"\{(?<ProjectGUID>[0-9A-Fa-f]{8}-?([0-9A-Fa-f]{4}-?){3}[0-9A-Fa-f]{12})}"\s*$' {
                $state = $state + 'Project'
                $OneProject = @{}
                $OneProject.ParentGUID = $matches['ParentGUID']
                $OneProject.NLP = $matches['NLP']
                $OneProject.ProjectGUID = $matches['ProjectGUID']
                break
              }
              '^\s*Global\s*$' {
                $state = $state + 'Global'
                $OneGlobal = [System.Collections.ArrayList]@()
                break
              }
              '^\s*$' { break } # blank line ignored here
              '^\s*(?<MetaLine>.*)\s*$' {
                # Non-Blank line, but not Project nor global
                # $state does not change
                $AllParts.Meta += $matches['MetaLine']
                break
              }
              default {
                Write-Host "in $state state, only Project or Global or blank lines are allowed: $l"
              }
            }break
          }
          '^TOPProject$' {
            switch -regex ($l) {
              '^\s*ProjectSection\((?<TypeOfProjectSection>.*?)\)\s*=\s*(?<PreOrPost>\S*?)\s*$' {
                $state = $state + 'ProjectSection'
                $OneProjectSection = @{}
                $OneProjectSection.TypeOfProjectSection = $matches['TypeOfProjectSection']
                $OneProjectSection.PreOrPost = $matches['PreOrPost']
                $OneProjectSection.SectionItems = [System.Collections.ArrayList]@()
                break
              }
              '^\s*ENDProject\s*$' {
                $state = $state -replace 'Project', ''
                $AllParts.Projects += $OneProject
                break
              }
              '^\s*$' { break } # blank line
              default {
                Write-Host "in $state state, only ProjectSection or EndProject or blank lines are allowed: $l"
              }
            }break
          }
          '^TOPProjectProjectSection$' {
            switch -regex ($l) {
              '^\s*EndProjectSection\s*$' {
                $state = $state -replace 'ProjectSection$', ''
                $OneProject.Sections += $OneProjectSection
                $OneProjectSection = @{}
                break
              }
              '^\s*(?<Name>\S*?)\s*=\s*(?<Location>\S*?)\s*$' {
                $OneProjectSection.SectionItems += New-Tuple $matches['Name'], $matches['Location']
                break
              }
              '^\s*$' { break } # blank line
              default {
                Write-Host "in $state state, only ProjectSection or EndProjectSection or Name = Value Pairs or blank lines are allowed: $l"
              }
            }break
          }
          '^TOPGlobal$' {
            switch -regex ($l) {
              '^\s*ENDGlobal' {
                $state = $state -replace 'Global$', ''
                $AllParts.Global += $OneGlobal
                break
              }
              '^\s*GlobalSection\((?<TypeOfGlobalSection>.*?)\)\s*=\s*(?<PreOrPost>\S*?)\s*$' {
                $state = $state + 'Section'
                $OneGlobalSection = @{}
                $OneGlobalSection.TypeOfGlobalSection = $matches['TypeOfGlobalSection']
                $OneGlobalSection.PreOrPost = $matches['PreOrPost']
                $OneGlobalSection.SectionItems = [System.Collections.ArrayList]@()
                break
              }
              '^\s*$' { break } # blank line
              default {
                Write-Host "in $state state, only GlobalSection or ENDGlobal or blank lines are allowed: $l"
              }
            }break
          }
          '^TOPGlobalSection' {
            switch -regex ($l) {
              '^\s*EndGlobalSection' {
                $state = $state = $state -replace 'Section$', ''
                $OneGlobal += $OneGlobalSection
                break
              }
              '^\s*(?<Name>.*?)\s*=\s*(?<Location>.*?)\s*$' {
                $OneGlobalSection.SectionItems += New-Tuple $matches['Name'], $matches['Location']
                break
              }
              '^\s*$' { break } # blank line
              default {
                Write-Host "in $state state, only EndGlobalSection or blank lines are allowed: $l"
              }
            }break
          }
          '^\s*$' { break } # blank line
          default {
            Write-Host "in $state state, only Project or Global or blank lines are allowed: $l"
          }
        }
      }
    }
    finally {
      $reader.Close()
      $FileStream.Close()
    }
  }

  $ProjectStart = 'Project("{'
  $ProjectPart2 = '}") = '
  $ProjectPart3 = ', "{'
  $ProjectPart4 = '}"'
  $ProjectEnd = 'EndProject'
  $ProjectSectionStart = '  ProjectSection('
  $ProjectSectionPart2 = ') = '
  $ProjectSectionEnd = '  EndProjectSection'
  $ProjectSectionSectionItemStart = '          '
  $ProjectSectionSectionItemPart2 = ' = '
  $GlobalStart = 'Global'
  $GlobalEnd = 'EndGlobal'
  $GlobalSectionStart = 'GlobalSection('
  $GlobalSectionPart2 = ') = '
  $GlobalSectionEnd = 'EndGlobalSection'
  $GlobalSectionSectionItemStart = '    '
  $GlobalSectionSectionItemPart2 = ' = '

  function Out-OneProjectSectionItem {
    Param(
      [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true )]
      $SectionItem,
      [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true )]
      [System.Text.StringBuilder]$mesg
    )
    Process {
      # OneSectionItem has no special string, it just ends with a newline
      $mesg.Append(('{0}{1}{2}{3}{4}' -f $ProjectSectionSectionItemStart, $SectionItem.Item1, $ProjectSectionSectionItemPart2, $SectionItem.Item2, $eol))  > $null
    }
  }

  function Out-OneProjectSection {
    Param(
      [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true )]
      $Section,
      [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true )]
      [System.Text.StringBuilder]$mesg
    )
    Process {
      $mesg.Append(('{0}{1}{2}{3}{4}' -f $ProjectSectionStart, $Section.TypeOfProjectSection, $ProjectSectionPart2, $Section.PreOrPost, $eol))  > $null
      foreach ($SectionItem in $Section.SectionItems) { Out-OneProjectSectionItem $SectionItem $mesg }
      $mesg.Append(('{0}{1}' -f $ProjectSectionEnd, $eol))  > $null
    }
  }

  function Out-OneProject {
    Param(
      [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true )]
      $Project,
      [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true )]
      [System.Text.StringBuilder]$mesg
    )
    Process {
      $mesg.Append(('{0}{1}{2}{3}{4}{5}{6}{7}' -f $ProjectStart, $Project.ParentGUID, $ProjectPart2, $Project.NLP, $ProjectPart3, $Project.ProjectGuid, $ProjectPart4, $eol))  > $null
      foreach ($Section in $Project.Sections) { Out-OneProjectSection $Section $mesg }
      $mesg.Append(('{0}{1}' -f $ProjectEnd, $eol))  > $null
    }
  }

  function Out-Projects {
    Param(
      [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true )]
      [System.Collections.ArrayList] $Projects,
      [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true )]
      [System.Text.StringBuilder]$mesg
    )
    Begin {
      $CustomSortingScriptBlock = { $_.NLP }
    }
    Process {
      # Sort Projects using a custom sort scriptblock
      foreach ($p in ($Projects | Sort-Object -Property $CustomSortingScriptBlock)) { Out-OneProject $p $mesg }
    }
  }

  function Out-OneGlobalSectionItem {
    Param(
      [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true )]
      $SectionItem,
      [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true )]
      [System.Text.StringBuilder]$mesg
    )
    Process {
      $mesg.Append(('{0}{1}{2}{3}{4}' -f $GlobalSectionSectionItemStart, $SectionItem.Item1, $GlobalSectionSectionItemPart2, $SectionItem.Item2, $eol))  > $null
    }
  }

  function Out-OneGlobalSection {
    Param(
      [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true )]
      [System.Collections.ArrayList] $Section,
      [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true )]
      [System.Text.StringBuilder]$mesg
    )
    Process {
      $mesg.Append(('{0}{1}{2}{3}{4}' -f $GlobalSectionStart, $Section.TypeOfGlobalSection, $GlobalSectionPart2, $Section.PreOrPost, $eol)) > $null
      foreach ($SectionItem in $Section.SectionItems) { Out-OneGlobalSectionItem $SectionItem $mesg }
      $mesg.Append(('{0}{1}' -f $GlobalSectionEnd, $eol)) > $null
    }
  }

  function Out-Global {
    Param(
      [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true )]
      [System.Collections.ArrayList] $Global,
      [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true )]
      [System.Text.StringBuilder]$mesg
    )
    Process {
      $mesg.Append(('{0}{1}' -f $GlobalStart, $eol)) > $null
      foreach ($Section in $Global) { Out-OneGlobalSection $Section $mesg }
      $mesg.Append(('{0}{1}' -f $GlobalEnd, $eol)) > $null
    }
  }

  function Out-Meta {
    Param(
      [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true )]
      [System.Collections.ArrayList] $meta,
      [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true )]
      [System.Text.StringBuilder]$mesg
    )
    Process {
      foreach ($metaLine in $meta) { $mesg.Append(('{0}{1}' -f $metaLine, $eol)) > $null }
    }
  }

  function Out-AllParts {
    Param(
      [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true )]
      $AllParts,
      [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true )]
      [System.Text.StringBuilder]$mesg
    )
    Process {
      Out-Meta $AllParts.Meta $mesg
      Out-Projects $AllParts.Projects $mesg
      Out-Global $AllParts.Global $mesg
    }
  }

  # Repeat for every file
  $filestoProcess | ForEach-Object { $fn = $_.fullname
    # Create the AllParts accumulator. Initialize each member as an ArrayList
    $AllParts = @{Meta = [System.Collections.ArrayList]@(); Projects = [System.Collections.ArrayList]@(); Global = [System.Collections.ArrayList]@() }
    # parse the file
    # ToDo: optionaly get the file encoding and EOL characteristics
    ParseOneSLNFile $AllParts $fn
    #ToDo: Optionally validate the input sln file encodings and EOL characteristics match the expected
    # output the data for each solution file as parsing is completed
    # Convert the SLN structure to a string
    $mesg = [System.Text.StringBuilder]::new()
    #ToDo: rewrite output so either a string to a file in the filesystem, or, SQL statements written to a file, or directly doing value inserts into tables in a db.
    Out-AllParts $AllParts $mesg
    # Write the mesg StringBuilder to the output file
    [io.file]::WriteAllText($Outfn, $mesg.ToString(), (New-Object System.Text.UTF8Encoding($true)))
  }
  #***
  # order the properties of the output
  # $partprops = $outobj[0] | select-object | Get-Member -MemberType NoteProperty |%{if($_.Name -notmatch ('^'+(($settings.OrderedProperties -split ',') -join '|'))+'$') {$_.Name}} | sort
  # $allprops = ($settings.OrderedProperties -split ',') + $partprops
  # Select all of the properties, in order as specified. Write all the data as a CSV file, append to the current output file
  #$outobj | select-object -property $allprops | Export-CSV -append -Path $Outfn -NoTypeInformation

}

