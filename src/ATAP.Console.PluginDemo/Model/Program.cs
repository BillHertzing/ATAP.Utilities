using System.Threading.Tasks;

using ATAP.Utilities.Secrets;
using ATAP.Utilities.Loader;

using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

namespace ATAP.Console.PluginDemo;

internal static class Program
{
  public static async Task Main(string[] args)
  {
    using IHost host = Host.CreateDefaultBuilder(args)
      .ConfigureServices((_, services) =>
      {
        services.AddBitwardenSecrets();
        services.AddSingleton<IAssemblyLoader, NativeAssemblyLoader>();
        services.AddHostedService<PluginDemoBackgroundService>();
      })
      .Build();

    await host.RunAsync().ConfigureAwait(false);
  }
}
