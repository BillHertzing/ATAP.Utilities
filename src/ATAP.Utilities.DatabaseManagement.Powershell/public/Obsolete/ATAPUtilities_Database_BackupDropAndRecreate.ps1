# Database drop and create script for the databaseCreator Login and Database

# The account running this script must have permissions to drop/add a Login to the instance, and grant dbCreator to that login
# The account running this script must have permissions to create files in the directories used by this database
# The account must have permissions to set clr-enabled to true

## ToDo comment based help file

# Ensure the dbatools module is loaded
if (!(Get-InstalledModule -Name "dbatools")) {Install-Module -Name "dbatools"}

# ToDo: ensure the Module is the latest

# Get the configuration options
$config = @{};
$config['ServerInstance'] = '::1'
$config['DatabaseName'] = "ATAPUtilities"

$config['PrimaryFilesize'] = 20
$config['PrimaryFileMaxSize'] = 1000
$config['PrimaryFileGrowth'] = 20
$config['DataFilePath'] = "C:\LocalDBs\" + $config['DatabaseName'] + "\Data"
$config['DataFileSuffix'] = "_PRIMARY"
$config['SecondaryFilesize'] = 64
$config['SecondaryFileMaxSize'] = 512
$config['SecondaryFileGrowth'] = 64
$config['SecondaryDataFileSuffix'] = "_MainData"
$config['LogSize'] = 32
$config['LogMaxSize'] = 512
$config['LogGrowth'] = 32
$config['LogFilePath'] = "C:\LocalDBs\" + $config['DatabaseName'] + "\Log"
$config['LogFileSuffix'] = "_Log"
$config['SecondaryDataFileSuffix'] = "_MainData"
$config['RecoveryModel'] = 'Simple'
$config['BackupFilePath'] = 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\Databases\ATAPUtilities\Backups\'
$config['AdminLogin'] = 'AUADMIN'
$config['AdminPassword'] = ConvertTo-SecureString 'NotSecret' -AsPlainText -Force
$config['UserLogin'] = 'AUUSER'
$config['UserPassword'] = ConvertTo-SecureString 'NotSecret' -AsPlainText -Force

# ToDo multiple filegroups
# $DatabaseDataStatementsFileGroupFullPath = "C:\LocalDBs\ATAPUtilities\Data\ATAPUtilities_Statements.mdf"
# $DatabaseLogFileFullPath = "C:\LocalDBs\ATAPUtilities\Log\ATAPUtilities_log.ldf"
# $DatabaseIndexFileFullPath = "C:\LocalDBs\ATAPUtilities\Index\ATAPUtilitiesIDX.mdf"
# $DatabaseIndexStatementsFileGroupFullPath = "C:\LocalDBs\ATAPUtilities\Index\ATAPUtilitiesIDX_Statements.mdf"

# Connect to the database on the server. The serverSMO object is specific for the instance, and the Windows user account running the script
# ToDo Error handling
$serverSMO = Connect-DbaInstance -SqlInstance $config['ServerInstance']


# ToDo: Ensure that the user has permission to delete, create and alter this specific database

# -- Create an Admin login on this instance to be used for access and ddl modifications to this database (db_creator role)
if ((Get-DbaLogin -SqlInstance $serverSMO -Login $config['AdminLogin']) -ne $null) {
  # Delete the existing login
  # ToDo: Error handling
  Remove-DbaLogin -SqlInstance $serverSMO -Login $config['AdminLogin'] -Force >> $null
}
# ToDo: Error handling
New-DbaLogin -SqlInstance $serverSMO -Login $config['AdminLogin'] -SecurePassword $config['AdminPassword'] >> $null
Set-DbaLogin -SqlInstance $serverSMO -Login $config['AdminLogin'] -AddRole 'dbcreator' >> $null

# ensure the Windows account running this script has access rights to the directories/files needed to backup, datadump, and create the database
# ToDo: Add multiple Filegroups and add BCP data directory
# ($config['LogFilePath'], $config['DataFilePath'], $config['BackupFilePath']) | %{$pathNeedingAccess = $_;
  # New-Item -ItemType Directory -Force -Path $pathNeedingAccess
  # $Acl = (Get-Item $pathNeedingAccess).GetAccessControl('Access')
  # $Ar = New-Object System.Security.AccessControl.FileSystemAccessRule("NT SERVICE\MSSQLSERVER", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
  # $Acl.SetAccessRule($Ar)
  # Set-Acl $pathNeedingAccess $Acl
# }

# If the database exists, create backup, make sure the backup works, dump data in BCP format
# ToDo: as database grows, this may need to be optimized
if (Get-DbaDatabase -SqlInstance $serverSMO -Database $config['DatabaseName']) {
  # Kick everyone else off the database
  # ToDo Error handling
  Set-DbaDbState -SqlInstance $serverSMO -Database $config['DatabaseName'] -SingleUser -Force >> $null
  # Drop it safely, (many checks)
  # ToDo Error handling
  Remove-DbaDatabaseSafely -SqlInstance $serverSMO -Database $config['DatabaseName'] -BackupFolder $config['BackupFilePath'] -Force >> $null
}

# Create a new database
# Populate databaseParams from a subset of the configuration parameters of the same name
# Add filegroups
$databaseParams = @{}
@('PrimaryFilesize','PrimaryFileMaxSize','PrimaryFileGrowth','DataFilePath','DataFileSuffix','SecondaryFilesize','SecondaryFileMaxSize',
  'SecondaryFileGrowth','SecondaryDataFileSuffix','LogSize', 'LogMaxSize','LogGrowth','LogFilePath','LogFileSuffix') |
  %{  $databaseParams[$_] = $config[$_]
}
$databaseParams['SqlInstance']= $serverSMO
$databaseParams['Name'] = $config['databaseName']
# ToDo: Error Checking
New-DbaDatabase @databaseParams >> $null
# CREATE DATABASE [$(DatabaseName)]
   # ON PRIMARY(NAME = [$(DatabaseName)], FILENAME = [$(DatabaseDataFileFullPath)], SIZE = 20, MAXSIZE = 1000 MB, FILEGROWTH = 20%)
   # , FILEGROUP ATAPUtilitiesData_STATEMENTS( NAME = ATAPUtilitiesData_STATEMENTS, FILENAME = [$(DatabaseDataStatementsFileGroupFullPath)], SIZE = 20, MAXSIZE = 1000 MB, FILEGROWTH = 20% )
   # , FILEGROUP ATAPUtilitiesIDX_STATEMENTS(  NAME = ATAPUtilitiesIDX_STATEMENTS,     FILENAME = [$(DatabaseIndexStatementsFileGroupFullPath)], SIZE = 20, MAXSIZE = 1000 MB, FILEGROWTH = 20% )
   # LOG ON (NAME = [ATAP.Utilities_log], FILENAME = [$(DatabaseLogFileFullPath)], SIZE = 10, MAXSIZE = 1000 MB, FILEGROWTH = 20 %
  # )
# GO

# -- Required for adding custom Net Common Language Runtime assemblies containing UDFs
Set-DbaSpConfigure -SqlInstance $serversmo -Name 'clr enabled' -Value 1 >> $null

# ToDo: investigate the proper values of these settings:
# sp_dbcmptlevel [$(DatabaseName)], 100
# iif (fulltextserviceproperty(N'IsFulltextInstalled') = 1) {sp_fulltext_database 'enable'}
# The default values for the default Connection settings at the Database Server level
# ANSI_NULLS ON,
# ANSI_NULL_DEFAULT ON,
# QUOTED_IDENTIFIER ON
# ANSI_PADDING ON,
# ANSI_WARNINGS ON,
# # The outcome when variable having a null value is string-concatenated
# CONCAT_NULL_YIELDS_NULL ON,
# Default_Language 'English'
# -- Null Handling follows ANSI standard by default in all scripts
# --ARITHABORT ON,
# -- Create statistics used to improve query execution plans
# --AUTO_CREATE_STATISTICS ON,
# -- allow the DB engine to shrink the sizes of some tables
# --AUTO_SHRINK ON,
# --AUTO_UPDATE_STATISTICS ON,
# --AUTO_UPDATE_STATISTICS_ASYNC OFF,
# -- Leave cursors open after a commit so they can be reused
# --CURSOR_CLOSE_ON_COMMIT OFF,
# -- Declared cursors are local to the database
# --CURSOR_DEFAULT LOCAL,
# --??
# --DATE_CORRELATION_OPTIMIZATION OFF
# --??
# --DISABLE_BROKER
# --??
# --HONOR_BROKER_PRIORITY OFF
# --NUMERIC_ROUNDABORT OFF
# --PAGE_VERIFY NONE,
# --PARAMETERIZATION SIMPLE,
# --READ_COMMITTED_SNAPSHOT OFF
# --RECOVERY SIMPLE
# --TRUSTWORTHY OFF
# --RECURSIVE_TRIGGERS OFF
# --AUTO_CLOSE OFF
# --ALLOW_SNAPSHOT_ISOLATION OFF
# --DB_CHAINING OFF
# --CREATE ROUTE [AutoCreatedLocal]
# --    AUTHORIZATION [dbo]
# --    WITH ADDRESS = N'LOCAL';
# -- DECLARE @VarDecimalSupported AS BIT;
# -- SELECT @VarDecimalSupported = 0;
# -- IF ((ServerProperty(N'EngineEdition') = 3)
  # -- AND (((@@microsoftversion / power(2, 24) = 9)
  # -- AND (@@microsoftversion & 0xffff >= 3024))
  # -- OR ((@@microsoftversion / power(2, 24) = 10)
  # -- AND (@@microsoftversion & 0xffff >= 1600))))
          # -- SELECT @VarDecimalSupported = 1;
# -- IF (@VarDecimalSupported > 0)
          # -- BEGIN
  # -- EXECUTE sp_db_vardecimal_storage_format N'$(DatabaseName)', 'ON';
# -- END
# -- END
# -- GO

# Make this new database the default for the AdminLogin, grant it three roles
Set-DbaLogin -SqlInstance $serverSMO -Login $config['AdminLogin'] -DefaultDatabase $config['DatabaseName']

# ToDo: is a User Login required for ths database? Or just use the Windows account under which the scripts are running?
# if ((Get-DbaLogin -SqlInstance $serverSMO -Login $config['UserLogin']) -ne $null) {
  # # Delete the existing login
  # # ToDo: Error handling
  # Remove-DbaLogin -SqlInstance $serverSMO -Login $config['UserLogin'] -Force >> $null
# }
  # # ToDo: Error handling
  # New-DbaLogin -SqlInstance $serverSMO -Login $config['UserLogin'] -SecurePassword $config['UserPassword'] >> $null

# Now login as the AdminLogin that will be used create this database
# $credentials = New-Object System.Management.Automation.PSCredential ($config['AdminLogin'], $config['AdminPassword']) # Already a secure-string
# $serverSMO = Connect-DbaInstance -SqlInstance $config['ServerInstance'] -SqlCredential $credentials


# Create an Admin user and a normal User for this database
if ((Get-DbaDbUser -SqlInstance $serversmo -Database $config['DatabaseName'] -User $config['AdminLogin']) -ne $null) {
  # Delete the existing login
  # ToDo: Error handling
  Remove-DbaDbUser -SqlInstance $serversmo -Database $config['DatabaseName'] -User $config['AdminLogin'] -Force >> $null
}
# ToDo: Error handling
New-DbaDbUser -SqlInstance $serversmo -Database $config['DatabaseName'] -Username $config['AdminLogin'] >> $null
# DB_owner has full permissions on the DB
Add-DbaDbRoleMember -SqlInstance $serversmo -Database $config['DatabaseName'] -User $config['AdminLogin'] -Role 'db_owner' -Confirm:$false

if ((Get-DbaDbUser -SqlInstance $serversmo -Database $config['DatabaseName'] -User  $config['UserLogin']) -ne $null) {
  # Delete the existing login
  # ToDo: Error handling
  Remove-DbaDbUser -SqlInstance $serversmo -Database $config['DatabaseName'] -User  $config['UserLogin'] -Force >> $null
}
# ToDo: Error handling
New-DbaDbUser -SqlInstance $serversmo -Database $config['DatabaseName'] -Username  $config['UserLogin'] >> $null
Add-DbaDbRoleMember -SqlInstance $serversmo -Database $config['DatabaseName'] -User $config['UserLogin'] -Role 'db_datareader', 'db_datawriter' -Confirm:$false

# Link the AdminLogin to the AdminUser

# ToDo: the database should not be set to Multi-User and opened up until all the migrations are run, this needs to be in a separate script
# Sets the database as MULTI_USER
# ToDo:: Add exception handling
Set-DbaDbState -SqlInstance $serverSMO -Database $config['DatabaseName'] -MultiUser >> $null
