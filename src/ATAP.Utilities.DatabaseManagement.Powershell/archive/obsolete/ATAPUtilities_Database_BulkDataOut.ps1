# Export all tables to BCP, in directory structure that matches the BulkDataIn script for this database
# Attribution: https://www.red-gate.com/hub/product-learning/flyway/bulk-loading-data-via-a-powershell-script-in-flyway
# modified breaking change, name of subdir where migrations are stored from Scripts to sql

# The account running this script must have permissions to create files in the directories used by this database

## ToDo comment based help file
# Get the configuration options
$config = @{};
$config['ServerInstance'] = '::1'
$config['DatabaseName'] = "ATAPUtilities"
$config['ProjectFolder'] = 'Flyway'  

$config['RecoveryModel'] = 'Simple'
$config['BackupFilePath'] = 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\Databases\ATAPUtilities\Backups\'
$config['AdminLogin'] = 'AUADMIN'
$config['AdminPassword'] = ConvertTo-SecureString 'NotSecret' -AsPlainText -Force
$config['UserLogin'] = 'AUUSER'
$config['UserPassword'] = ConvertTo-SecureString 'NotSecret' -AsPlainText -Force

$Details = @{
    'server' = $config['ServerInstance']; #The Server name in a connection string
    'database' = $config['DatabaseName']; #The Database
    'uid' = $config['AdminLogin']; #The User ID. you only need this if there is no domain authentication or secrets store #>
    'pwd' = 'NotSecret'; # The password. This gets filled in if you request it
    'ProjectFolder'=$config['ProjectFolder'] ;#The folder containing the project
    'version' = ''; # TheCurrent Version. This gets filled in if you request it
    'Warnings' = @{ }; # Just leave this be. Filled in for your information
    'Problems' = @{ }; # Just leave this be. Filled in for your information
    'Locations' = @{ }; # Just leave this be. Filled in for your information
}
# add a bit of error-checking. Is the project directory there
if (-not (Test-Path "$($Details.ProjectFolder)"))
{ Write-Error "Sorry, but I couldn't find a project directory at the $($Details.ProjectFolder) location" }
# ...and is the script directory there?
if (-not (Test-Path "$($Details.ProjectFolder)\sql"))
{ Write-Error "Sorry, but I couldn't find a sql directory at the $($Details.ProjectFolder)\sql location" }
pushd
cd "$($details.ProjectFolder)\sql"
. ..\..\..\DatabaseBuildAndMigrateTasks.ps1 -Verbose
# now we use the scriptblock to determine the version number and name from SQL Server
$Details.problems=@{}
Process-FlywayTasks $Details  @(
#$FetchAnyRequiredPasswords, #deal with passwords
$GetCurrentVersion, #access the database to work out the current version
$BulkCopyOut #now write out the contents of all the tables
)
popd
$Details | format-table
