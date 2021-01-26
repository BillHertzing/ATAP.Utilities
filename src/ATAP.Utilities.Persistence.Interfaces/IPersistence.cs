using System;
using System.Collections.Generic;

namespace ATAP.Utilities.Persistence {
  public interface IPersistence<out Tout> where Tout : IInsertResultsAbstract {
    Func<IEnumerable<IEnumerable<object>>, Tout> InsertEnumerableFunc { get; }
    Func<IDictionary<string, IEnumerable<object>>, Tout> InsertDictionaryFunc { get; }
  }
}
