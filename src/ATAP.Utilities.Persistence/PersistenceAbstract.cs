using System;
using System.Collections.Generic;
using System.Threading;

namespace ATAP.Utilities.Persistence {
  public abstract class SetupDataAbstract : ISetupDataAbstract {
    public CancellationToken? CancellationToken { get; private set; }


    protected SetupDataAbstract(CancellationToken? cancellationToken) {
      if (cancellationToken != null) {
        CancellationToken = cancellationToken;
      }
      else {
        CancellationToken = null;
      }
    }

    protected SetupDataAbstract() : this(null) { }
  }

  public abstract class SetupResultsAbstract : ISetupResultsAbstract {
    protected SetupResultsAbstract() : this(false) { }

    protected SetupResultsAbstract(bool success) {
      Success = success;
    }

    public bool Success { get; set; }
  }

  public abstract class InsertDataAbstract : IInsertDataAbstract {
    public IEnumerable<IEnumerable<object>> EnumerableDataToInsert { get;  set; }
    public IDictionary<string, IEnumerable<object>> DictionaryDataToInsert { get;  set; }
    public CancellationToken? CancellationToken { get; private set; }
    protected InsertDataAbstract(IEnumerable<IEnumerable<object>> enumerableDataToInsert, CancellationToken? cancellationToken) {
      EnumerableDataToInsert = enumerableDataToInsert ?? throw new ArgumentNullException(nameof(enumerableDataToInsert));
      CancellationToken = cancellationToken;
    }
    protected InsertDataAbstract(IDictionary<string, IEnumerable<object>> dictionaryDataToInsert, CancellationToken? cancellationToken) {
      DictionaryDataToInsert = dictionaryDataToInsert ?? throw new ArgumentNullException(nameof(dictionaryDataToInsert));
      CancellationToken = cancellationToken;
    }
  }

  public abstract class InsertResultsAbstract : IInsertResultsAbstract {
    protected InsertResultsAbstract() : this(false) {
    }

    protected InsertResultsAbstract(bool success) {
      Success = success;
    }
    public bool Success { get; set; }
  }

//ToDo: write a fluent builder for create a PersistenceObject
  public class PersistenceBuilderAbstract //: IPersistenceBuilderAbstract
  {

  }

}
