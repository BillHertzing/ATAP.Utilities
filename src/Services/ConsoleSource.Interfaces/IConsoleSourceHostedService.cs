using System.Threading;
using System.Threading.Tasks;
using System.Reactive;
using System;

namespace ATAP.Utilities.HostedServices.ConsoleSourceHostedService {
  public interface IConsoleSourceHostedService {
    void Dispose();
    Task StartAsync(CancellationToken externalCancellationToken);
    Task StopAsync(CancellationToken cancellationToken);
    IObservable<string> ConsoleReadLineAsyncAsObservable();
  }
}
