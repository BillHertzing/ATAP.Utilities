using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace ATAP.Utilities.HostedServices {
  public interface IConsoleSinkHostedService {
    void Dispose();
    Task StartAsync(CancellationToken externalCancellationToken);
    Task StopAsync(CancellationToken cancellationToken);
    Task WriteMessage(string message);
    Task<Task> WriteMessageAsync(string message);
    Task<Task> WriteMessageAsync(StringBuilder message);
  }
}
