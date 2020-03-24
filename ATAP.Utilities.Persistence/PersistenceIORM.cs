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

    public class PersistenceViaIORMSetupResults : SetupResultsAbstract, ISetupResultsAbstract
    {
      public PersistenceViaIORMSetupResults(bool success) : base(success)
      {
      }
      public bool DisposeOfTheORMFunc { get; private set; }
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

    public class PersistenceViaIORMTearDownInitializationData : TearDownDataAbstract
    {
      public PersistenceViaIORMTearDownInitializationData(SetupResultsAbstract persistenceSetupResults, CancellationToken cancellationToken) : base( cancellationToken)
      {
      }
    }

    public class PersistenceViaIORMTearDownResults : TearDownResultsAbstract
    {
      public PersistenceViaIORMTearDownResults(bool success) : base(success)
      {
      }
    }

    //public class PersistenceViaIORM : PersistenceAbstract {

    //    public Func<PersistenceViaIORMSetupInitializationData, PersistenceViaIORMSetupResults> PersistenceViaIORMSetup;
    //    public Func<PersistenceViaIORMInsertData, PersistenceViaIORMSetupResults, PersistenceViaIORMInsertResults> PersistenceViaIORMViaIORMInsert;
    //    public Func<PersistenceViaIORMTearDownInitializationData, PersistenceViaIORMTearDownResults> PersistenceViaIORMTearDown;

    //  public PersistenceViaIORM(PersistenceSetupInitializationDataAbstract persistenceSetupInitializationData, PersistenceSetupResultsAbstract persistenceSetupResults, Func<PersistenceSetupInitializationDataAbstract, PersistenceSetupResultsAbstract> persistenceSetup, PersistenceInsertDataAbstract persistenceInsertData, PersistenceInsertResultsAbstract persistenceInsertResults, Func<PersistenceInsertDataAbstract, PersistenceSetupResultsAbstract, PersistenceInsertResultsAbstract> persistenceInsert, PersistenceTearDownDataAbstract persistenceTearDownInitializationData, PersistenceTearDownResultsAbstract persistenceTearDownResults, Func<PersistenceTearDownDataAbstract, PersistenceSetupResultsAbstract, PersistenceTearDownResultsAbstract> persistenceTearDown) : base(persistenceSetupInitializationData, persistenceSetupResults, persistenceSetup, persistenceInsertData, persistenceInsertResults, persistenceInsert, persistenceTearDownInitializationData, persistenceTearDownResults, persistenceTearDown)
    //  {
    //  }
    //}
}
