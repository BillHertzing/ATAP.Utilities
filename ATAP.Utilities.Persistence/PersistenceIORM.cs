using System;
using System.Collections.Generic;
using System.Threading;
using ATAP.Utilities.Persistence;

namespace ATAP.Utilities.Persistence.ORM
{


    public class PersistenceViaORMSetupInitializationData : PersistenceSetupInitializationDataAbstract
    {
      public PersistenceViaORMSetupInitializationData(string dBConnectionString, CancellationToken cancellationToken) : base(cancellationToken)
      {
        DBConnectionString = dBConnectionString ?? throw new ArgumentNullException(nameof(dBConnectionString));
      }

      public string DBConnectionString { get; private set; }
    }

    public class PersistenceViaORMSetupResults : PersistenceSetupResultsAbstract
    {
      public PersistenceViaORMSetupResults(bool success) : base(success)
      {
      }


      //public IORMInfo ORMHandle { get; private set; }
      public bool DisposeOfTheORMFunc { get; private set; }
    }

    public class PersistenceViaORMInsertData : PersistenceInsertDataAbstract
    {
      public PersistenceViaORMInsertData(PersistenceSetupResultsAbstract persistenceSetupResults, List<string>[] dList, CancellationToken cancellationToken) : base(persistenceSetupResults, dList, cancellationToken)
      {
      }
    }

    public class PersistenceViaORMInsertResults : PersistenceInsertResultsAbstract
    {
      public PersistenceViaORMInsertResults(bool success) : base(success)
      {
      }
    }

    public class PersistenceViaORMTearDownInitializationData : PersistenceTearDownDataAbstract
    {
      public PersistenceViaORMTearDownInitializationData(PersistenceSetupResultsAbstract persistenceSetupResults, CancellationToken cancellationToken) : base(persistenceSetupResults, cancellationToken)
      {
      }
    }

    public class PersistenceViaORMTearDownResults : PersistenceTearDownResultsAbstract
    {
      public PersistenceViaORMTearDownResults(bool success) : base(success)
      {
      }
    }

    public class PersistenceViaORM : PersistenceAbstract {

        public Func<PersistenceViaORMSetupInitializationData, PersistenceViaORMSetupResults> PersistenceViaORMSetup;
        public Func<PersistenceViaORMInsertData, PersistenceViaORMSetupResults, PersistenceViaORMInsertResults> PersistenceViaORMViaORMInsert;
        public Func<PersistenceViaORMTearDownInitializationData, PersistenceViaORMTearDownResults> PersistenceViaORMTearDown;

      public PersistenceViaORM(PersistenceSetupInitializationDataAbstract persistenceSetupInitializationData, PersistenceSetupResultsAbstract persistenceSetupResults, Func<PersistenceSetupInitializationDataAbstract, PersistenceSetupResultsAbstract> persistenceSetup, PersistenceInsertDataAbstract persistenceInsertData, PersistenceInsertResultsAbstract persistenceInsertResults, Func<PersistenceInsertDataAbstract, PersistenceSetupResultsAbstract, PersistenceInsertResultsAbstract> persistenceInsert, PersistenceTearDownDataAbstract persistenceTearDownInitializationData, PersistenceTearDownResultsAbstract persistenceTearDownResults, Func<PersistenceTearDownDataAbstract, PersistenceSetupResultsAbstract, PersistenceTearDownResultsAbstract> persistenceTearDown) : base(persistenceSetupInitializationData, persistenceSetupResults, persistenceSetup, persistenceInsertData, persistenceInsertResults, persistenceInsert, persistenceTearDownInitializationData, persistenceTearDownResults, persistenceTearDown)
      {
      }
    }
}
