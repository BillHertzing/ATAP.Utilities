using System;
using System.Collections.Generic;
using System.Threading;

namespace ATAP.Utilities.Persistence {
    public abstract class PersistenceSetupInitializationDataAbstract
  {
        public CancellationToken CancellationToken { get; private set; }

 
    protected PersistenceSetupInitializationDataAbstract(CancellationToken cancellationToken)
    {
      CancellationToken = cancellationToken;
    }
  }

 
    public abstract class PersistenceSetupResultsAbstract
  {
    protected PersistenceSetupResultsAbstract(bool success)
    {
      Success = success;
    }

    public bool Success { get; private set; }
    }

    public abstract class PersistenceInsertDataAbstract
  {
    protected PersistenceInsertDataAbstract(PersistenceSetupResultsAbstract persistenceSetupResults, List<string> dList, CancellationToken cancellationToken)
    {
      PersistenceSetupResults = persistenceSetupResults ?? throw new ArgumentNullException(nameof(persistenceSetupResults));
      DList = dList ?? throw new ArgumentNullException(nameof(dList));
      CancellationToken = cancellationToken;
    }

    public PersistenceSetupResultsAbstract PersistenceSetupResults { get; private set; }
        public List<string> DList { get; private set; }
    public CancellationToken CancellationToken { get; private set; }

  }
  public abstract class PersistenceInsertResultsAbstract
  {
    protected PersistenceInsertResultsAbstract(bool success)
    {
      Success = success;
    }

    public bool Success { get; private set; }
  }

    // ToDo Make writeFileInfo into a thread-safe structure
    //ToDo: Add a CancellationToken
    public abstract class PersistenceTearDownInitializationDataAbstract
  {
    protected PersistenceTearDownInitializationDataAbstract(PersistenceSetupResultsAbstract persistenceSetupResults, CancellationToken cancellationToken)
    {
      PersistenceSetupResults = persistenceSetupResults ?? throw new ArgumentNullException(nameof(persistenceSetupResults));
      CancellationToken = cancellationToken;
    }

    public PersistenceSetupResultsAbstract PersistenceSetupResults { get; private set; }
    public CancellationToken CancellationToken { get; private set; }

  }

  public abstract class PersistenceTearDownResultsAbstract
  {
    protected PersistenceTearDownResultsAbstract(bool success)
    {
      Success = success;
    }

    public bool Success { get; private set; }
  }

    public abstract class PersistenceAbstract
  {
        public PersistenceSetupInitializationDataAbstract PersistenceSetupInitializationData;
        public PersistenceSetupResultsAbstract PersistenceSetupResults;
        public Func<PersistenceSetupInitializationDataAbstract, PersistenceSetupResultsAbstract> PersistenceSetup;
        public PersistenceInsertDataAbstract PersistenceInsertData;
        public PersistenceInsertResultsAbstract PersistenceInsertResults;
        public Func<PersistenceInsertDataAbstract, PersistenceSetupResultsAbstract, PersistenceInsertResultsAbstract> PersistenceInsert;
        public PersistenceTearDownInitializationDataAbstract PersistenceTearDownInitializationData;
        public PersistenceTearDownResultsAbstract PersistenceTearDownResults;
        public Func<PersistenceTearDownInitializationDataAbstract, PersistenceSetupResultsAbstract, PersistenceTearDownResultsAbstract> PersistenceTearDown;

    protected PersistenceAbstract(PersistenceSetupInitializationDataAbstract persistenceSetupInitializationData, PersistenceSetupResultsAbstract persistenceSetupResults, Func<PersistenceSetupInitializationDataAbstract, PersistenceSetupResultsAbstract> persistenceSetup, PersistenceInsertDataAbstract persistenceInsertData, PersistenceInsertResultsAbstract persistenceInsertResults, Func<PersistenceInsertDataAbstract, PersistenceSetupResultsAbstract, PersistenceInsertResultsAbstract> persistenceInsert, PersistenceTearDownInitializationDataAbstract persistenceTearDownInitializationData, PersistenceTearDownResultsAbstract persistenceTearDownResults, Func<PersistenceTearDownInitializationDataAbstract, PersistenceSetupResultsAbstract, PersistenceTearDownResultsAbstract> persistenceTearDown)
    {
      PersistenceSetupInitializationData = persistenceSetupInitializationData ?? throw new ArgumentNullException(nameof(persistenceSetupInitializationData));
      PersistenceSetupResults = persistenceSetupResults ?? throw new ArgumentNullException(nameof(persistenceSetupResults));
      PersistenceSetup = persistenceSetup ?? throw new ArgumentNullException(nameof(persistenceSetup));
      PersistenceInsertData = persistenceInsertData ?? throw new ArgumentNullException(nameof(persistenceInsertData));
      PersistenceInsertResults = persistenceInsertResults ?? throw new ArgumentNullException(nameof(persistenceInsertResults));
      PersistenceInsert = persistenceInsert ?? throw new ArgumentNullException(nameof(persistenceInsert));
      PersistenceTearDownInitializationData = persistenceTearDownInitializationData ?? throw new ArgumentNullException(nameof(persistenceTearDownInitializationData));
      PersistenceTearDownResults = persistenceTearDownResults ?? throw new ArgumentNullException(nameof(persistenceTearDownResults));
      PersistenceTearDown = persistenceTearDown ?? throw new ArgumentNullException(nameof(persistenceTearDown));
    }
  }

}
