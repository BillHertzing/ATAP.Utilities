using System.Threading;
using System.Threading.Tasks;

namespace ATAP.Utilities.HostedServices {
  public interface IFileWatchersHostedService {
    IFileWatchersHostedServiceData fileWatchersHostedServiceData { get; }

    void Dispose();
    Task StartAsync(CancellationToken externalCancellationToken);
    void Startup();
    Task StopAsync(CancellationToken cancellationToken);
  }
}
