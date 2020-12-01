
$solutionDir = 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\'
$baseprefixCompany = 'ATAP'
$baseprefixRepository = 'Utilities'
$BasePrefix = "{0},{1}" -f $baseprefixCompany, $baseprefixRepository
$ProjectDirList = @('ComputerInventory','ComputerInventory.Enumerations.Hardware','ComputerInventory.Interfaces.Hardware', 'ComputerInventory.Models.Hardware')
$enumerationsNames = @('CPUMaker','CPUSocket','DiskDriveMaker','DiskDriveType','GPUMaker','MainBoardMaker', 'PartitionFileSystem','VideocardMaker','VideoCardMemoryMaker')
$ProjectToEnumerationMapping = %{'ComputerInventory.Enumerations.Hardware','Enumerations.Hardware.cs', $enumerationsNames}

$classAndInterfaceBaseNames = @('CPU','CPUSignil','DiskDrive','DiskDriveSignil', 'MainBoard', 'MainBoardSignil')
$classInterfaceaccess = 
{'DiskDriveSignil',{DiskDriveMaker,DiskDriveType,[UnitsNet.Information, InformationSize }

$UnitTestGenerators
$EnumerationsSerializationUnitTestAndTestDataGenerator

$InitialPath = $SolutionDir
cd $InitialPath
$code = '';
foreach ($class in $classesToGenerate) {


$code | set-content -Path 

}
.\dotnet build