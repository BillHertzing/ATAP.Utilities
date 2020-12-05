using System;
using System.Collections.Generic;
using System.Data;
using System.Threading;
using ATAP.Utilities.Persistence;
using ServiceStack.OrmLite;

namespace ATAP.Utilities.Persistence {

  public interface ISetupViaORMData {
    string DBConnectionString { get; }
    IOrmLiteDialectProvider Provider { get; }
    bool SetGlobalDialectProvider { get; }
  }
  public class SetupViaORMData : SetupDataAbstract, ISetupViaORMData {
    public SetupViaORMData(string dBConnectionString, IOrmLiteDialectProvider provider, CancellationToken cancellationToken) : this(dBConnectionString, provider, true, cancellationToken) {
    }
    public SetupViaORMData(string dBConnectionString, IOrmLiteDialectProvider provider, bool setGlobalDialectProvider, CancellationToken cancellationToken) : base(cancellationToken) {
      DBConnectionString = dBConnectionString ?? throw new ArgumentNullException(nameof(dBConnectionString));
      Provider = provider ?? throw new ArgumentNullException(nameof(provider));
      SetGlobalDialectProvider = setGlobalDialectProvider;
    }

    public string DBConnectionString { get; }
    public IOrmLiteDialectProvider Provider { get; }
    public bool SetGlobalDialectProvider { get; }
  }

  public interface ISetupViaORMResults {
    void Dispose();
  }

  public class SetupViaORMResults : SetupResultsAbstract, IDisposable, ISetupViaORMResults {
    OrmLiteConnectionFactory DbFactory { get; }
    IDbConnection DbConn { get; }
    IDbCommand DbCmd { get; }

    public SetupViaORMResults(OrmLiteConnectionFactory DbFactory, IDbConnection DbConn, IDbCommand DbCmd, bool success) : base(success) {
    }

    #region IDisposable Support
    private bool disposedValue = false; // To detect redundant calls

    protected virtual void Dispose(bool disposing) {
      if (!disposedValue) {
        if (disposing) {
          // TODO: dispose managed state (managed objects).
        }

        // TODO: free unmanaged resources (unmanaged objects) and override a finalizer below.
        // TODO: set large fields to null.

        disposedValue = true;
      }
    }

    // TODO: override a finalizer only if Dispose(bool disposing) above has code to free unmanaged resources.
    // ~SetupViaIORMResults()
    // {
    //   // Do not change this code. Put cleanup code in Dispose(bool disposing) above.
    //   Dispose(false);
    // }

    // This code added to correctly implement the disposable pattern.
    public void Dispose() {
      // Do not change this code. Put cleanup code in Dispose(bool disposing) above.
      Dispose(true);
      // TODO: uncomment the following line if the finalizer is overridden above.
      // GC.SuppressFinalize(this);
    }
    #endregion
  }

  public interface IInsertViaORMData : IInsertDataAbstract { }
  public class InsertViaORMData : InsertDataAbstract, IInsertViaORMData {
    public InsertViaORMData(IEnumerable<object>[][] dataToInsert, CancellationToken cancellationToken) : base(dataToInsert, cancellationToken) {
    }
  }

  public interface IInsertViaORMResults : IInsertResultsAbstract { }
  public class InsertViaORMResults : InsertResultsAbstract, IInsertViaORMResults {
    public InsertViaORMResults(bool success) : base(success) {
    }
  }


}
