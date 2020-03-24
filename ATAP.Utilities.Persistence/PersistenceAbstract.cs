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

  public interface IPersistence<out Tout>
  {
    Func<IEnumerable<IEnumerable<object>>, Tout> InsertFunc { get; }
  }

  public class Persistence<Tout> : IPersistence<Tout> where Tout : IInsertResultsAbstract
  {

    public Persistence(Func<IEnumerable<IEnumerable<object>>, Tout> insertFunc)
    {
      InsertFunc = insertFunc;
    }

    public Func<IEnumerable<IEnumerable<object>>, Tout> InsertFunc { get; private set; }
  }


  public class PersistenceBuilderAbstract //: IPersistenceBuilderAbstract
  {

  }

}
