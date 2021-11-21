using System;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using Polly;

namespace ATAP.Utilities.HostedServices.TcpWithResilienceHostedService {
  public interface ITcpWithResilience
  {
      //public Task<byte[]> FetchAsync(string host, int port, string tcpRequestMessage, Encoding encoding = default, Policy policy = default, int maxResponseBufferSize = default, CancellationToken cancellationToken = default);
  }
  public interface ITcpWithResilienceHostedService
  {
    void Dispose();
    Task StartAsync(CancellationToken externalCancellationToken);
    Task StopAsync(CancellationToken cancellationToken);
    // IObservable<string> ConsoleReadLineAsyncAsObservable();
    //
    // ToDo: Move into a TcpWithResilienceHostedService configuration section and Data structure
    //public int defaultMaxResponseBufferSize;
    // ToDo: declare a DI injected resilience policy repository ?

  }
}
