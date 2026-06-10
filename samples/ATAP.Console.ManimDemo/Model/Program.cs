using System.Threading.Tasks;

using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.SemanticKernel;

using ATAP.Utilities.ManimVideoGenerator;

namespace ATAP.Console.ManimDemo;

internal static class Program
{
  public static async Task Main(string[] args)
  {
    using IHost host = Host.CreateDefaultBuilder(args)
      .ConfigureAppConfiguration((ctx, config) =>
      {
        // Inject compile-time defaults before file-based sources
        config.AddInMemoryCollection(ManimDemoDefaultConfiguration.Production);
      })
      .ConfigureServices((ctx, services) =>
      {
        // Bind strongly-typed options from the "ManimVideoGenerator" config section
        services.AddOptions<ManimVideoGeneratorOptions>()
          .Bind(ctx.Configuration.GetSection(StringConstants.ManimDemoConfigRootKey))
          .ValidateDataAnnotations()
          .ValidateOnStart();

        // Register the Manim utility services
        services.AddSingleton<IManimRunner, ManimRunner>();
        services.AddSingleton<IAnimationOrchestrator, AnimationOrchestrator>();

        // Register the interactive background service
        services.AddHostedService<ManimDemoBackgroundService>();
      })
      .Build();

    await host.RunAsync().ConfigureAwait(false);
  }
}
