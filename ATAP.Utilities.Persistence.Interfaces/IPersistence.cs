using System;
using System.Collections.Generic;

namespace ATAP.Utilities.Persistence
{
  public interface IPersistence<out Tout> where Tout : IInsertResultsAbstract
  {
    Func<IEnumerable<IEnumerable<object>>, Tout> InsertFunc { get; }
  }
}
