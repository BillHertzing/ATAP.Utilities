using System;
using System.Collections.Generic;

namespace ATAP.Utilities.Persistence
{
  public interface IPickAndSave<out Tout> where Tout : IInsertResultsAbstract {
    Func<object, bool> PickFunc { get; }
    Func<IEnumerable<IEnumerable<object>>, Tout> InsertFunc { get; }
  }
}
