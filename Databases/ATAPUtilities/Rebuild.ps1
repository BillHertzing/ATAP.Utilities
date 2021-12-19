sqlcmd -U 'sa' -P 'NotSecret' -i 'Databases/ATAPUtilities/ATAPUtilities_Database_BackupAndExport.sql'
sqlcmd -U 'sa' -P 'NotSecret' -i 'Databases/ATAPUtilities/ATAPUtilities_Database_DropAndRecreate.sql'
Flyway migrate
