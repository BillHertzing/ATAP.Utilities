using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;

namespace ATAP.Utilities.Persistence
{
  public interface ISetupDataAbstract
  {
    CancellationToken? CancellationToken { get; }
  }

  public abstract class SetupDataAbstract : ISetupDataAbstract
  {
    public CancellationToken? CancellationToken { get; private set; }


    protected SetupDataAbstract(CancellationToken? cancellationToken)
    {
      if (cancellationToken != null)
      {
        CancellationToken = cancellationToken;
      }
      else
      {
        CancellationToken = null;
      }
    }

    protected SetupDataAbstract() : this(null)
    {
    }
  }

  public interface ISetupResultsAbstract
  {
    bool Success { get; set; }
  }

  public abstract class SetupResultsAbstract : ISetupResultsAbstract
  {
    protected SetupResultsAbstract() : this(false)
    {
    }

    protected SetupResultsAbstract(bool success)
    {
      Success = success;
    }

    public bool Success { get; set; }
  }

  public interface IInsertDataAbstract
  {
    CancellationToken? CancellationToken { get; }
    IEnumerable<IEnumerable<object>> DataToInsert { get; }
  }

  public abstract class InsertDataAbstract : IInsertDataAbstract
  {
    protected InsertDataAbstract(IEnumerable<IEnumerable<object>> dataToInsert, CancellationToken? cancellationToken)
    {
      DataToInsert = dataToInsert ?? throw new ArgumentNullException(nameof(dataToInsert));
      CancellationToken = cancellationToken;
    }

    public IEnumerable<IEnumerable<object>> DataToInsert { get; private set; }
    public CancellationToken? CancellationToken { get; private set; }

  }

  public interface IInsertResultsAbstract
  {
    bool Success { get; set; }
  }

  public abstract class InsertResultsAbstract : IInsertResultsAbstract
  {
    protected InsertResultsAbstract() : this(false)
    {
    }

    protected InsertResultsAbstract(bool success)
    {
      Success = success;
    }

    public bool Success { get; set; }
  }

  public interface ITearDownDataAbstract
  {
    CancellationToken? CancellationToken { get; }
  }

  public abstract class TearDownDataAbstract : ITearDownDataAbstract
  {

    protected TearDownDataAbstract(CancellationToken? cancellationToken)
    {
      if (cancellationToken != null)
      {
        CancellationToken = cancellationToken;
      }
      else
      {
        CancellationToken = null;

      }
    }

    public CancellationToken? CancellationToken { get; private set; }

  }

  public interface ITearDownResultsAbstract
  {
    bool Success { get; set; }
  }

  public abstract class TearDownResultsAbstract : ITearDownResultsAbstract
  {
    protected TearDownResultsAbstract() : this(false)
    {
    }

    protected TearDownResultsAbstract(bool success)
    {
      Success = success;
    }

    public bool Success { get; set; }
  }

  public interface IPersistenceAbstract
  {
    ISetupResultsAbstract SetupResults { get; set; }
    Func<SetupDataAbstract, ISetupResultsAbstract> SetupFunc { get; set; }
    Func<InsertDataAbstract, ISetupResultsAbstract, InsertResultsAbstract> InsertFunc { get; set; }
    Func<TearDownDataAbstract, ISetupResultsAbstract, TearDownResultsAbstract> TearDownFunc { get; set; }
  }


  public abstract class PersistenceAbstract : IPersistenceAbstract
  {
    protected PersistenceAbstract() { }
    protected PersistenceAbstract(SetupDataAbstract? setupData, ISetupResultsAbstract? setupResults, Func<SetupDataAbstract, ISetupResultsAbstract> setupFunc, Func<object, InsertViaFileData> convertToDataToInsertFunc, Func<InsertDataAbstract, ISetupResultsAbstract, InsertResultsAbstract> insertFunc, Func<TearDownDataAbstract, ISetupResultsAbstract, TearDownResultsAbstract> tearDownFunc)
    {
      SetupResults = setupResults;
      SetupFunc = setupFunc ?? throw new ArgumentNullException(nameof(setupFunc));
      InsertFunc = insertFunc ?? throw new ArgumentNullException(nameof(insertFunc));
      TearDownFunc = tearDownFunc ?? throw new ArgumentNullException(nameof(tearDownFunc));
    }

    public ISetupResultsAbstract? SetupResults { get; set; }
    public Func<SetupDataAbstract, ISetupResultsAbstract> SetupFunc { get; set; }
    public Func<InsertDataAbstract, ISetupResultsAbstract, InsertResultsAbstract> InsertFunc { get; set; }
    public Func<TearDownDataAbstract, ISetupResultsAbstract, TearDownResultsAbstract> TearDownFunc { get; set; }


  }

  public class PersistenceBuilderAbstract //: IPersistenceBuilderAbstract
  {

  }

}
