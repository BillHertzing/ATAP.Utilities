using System.Threading;
using System.Threading.Tasks;

namespace ATAP.Utilities.HostedServices {
  public interface IObservableResetableTimersHostedService {
    void Dispose();
    Task StartAsync(CancellationToken externalCancellationToken);
    void Startup();
    Task StopAsync(CancellationToken externalCancellationToken);
  }
}
