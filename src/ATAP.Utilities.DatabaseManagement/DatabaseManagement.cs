using System;
using System.Threading;
using ServiceStack.OrmLite;

namespace ATAP.Utilities.DatabaseManagement
{
    public class DatabaseManagement
    {
    }


  public class ConnectViaORMData : IConnectViaORMData {

    public ConnectViaORMData(string dBConnectionString, IOrmLiteDialectProvider ormLiteDialectProvider, bool setGlobalDialectProvider, string databaseName, CancellationToken cancellationToken) {
      DBConnectionString = dBConnectionString ?? throw new ArgumentNullException(nameof(dBConnectionString));
      OrmLiteDialectProvider = ormLiteDialectProvider ?? throw new ArgumentNullException(nameof(ormLiteDialectProvider));
      SetGlobalDialectProvider = setGlobalDialectProvider;
      DatabaseName = databaseName ?? throw new ArgumentNullException(nameof(databaseName));
    }

    public string DBConnectionString { get; }
    public IOrmLiteDialectProvider OrmLiteDialectProvider { get; }
    public bool SetGlobalDialectProvider { get; }
    public string DatabaseName { get; }
  }

  public class ConnectViaORMResults : IConnectViaORMResults {
    protected ConnectViaORMResults() : this(false) { }

    protected ConnectViaORMResults(bool success) {
      Success = success;
    }

    public bool Success { get; set; }

  }
  public class CreateDatabaseResults : ICreateDatabaseResults {
    protected CreateDatabaseResults() : this(false) { }

    protected CreateDatabaseResults(bool success) {
      Success = success;
    }

    public bool Success { get; set; }

  }

}

/*
 * CREATE USER [whertzing]
	WITHOUT LOGIN
	WITH DEFAULT_SCHEMA = dbo

GO

GRANT CONNECT TO [whertzing]

*/
