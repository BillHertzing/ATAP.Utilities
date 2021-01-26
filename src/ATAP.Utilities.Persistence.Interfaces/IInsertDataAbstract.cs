using System.Collections.Generic;
using System.Threading;

namespace ATAP.Utilities.Persistence {
  public interface IInsertDataAbstract {
    CancellationToken? CancellationToken { get; }
    IEnumerable<IEnumerable<object>> EnumerableDataToInsert { get; }
    IDictionary<string, IEnumerable<object>> DictionaryDataToInsert { get; }
  }
  // public interface IInsertDataAbstract<T,V> {
  //   CancellationToken? CancellationToken { get; }
  //   ICollection<IEnumerable<object>>
  //   V is IEnumerable IEnumerable<IEnumerable<object>> EnumerableDataToInsert { get; }
  //   V is Dictionary Dictionary<string, IEnumerable<object>> EnumerableDataToInsert { get; }
  // }
}
