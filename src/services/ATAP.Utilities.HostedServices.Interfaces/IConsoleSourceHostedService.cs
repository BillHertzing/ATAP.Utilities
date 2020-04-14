using System.Threading;
using System.Threading.Tasks;

namespace ATAP.Utilities.HostedServices {
  public interface IConsoleSourceHostedService {
    void Dispose();
    Task StartAsync(CancellationToken externalCancellationToken);
    Task StopAsync(CancellationToken cancellationToken);
  }
}