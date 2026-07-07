# Overview of the database design within ATAP Utilities

## Using the community DBATools

The ATAP Utilities make widespread use of the dbaTools powershell module.

## connecting to a database

A DatabaseConnectionString is used to connect a process to a database. It defines the criteria used to make a connection.

### DatabaseConnectionStringBuilder object

A DatabaseConnectionString is created by calling the .ToString() method on a DatabaseConnectionStringBuilder object.

The cmdlet New-ConnectionStringBuilderFromDbaTools from the ATAP.Utilities.DatabaseManagement.Powershell module returns a DatabaseConnectionStringBuilder object.

## Defining the fields of a connection

the cmdlet New-ConnectionStringBuilderFromDbaTools has a large number of parameter sets, to describe the many ways of connecting to a SQL Server database instance.

DatabaseName - the name of the database

Environment - 'Production', 'QA', 'Integration', 'Development', 'Experimental'. This drives the value of SqlInstance

SqlInstance - the shared named instances are 'localhost\Production', 'localhost\QA', and 'localhost\Integration', corresponding to the Production, QA, and Integration environments. Development and Experimental use developer-specific instances.

DatabaseServer (Alias 'HostName') - the resolvable name that identifies the computer address to use

ConnectionMethod - tcp, namedpipes, etc.

Integrated Security - flag, if true, `ToString` wont add a password to the connectionstring

IsJDBC - flag, if true, ToString will return a jdbc driver formatted connection string

Trust

CredentialsKey - a string that identifies a secret in the active Secretvault. ATAP.Utilities currently has single vault, but future features may support multiple vaults. If CredentialsKey is not null after getting the configuration settings, it overrides
many of the other parameters. After fetching credentials from the vault, the following fields may be defined in the returned value, and if present, override parameter values for the following

DatabaseServer
SqlInstance
DatabaseName
ConnectionMethod
IntegratedSecurity
UserName
UserPassword

The poowershell snippet file
