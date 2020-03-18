using System;
using System.Collections.Generic;
using System.IO;
using System.Threading;

namespace ATAP.Utilities.Persistence.FileSystem {

  // ToDo figure out the disposable mechanism
    public class PersistenceViaFileSetupInitializationData : PersistenceSetupInitializationDataAbstract
  {
    public PersistenceViaFileSetupInitializationData(string filePath, CancellationToken cancellationToken) : base(cancellationToken)
    {
      FilePath = filePath ?? throw new ArgumentNullException(nameof(filePath));
    }

    // ToDo something more sophisticated than just a string for identifying the FileSystem storage mechanism
    public string FilePath { get; private set; }
  }

    public class PersistenceViaFileSetupResults : PersistenceSetupResultsAbstract
  {

    public PersistenceViaFileSetupResults(FileStream fileStream, StreamWriter streamWriter, bool success) : base(success)
    {
      FileStream = fileStream ?? throw new ArgumentNullException(nameof(fileStream));
      StreamWriter = streamWriter ?? throw new ArgumentNullException(nameof(streamWriter));
    }

    public FileStream FileStream { get; private set; }
    public StreamWriter StreamWriter { get; private set; }
  }

  public class PersistenceViaFileInsertData : PersistenceInsertDataAbstract
  {
    public PersistenceViaFileInsertData(PersistenceSetupResultsAbstract persistenceSetupResults, List<string> dList, CancellationToken cancellationToken) : base(persistenceSetupResults, dList, cancellationToken)
    {
    }
  }

  public class PersistenceViaFileInsertResults : PersistenceInsertResultsAbstract
  {
    public PersistenceViaFileInsertResults(bool success) : base(success)
    {
    }
  }

  public class PersistenceViaFileTearDownInitializationData : PersistenceTearDownInitializationDataAbstract
  {
    public PersistenceViaFileTearDownInitializationData(PersistenceSetupResultsAbstract persistenceSetupResults, CancellationToken cancellationToken) : base(persistenceSetupResults, cancellationToken)
    {
    }
  }

  public class PersistenceViaFileTearDownResults : PersistenceTearDownResultsAbstract
  {
    public PersistenceViaFileTearDownResults(bool success) : base(success)
    {
    }
  }

  public class PersistenceViaFile : PersistenceAbstract {

        public Func<PersistenceViaFileSetupInitializationData, PersistenceViaFileSetupResults> PersistenceViaFileSetup;
        public Func<PersistenceViaFileInsertData, PersistenceViaFileSetupResults, PersistenceViaFileInsertResults> PersistenceViaFileViaFileInsert;
        public Func<PersistenceViaFileTearDownInitializationData, PersistenceViaFileTearDownResults> PersistenceViaFileTearDown;

    public PersistenceViaFile(PersistenceSetupInitializationDataAbstract persistenceSetupInitializationData, PersistenceSetupResultsAbstract persistenceSetupResults, Func<PersistenceSetupInitializationDataAbstract, PersistenceSetupResultsAbstract> persistenceSetup, PersistenceInsertDataAbstract persistenceInsertData, PersistenceInsertResultsAbstract persistenceInsertResults, Func<PersistenceInsertDataAbstract, PersistenceSetupResultsAbstract, PersistenceInsertResultsAbstract> persistenceInsert, PersistenceTearDownInitializationDataAbstract persistenceTearDownInitializationData, PersistenceTearDownResultsAbstract persistenceTearDownResults, Func<PersistenceTearDownInitializationDataAbstract, PersistenceSetupResultsAbstract, PersistenceTearDownResultsAbstract> persistenceTearDown) : base(persistenceSetupInitializationData, persistenceSetupResults, persistenceSetup, persistenceInsertData, persistenceInsertResults, persistenceInsert, persistenceTearDownInitializationData, persistenceTearDownResults, persistenceTearDown)
    {
    }
  }
}
