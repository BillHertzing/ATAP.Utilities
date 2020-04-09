
######################################################
<#
.SYNOPSIS
Create structured representation of a .sln file
.DESCRIPTION
This utility will create
For every InputFilenamePattern below, the utility will look (in the inputdir) for all files that match the pattern, then select the one with the latest FileModifyTime
Every argument below that allows the InputFilenamePattern like '(InFnPatrn1,InFnPatrn2,...,InFnPaternN)', the utility will look (in the inputdir) for all files that match each pattern in the array, then select, for each pattern in the array, the one with the latest FileModifyTime
.PARAMETER InDir
Where the input files reside
Defaults to .\
.PARAMETER OutDir
Where the files created by this utility reside
Defaults to .\outputs
.PARAMETER InFnFilePattern
An pattern for the input file name
Defaults to "\.sln$" which matches all files ending in .sln (Solution files)
.PARAMETER OutFn
Name of the output file
Defaults to 'Statistic <SLNName> <daterangeofdata>.csv'

.EXAMPLE
#Always use the cd command to change to the directory where the data file lives
cd 'c:\temp'
#
.\Get-PCACaptureData.ps1 -InDir '.\Inputs' -OutDir '.\Outputs' -InFnFilePattern 'Statistics.log'-OutFn Statistics.csv # For Sales
#>


[CmdletBinding(DefaultParameterSetName='Min')]
Param(
  [parameter(ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)] $InDir
  ,[alias('InFnFilePattern')]
  [parameter(ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)] $InFn1
  ,[parameter(ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)] $OutDir
  ,[alias('OutFn')]
  [parameter(ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)] $OutFn1
)
$settings=@{
  InDir = 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities'
  InFnFilePattern = '\.sln$'
  OutDir = 'D:\Temp\GenerateProgram'
  OutFn = 'slnstructures.txt'
  OrderedProperties = 'Projects,BuildConfigurations'
  Zip7ZipPath = 'C:\Program Files\7-Zip\7z.exe'
}
# Things to be initialized after settings are processed
if ($InDir) {$Settings.InDir = $InDir}
if ($InFn1) {$Settings.InFnFilePattern = $InFn1}
if ($OutDir) {$Settings.OutDir = $OutDir}
if ($OutFn1) {$Settings.OutFn = $OutFn1}

$DebugPreference = 'Continue'

# Turn any input file name patterns that are of the form (..[,..]*) into arrays
if ($settings.InFnFilePattern -match '^\(.*\)$') {$settings.InFnFilePattern = $settings.InFnFilePattern -replace ',','|'}

# In and out directory and file validations
if (-not (test-path -path $settings.InDir -pathtype Container)) {throw "$settings.InDir is not a directory"}
if (-not(ls $settings.InDir | ?{$_ -match $settings.InFnFilePattern })) {throw "there are no files matching {0} in directory {1}" -f $settings.InFnFilePattern,$settings.InDir}

# Output tests
if (-not (test-path -path $settings.OutDir -pathtype Container)) {throw "$settings.OutDir is not a directory"}
# Validate that the $Settings.OutDir is writeable
$testOutFn = $settings.OutDir + 'test.txt'
try {new-item $testOutFn -force -type file >$null}
catch {#Log('Error', "Can't write to file $testOutFn");
throw "Can't write to file $testOutFn"}
# Remove the test file
Remove-Item $testOutFn
$OutFn = join-path $settings.OutDir $settings.OutFn

# expand any gzipped files that match the input filename pattern
if (test-path $settings.Zip7ZipPath) {
  set-alias sz $settings.Zip7ZipPath
} else {
  throw "7z.exe not found at $settings.Zip7ZipPath"
}
function Expand-7ZipFile {
  [CmdletBinding()]
  param(
    [parameter(ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)] $InFn1
    ,[parameter(ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)] $OutDir
  )
  $outputOption = "-o$OutDir"
  sz x "$InFn1" $outputOption -r -y
}
# list the direcotry and expand the gzip files
ls $settings.InDir | ?{$_ -match $settings.InFnFilePattern } | ?{$_.fullname -match '\.gz$'} | %{
  Expand-7ZipFile $_.fullname $settings.InDir
}

# get all of the solution file to parse
$filesToProcess = @(ls $settings.InDir | ?{$_ -match $settings.InFnFilePattern } | ?{$_.fullname -notmatch '\.gz$'})

# create an empty output file, overwrite one if it already exists
set-content -force $Outfn ''

# move this function to a library for reuse
function New-Tuple { #https://stackoverflow.com/questions/54373785/tuples-arraylist-of-pairs
    Param(
        [Parameter(
            Mandatory=$true,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true
        )]
        [ValidateCount(2,20)]
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
    $InstanceID=0
    $state='Top'

    $lines = gc $InFn

    $lines | %{$l=$_;
      switch -regex ($state) {
        '^TOP$' {
          switch -regex ($l) {
          '^\s*Project\("\{(?<ParentGUID>[0-9A-Fa-f]{8}-?([0-9A-Fa-f]{4}-?){3}[0-9A-Fa-f]{12})}"\)\s*=\s*(?<NLP>.*?)\s*,\s*"\{(?<ProjectGUID>[0-9A-Fa-f]{8}-?([0-9A-Fa-f]{4}-?){3}[0-9A-Fa-f]{12})}"\s*$' {
            $state= $state+'Project'
            $OneProject = @{}
            $OneProject.ParentGUID = $matches['ParentGUID']
            $OneProject.NLP = $matches['NLP']
            $OneProject.ProjectGUID = $matches['ProjectGUID']
            break
          }
          '^\s*Global\s*$' {
            $state=$state+'Global'
            $OneGlobal = @()
            break
          }
          '^\s*$' {break} # blank line ignored here
          default {
            write-host "in $state state, only Project or Global or blank lines are allowed: $l"
          }
          }break}
        '^TOPProject$' {
          switch -regex ($l) {
            '^\s*ProjectSection\((?<TypeOfProjectSection>.*?)\)\s*=\s*(?<PreOrPost>\S*?)\s*$' {
              $state =  $state+'ProjectSection'
              $OneProjectSection = @{}
              $OneProjectSection.TypeOfProjectSection = $matches['TypeOfProjectSection']
              $OneProjectSection.PreOrPost = $matches['PreOrPost']
              $OneProjectSection.SectionItems = @()
              break
            }
            '^\s*ENDProject\s*$' {
              $state = $state -replace 'Project',''
              $AllParts.Projects += $OneProject
              break
            }
            '^\s*$' {break} # blank line
            default {
              write-host "in $state state, only ProjectSection or EndProject or blank lines are allowed: $l"
            }
          }break}
        '^TOPProjectProjectSection$' {
          switch -regex ($l) {
            '^\s*EndProjectSection\s*$' {
              $state =  $state -replace 'ProjectSection$',''
              $OneProject.Sections += $OneProjectSection
              $OneProjectSection = @{}
              break
            }
            '^\s*(?<Name>\S*?)\s*=\s*(?<Location>\S*?)\s*$' {
              $OneProjectSection.SectionItems += New-Tuple $matches['Name'],$matches['Location']
              break
            }
            '^\s*$' {break} # blank line
            default {
              write-host "in $state state, only ProjectSection or EndProjectSection or Name = Value Pairs or blank lines are allowed: $l"
            }
          }break}
        '^TOPGlobal$' {
          switch -regex ($l) {
            '^\s*ENDGlobal' {
              $state = $state -replace 'Global$',''
              $AllParts.Global += $OneGlobal
              break
            }
            '^\s*GlobalSection\((?<TypeOfGlobalSection>.*?)\)\s*=\s*(?<PreOrPost>\S*?)\s*$' {
              $state = $state + 'Section'
              $OneGlobalSection = @{}
              $OneGlobalSection.TypeOfGlobalSection = $matches['TypeOfGlobalSection']
              $OneGlobalSection.PreOrPost = $matches['PreOrPost']
               $OneGlobalSection.SectionItems = @()
              break
            }
            '^\s*$' {break} # blank line
            default {
              write-host "in $state state, only GlobalSection or ENDGlobal or blank lines are allowed: $l"
            }
          }break}
        '^TOPGlobalSection' {
          switch -regex ($l) {
            "^\s*EndGlobalSection" {
              $state = $state = $state -replace 'Section$',''
              $OneGlobal += $OneGlobalSection
              break
            }
            '^\s*(?<Name>.*?)\s*=\s*(?<Location>.*?)\s*$' {
              $OneGlobalSection.SectionItems += New-Tuple $matches['Name'],$matches['Location']
              break
            }
            '^\s*$' {break} # blank line
            default {
              write-host "in $state state, only EndGlobalSection or blank lines are allowed: $l"
            }
          }break}
        '^\s*$' {break} # blank line
        default {
          write-host "in $state state, only Project or Global or blank lines are allowed: $l"
        }
      }
  }
}



function AllPartstruct-OutObj ($AllParts,$outobj,$PCAId) {
    $AllParts.keys|sort|%{$dts = $_
      $onestat=$AllParts.$dts
      $onestat.Instances.keys | sort | %{$IID=$_
        $onerow=@{"DTS"=$dts;"PCAId"=$PCAId;"InstanceID"=$IID}
        $instance=$onestat.Instances.($IID)
        $instance.keys | sort | %{$value=$_
          $onerow.($Value) = $instance.$value
        }
        $outobj += (New-Object PSObject -Property $onerow)
    }}
}



# Repeat for every file
$filestoProcess | %{$fn = $_.fullname
   # Create the AllParts accumulator.
  $AllParts=@{Projects=@();Global=@()}
  # Get the PCA name from the name of the statstics file
  $SLNName=$fn.basename
  # parse the file
  ParseOneSLNFile $AllParts $fn
  # output the data for each solution file as it is parsed
  $outobj = @()
  AllPartstruct-OutObj $AllParts $outobj $SLNName
  # order the properties of the output
  $partprops = $outobj[0] | select-object | Get-Member -MemberType NoteProperty |%{if($_.Name -notmatch ('^'+(($settings.OrderedProperties -split ',') -join '|'))+'$') {$_.Name}} | sort
  $allprops = ($settings.OrderedProperties -split ',') + $partprops
  # Select all of the properties, in order as specified, Write all the data as a CSV file, append to the current output file
  $outobj | select-object -property $allprops | Export-CSV -append -Path $Outfn -NoTypeInformation
 }




#$AllParts.keys | sort | %{$_; $k = $_; $onestat = $AllParts.$k; $onestat.Keys | sort | %{$_; $k=$_; $onesection = $onestat.$k; $onesection.keys| sort | %{$_; $k = $_; }}}
#set-content $OutFn ($AllParts.keys | sort | %{$dts = $_; $onestat = $AllParts.$dts; $onestat.Instances.keys | sort | %{$IID=$_; $instance = $onestat.Instances.($IID); $instance.keys| sort | %{"{0}, {1}, {2}, {3}" -f $dts,$IID,$_,$instance.$_}}})

#iex $program

<#

  $StatisticsFileProperties =  @('LocalTimeUtc','Instance ID','Process ID','Peer ID','TotalHitsQueued','TotalHitsDelivered','CaptureBytesWrittenByListener','CaptureBytesWrittenByRouter','CaptureBytesReadFromListener','HitsCaptured','HitsRejectedHits','HitsTotalCaptureType1','HitsTotalDroppedBusinessModeExtension','HitsTotalDroppedBusinessModeResponse','HitsTotalDroppedByDelimagesFeature','HitsTotalDroppedInvalidMethod','HitsTotalDroppedBySampling','SslCurrentHitsPerSec','TcpUnidirectionalTrafficPercentage')
  $StatisticsFileStructureProperties =  @('Instance ID=(\d+)','Process ID','Peer ID')

#The structure of the solution file, described in a string. top is special
$top='Statistics'
$sfs = @'
Statistics=General,CoreDumps,Delivery,Failover,Instances,ProcessClasses,Processes,Time
General=
CoreDumps=CoreDump
CoreDump=
Delivery=Peer
Failover=
Peer=Host,TotalHitsQueued,TotalHitsDelivered,TotalHitsDropped
Instances=Instance
Instance=Capture,Hits,Memory,SSL,TCP,Time
Capture=CapturePacketsDroppedByPcap,CaptureBytesReadFromListener,CapturePacketsDroppedInOutputAtListend,CapturePacketsDroppedInOutputAtRouterd,CaptureCurrentFilteredKbytesPerSec
Hits=HitsCaptured,HitsRejectedHitsHitsUndeliveredHitsWhilePassive
Memory=
SSL=SslTotalNewHandshakes,SslTotalResumedHandshakes,SslHitCount,SslTotalUnknownCipherErrors,SslTotalEphemeralRsaConnections,SslTotalDhCipherConnections
TCP=TcpTotalPacketsRcvdAtRouterd,TcpTotalPacketsRcvd,TcpUnidirectionalTrafficPercentage,TcpAlienPacketsRcvd,TcpTotalDuplicatePackets
Time=LocalTimeSecondsUtc,LocalTimeUtc
ProcessClasses=ProcessClass
ProcessClass=
Processes=Process
Process=
Time=LocalTimeSecondsUtc,LocalTimeUtc
'@

$sfs = @'
Statistics=General
General=
CoreDumps=CoreDump
CoreDump=
Delivery=Peer
Failover=
Peer=Host,TotalHitsQueued,TotalHitsDelivered,TotalHitsDropped
Instances=Instance
Instance=Capture,Hits,Memory,SSL,TCP,Time
Capture=CapturePacketsDroppedByPcap,CaptureBytesReadFromListener,CapturePacketsDroppedInOutputAtListend,CapturePacketsDroppedInOutputAtRouterd,CaptureCurrentFilteredKbytesPerSec
Hits=HitsCaptured,HitsRejectedHitsHitsUndeliveredHitsWhilePassive
Memory=
SSL=SslTotalNewHandshakes,SslTotalResumedHandshakes,SslHitCount,SslTotalUnknownCipherErrors,SslTotalEphemeralRsaConnections,SslTotalDhCipherConnections
TCP=TcpTotalPacketsRcvdAtRouterd,TcpTotalPacketsRcvd,TcpUnidirectionalTrafficPercentage,TcpAlienPacketsRcvd,TcpTotalDuplicatePackets
Time=LocalTimeSecondsUtc,LocalTimeUtc
ProcessClasses=ProcessClass
ProcessClass=
Processes=Process
Process=
Time=LocalTimeSecondsUtc,LocalTimeUtc
'@

$haskids=('Statistics','CoreDumps','Delivery','Instances','Instance','ProcessClasses','Processes')


function buildvalues ($st) {
  $values=(($sfs -split "`r`n") | ?{$_ -match "$st"}) -split ','
  $values[0] = $values[0] -replace "$st=",''
  $values | %{ "^\s+VALUE\s+$_\s+(.*)$ {$_=$matches[1]}" }
}
function buildnextlevel ($st) {
  "^\s+BEGIN\s+$st\s {$state+=$state$st"
  $KidsOrValues = getKidsOrValues $st
  if (($KidsOrValues.count -eq 0) -or (($KidsOrValues.count -eq 1) -and (-not $KidsOrValues[0]))) {
    '}'
    return
  }
  if ($haskids -notcontains $st) {buildvalues $st; '}'}
  getKidsOrValues $st | %{buildnextlevel $_; '}'}
}

function getKidsOrValues ($st) {
  $kovs=(($sfs -split "`r`n") | ?{$_ -match "^$st"}) -split ','
  $kovs[0] = $kovs[0] -replace "$st=",''
  @($kovs)
}

# Build the levels
$program = '$lines[0..100] | %{$l=$_;'+ @'
if ($state -eq 'Top') {
  if ($l -match "^\s+BEGIN\s+$top\s*") {
    $state=$state+$top
    $OneStat = @{}
  }
} elseif ($state -eq ('Top'+$top)) {
  if ($l -match "^\s+END\s+$top\s*") {
    $state -eq 'Top'
    $AllParts.($OneStat.Time.LocalTimeSecondsUtc) = $OneStat
  } else {
    switch -regex ($l) {
'@
$str = (getKidsOrValues $top | %{buildnextlevel $_})
#+ (getKidsOrValues $top | %{buildnextlevel $_})
#+ '}}}}'


$Statistics
# Get the property hash and the Regex
$s=PropHashAndRegex($StatisticsFileProperties)
$PropHash=$s[0];$PropNameRegex=$s[1];
$StructuredPropertiesRegex=[regex] ('(' + ($StatisticsFileStructureProperties -join '|') +')')
$RowEndKey= 'LocalTimeUtc'

    $ConvertedRows=@{}
    $ThisRow=@{}
    $ThisSubLevel=$ThisRow
    $t = (get-content $inFn).where{$_ -match $PropNameRegex}
    $t |
      # evaluate the line again against every property Regex to find which property matched,
      %{$l=$_;$PropHash.Keys |
        %{$k=$_; if ($l -match $PropHash.$k) {
          # If this is a peer, process, or instance line, add another level to the row and break out of the property evaluation loop
          if ($k -match $StructuredPropertiesRegex) {
            $ThisRow.($Matches[1..2] -join ' ')=@{}; $ThisSubLevel=$ThisRow.($Matches[1..2] -join ' ')
          } else {
            # push the value into the accumulator hash and break out of the property evaluation loop
            $ThisSubLevel.$k = $Matches[1];
            if ($k -eq $RowEndKey) {$ConvertedRows.($Matches[2]) += $ThisRow; $ThisRow=@{};$ThisSubLevel=$ThisRow}
          }
        }
      }
    }
  #@

    # Write the data out to a CSV file, in column order as specified in the $RequestBlockProperties list,
    #  and converting the RequestTimeEx to a standard datetime string format useable by Excel pivot tables
    $ConvertedRows | %{$thisrow=$_;
      $ConvertedRow = New-Object PSObject;
      $StatisticsFileProperties | %{$prop=$_;
        if ($prop -eq 'LocalTimeUtc') {
          $dts = Convert-TealeafDate $thisrow.$prop
          if (-not $dts) {throw "unrecognized datetime format: $thisrow.$prop"}
          Add-Member $prop $dts.ToString('MM/dd/yyyy HH:mm:ss') -InputObject $ConvertedRow
        } else {
          Add-Member $prop $thisrow.$prop -InputObject $ConvertedRow
        }
      }
      $ConvertedRow
    } |
    export-csv $OutFullname -NoTypeInformation -Force




#Get instance 0 and timestamps and packets dropped

#>
