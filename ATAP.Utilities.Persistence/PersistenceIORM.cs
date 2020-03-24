using System;
using System.Collections.Generic;
using System.Threading;
using ATAP.Utilities.Persistence;

namespace ATAP.Utilities.Persistence
{


    public class PersistenceViaIORMSetupInitializationData : SetupDataAbstract, ISetupDataAbstract
    {
      public PersistenceViaIORMSetupInitializationData(string dBConnectionString, CancellationToken cancellationToken) : base(cancellationToken)
      {
        DBConnectionString = dBConnectionString ?? throw new ArgumentNullException(nameof(dBConnectionString));
      }

      public string DBConnectionString { get; private set; }
    }

    public class PersistenceViaIORMSetupResults : SetupResultsAbstract, ISetupResultsAbstract, IDisposable
    {
      public PersistenceViaIORMSetupResults(bool success) : base(success)
      {
      }

    #region IDisposable Support
    private bool disposedValue = false; // To detect redundant calls

    protected virtual void Dispose(bool disposing)
    {
      if (!disposedValue)
      {
        if (disposing)
        {
          // TODO: dispose managed state (managed objects).
        }

        // TODO: free unmanaged resources (unmanaged objects) and override a finalizer below.
        // TODO: set large fields to null.

        disposedValue = true;
      }
    }

    // TODO: override a finalizer only if Dispose(bool disposing) above has code to free unmanaged resources.
    // ~PersistenceViaIORMSetupResults()
    // {
    //   // Do not change this code. Put cleanup code in Dispose(bool disposing) above.
    //   Dispose(false);
    // }

    // This code added to correctly implement the disposable pattern.
    public void Dispose()
    {
      // Do not change this code. Put cleanup code in Dispose(bool disposing) above.
      Dispose(true);
      // TODO: uncomment the following line if the finalizer is overridden above.
      // GC.SuppressFinalize(this);
    }
    #endregion
  }

    public class PersistenceViaIORMInsertData : InsertDataAbstract
    {
      public PersistenceViaIORMInsertData( IEnumerable<object>[][] dataToInsert, CancellationToken cancellationToken) : base(dataToInsert, cancellationToken)
      {
      }
    }

    public class PersistenceViaIORMInsertResults : InsertResultsAbstract, IInsertResultsAbstract
    {
      public PersistenceViaIORMInsertResults(bool success) : base(success)
      {
      }
    }

   
}
