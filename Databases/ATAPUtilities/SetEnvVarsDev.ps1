
[System.Environment]::SetEnvironmentVariable('Environment','Development',[System.EnvironmentVariableTarget]::User)
[System.Environment]::SetEnvironmentVariable('ATAPUtilitiesVersion','PlaceholderRepositoryGitVersionOfBuildSchema',[System.EnvironmentVariableTarget]::User)

[System.Environment]::SetEnvironmentVariable('FLYWAY_URL','jdbc:sqlserver://localhost:1433;databaseName=ATAPUtilities',[System.EnvironmentVariableTarget]::User)
[System.Environment]::SetEnvironmentVariable('FLYWAY_USER','AUADMIN',[System.EnvironmentVariableTarget]::User)
[System.Environment]::SetEnvironmentVariable('FLYWAY_LOCATIONS','filesystem:C:\Dropbox\whertzing\GitHub\ATAP.Utilities\Databases\ATAPUtilities\Flyway\sql',[System.EnvironmentVariableTarget]::User)
[System.Environment]::SetEnvironmentVariable('FLYWAY_PASSWORD','NotSecret',[System.EnvironmentVariableTarget]::User)

# Attribution: https://www.red-gate.com/hub/product-learning/flyway/bulk-loading-data-via-a-powershell-script-in-flyway?topic=database-builds&product=flyway

[System.Environment]::SetEnvironmentVariable('FP__projectName','ATAPUtilities',[System.EnvironmentVariableTarget]::User)
[System.Environment]::SetEnvironmentVariable('FP__projectDescription','Test Flyway and Pubs samples',[System.EnvironmentVariableTarget]::User)

