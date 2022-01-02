[System.Environment]::SetEnvironmentVariable('FLYWAY_DRIVER','com.microsoft.sqlserver.jdbc.SQLServerDriver',[System.EnvironmentVariableTarget]::User);
[System.Environment]::SetEnvironmentVariable('FLYWAY_URL','jdbc:sqlserver://localhost:1433',[System.EnvironmentVariableTarget]::User);
[System.Environment]::SetEnvironmentVariable('FLYWAY_USER','AUADMIN',[System.EnvironmentVariableTarget]::User);
[System.Environment]::SetEnvironmentVariable('FLYWAY_PASSWORD','pass',[System.EnvironmentVariableTarget]::User);
[System.Environment]::SetEnvironmentVariable('FLYWAY_LOCATIONS','filesystem:C:\Dropbox\whertzing\GitHub\ATAP.Utilities\Databases\ATAPUtilities\Flyway\sql',[System.EnvironmentVariableTarget]::User);
[System.Environment]::SetEnvironmentVariable('FLYWAY_CREATESCHEMAS','true',[System.EnvironmentVariableTarget]::User);
[System.Environment]::SetEnvironmentVariable('FLYWAY_SCHEMAS','dbo',[System.EnvironmentVariableTarget]::User);
