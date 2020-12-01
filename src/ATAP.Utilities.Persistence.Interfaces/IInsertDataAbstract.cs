using System.Collections.Generic;
using System.Threading;

namespace ATAP.Utilities.Persistence
{
  public interface IInsertDataAbstract
  {
    CancellationToken? CancellationToken { get; }
    IEnumerable<IEnumerable<object>> DataToInsert { get; }
  }
}
