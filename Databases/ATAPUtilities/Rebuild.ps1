 ./SetEnvVarsDev.ps1
#sqlcmd -E -i 'Databases/ATAPUtilities/ATAPUtilities_Database_BackupAndExport.sql'
# sqlcmd -E -i 'Databases/ATAPUtilities/ATAPUtilities_Database_DropAndRecreate.sql'
./ATAPUtilities_Database_BackupDropAndRecreate.ps1
Flyway migrate
