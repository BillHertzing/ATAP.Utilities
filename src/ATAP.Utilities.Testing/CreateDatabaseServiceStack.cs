using System.Collections.Concurrent;
using System.Data;
using System.Linq;
using System;
using System.Text.Json;
using System.IO;
using System.Reflection;
using Microsoft.Extensions.Configuration;

using ServiceStack;
using ServiceStack.OrmLite;
using ServiceStack.OrmLite.Support;
using ServiceStack.OrmLite.SqlServer;
using ServiceStack.OrmLite.MySql;
using ServiceStack.OrmLite.Sqlite;
using ServiceStack.DataAnnotations;
using ServiceStack.Text;

namespace ATAP.Utilities.Testing {

  public static partial class Extensions {

    public static void CreateDatabaseServiceStack(this IDbConnection db, string databaseName) {

      var provider = db.GetDialectProvider();

      if (provider == null)

        throw new Exception("Invalid IDbConnection, no provider found.");


      var typeOfProvider = provider.GetType();
      switch (typeOfProvider) {

        case { } sqlServerProvider when (
        (sqlServerProvider == typeof(SqlServer2008OrmLiteDialectProvider)) ||
        (sqlServerProvider == typeof(SqlServer2012OrmLiteDialectProvider)) ||
        (sqlServerProvider == typeof(SqlServer2014OrmLiteDialectProvider)) ||
        (sqlServerProvider == typeof(SqlServer2016OrmLiteDialectProvider)) ||
        (sqlServerProvider == typeof(SqlServer2017OrmLiteDialectProvider)) ||
        (sqlServerProvider == typeof(SqlServer2019OrmLiteDialectProvider))):
          // Use all of the defaults of the MSSQLServer instance when creating the database
          db.ExecuteNonQuery(@$"
            IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = '{databaseName}')
            BEGIN
              CREATE DATABASE {databaseName};
            END;");
          // Another way is to call the powershell script New-TestDatabase.ps1 in the ( ToDo:ATAP.Utilities.Testing.Powershell package (currently local))
          //  That script supports a number of command line options, and may be more appropriate depending on the complexity of the database required by the specificTest
          //  ToDo: write another method that takes a multitude of database creation options,
          //  ToDo: write a companion method of providing the argumentsSignil and it's values for the different testing environments, which can be Fluently constructed in the specificTest constructor
          break;
        case { } mySqlProvider when mySqlProvider == typeof(MySqlDialectProvider):
          // Use all of the defaults of the MySQL instance when creating the database
          db.ExecuteNonQuery($"CREATE DATABASE IF NOT EXISTS `{databaseName}`;");
          break;
        case { } sQLiteProvider when sQLiteProvider == typeof(SqliteOrmLiteDialectProvider):
          // ! SQLite creates a database for every connection if the connectionstring specifies :memory: 
          // db.ExecuteNonQuery($"CREATE DATABASE IF NOT EXISTS `{databaseName}`;");
          break;
        default:
          throw new NotSupportedException("CreateDatabaseServiceStack does not yet support {nameof(typeOfProvider)}");
      }
    }

    public static void DeleteDatabaseServiceStack(this IDbConnection db, string databaseName) {
      var provider = db.GetDialectProvider();
      if (provider == null)
        throw new Exception("Invalid IDbConnection, no provider found.");
      var typeOfProvider = provider.GetType();
      switch (typeOfProvider) {
        case { } sqlServerProvider when (
        (sqlServerProvider == typeof(SqlServer2008OrmLiteDialectProvider)) ||
        (sqlServerProvider == typeof(SqlServer2012OrmLiteDialectProvider)) ||
        (sqlServerProvider == typeof(SqlServer2014OrmLiteDialectProvider)) ||
        (sqlServerProvider == typeof(SqlServer2016OrmLiteDialectProvider)) ||
        (sqlServerProvider == typeof(SqlServer2017OrmLiteDialectProvider)) ||
        (sqlServerProvider == typeof(SqlServer2019OrmLiteDialectProvider))):
          // In MSSQL, it is necessary to get exclusive access to a database before it can be deleted
          // /* Query to Get Exclusive Access of SQL Server Database before Dropping the Database  */
          db.ExecuteNonQuery(@$"
            USE [master]
            ALTER DATABASE {databaseName} SET SINGLE_USER WITH ROLLBACK IMMEDIATE
          ");
          // /* Query to Drop Database in SQL Server  */
          db.ExecuteNonQuery(@$"
            USE [master]
            IF EXISTS (SELECT * FROM sys.databases WHERE name = '{databaseName}')
            BEGIN
              DROP DATABASE {databaseName};
            END;
          ");
          // Another way is to call the powershell script New-TestDatabase.ps1 in the ( ToDo:ATAP.Utilities.Testing.Powershell package (currently local))
          //  That script supports a number of command line options, and may be more appropriate depending on the complexity of the database required by the specificTest
          //  ToDo: write another method that takes a multitude of database creation options,
          //  ToDo: write a companion method of providing the argumentsSignil and it's values for the different testing environments, which can be Fluently constructed in the specificTest constructor
          break;
        case { } mySqlProvider when mySqlProvider == typeof(MySqlDialectProvider):
          db.ExecuteNonQuery($"DROP DATABASE {databaseName};");
          break;
        case { } sQLiteProvider when sQLiteProvider == typeof(SqliteOrmLiteDialectProvider):
          // ! SQLite drops the :memory: database when the connnection is closed
          // db.ExecuteNonQuery($"DROP DATABASE {databaseName};");
          break;
        default:
          throw new NotSupportedException("DeleteDatabaseServiceStack does not yet support {nameof(typeOfProvider)}");
      }
    }
  }
}
