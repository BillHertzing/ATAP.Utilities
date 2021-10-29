using System.Threading;

namespace ATAP.Utilities.MessageQueue
{
  public interface ISetupMessageQueue
  {
    CancellationToken? CancellationToken { get; }
  }
}
