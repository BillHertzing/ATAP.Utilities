using System.Threading;

namespace ATAP.Utilities.Persistence
{
  public interface ISetupDataAbstract
  {
    CancellationToken? CancellationToken { get; }
  }
}
