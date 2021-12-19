cd 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\Databases'
$InterfaceListPath = 'ATAPUtilities/Flyway/sql/InterfaceList.txt'
$ClassListPath = 'ATAPUtilities/Flyway/sql/ClassList.txt'
$NamespaceListPath = 'ATAPUtilities/Flyway/sql/NamespacesList.txt'
$AllSourcePath = 'ATAPUtilities/Allsource.txt'

$InterfaceSourceFiles = gci ../src\ATAP.Utilities.GenerateProgram.Interfaces/IG*.cs
$ClassSourceFiles = gci ../src\ATAP.Utilities.GenerateProgram/G*.cs

gci $InterfaceSourceFiles |  %{$_.basename} | Set-Content -path $InterfaceListPath
gci $ClassSourceFiles |  %{$_.basename} | Set-Content -path $ClassListPath

$AllSource = ForEach ($File in $InterfaceSourceFiles,$ClassSourceFiles) {(Get-Content -raw $File)}
$Allsource | set-content -path $AllSourcePath

# [RegEx]$SearchNamespace = '(?sm)^\s*namespace\s+(.*?)(?:\s|\{|$)'
# [RegEx]$ResultNamespace = '$1'
# $NamespaceList = ForEach ($File in $InterfaceSourceFiles,$ClassSourceFiles) {
  # if ((Get-Content -raw $File) -match $SearchNamespace) {$ResultNamespace}
# }
# $NamespaceList | Set-Content -path $NamespaceListPath

