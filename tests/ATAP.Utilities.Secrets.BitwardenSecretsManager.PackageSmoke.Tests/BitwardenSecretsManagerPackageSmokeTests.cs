using ATAP.Utilities.Secrets;
using ATAP.Utilities.Secrets.BitwardenSecretsManager;
using ATAP.Utilities.Secrets.BitwardenSecretsManager.Windows;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Logging.Abstractions;
using System.Runtime.Versioning;
using Xunit;

namespace ATAP.Utilities.Secrets.BitwardenSecretsManager.PackageSmoke.Tests;

[SupportedOSPlatform("windows")]
public sealed class BitwardenSecretsManagerPackageSmokeTests
{
  [Fact]
  public void PublicOptionsAndDiCompositionCanBeUsedFromTheReferencedPackages()
  {
    var bitwardenOptions = new BitwardenSecretsManagerOptions
    {
      ApplicationId = "PackageSmoke",
      ProjectId = "8e96b69e-831b-47e1-8ccb-0ce731f0b2a4",
      ProjectName = "PackageSmoke",
      VaultGroupingId = "PackageSmoke",
      BwsExecutablePath = @"C:\Windows\System32\cmd.exe",
      RequiredSecretNames = new HashSet<string>(StringComparer.Ordinal) { "PackageSmoke.RequiredSecret" },
      SecretIdsByName = new Dictionary<string, string>(StringComparer.Ordinal)
      {
        ["PackageSmoke.RequiredSecret"] = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
      },
    };
    var windowsOptions = new WindowsBwsTokenSourceOptions
    {
      ApplicationId = bitwardenOptions.ApplicationId,
      VaultGroupingId = bitwardenOptions.VaultGroupingId,
    };
    var services = new ServiceCollection();
    services.AddSingleton(typeof(ILogger<>), typeof(NullLogger<>));

    services.AddWindowsDpapiBwsReadOnlyAccessTokenSource(windowsOptions);
    services.AddBitwardenSecretsManager(bitwardenOptions);

    using var provider = services.BuildServiceProvider();

    Assert.Same(bitwardenOptions, provider.GetRequiredService<BitwardenSecretsManagerOptions>());
    Assert.Same(windowsOptions, provider.GetRequiredService<WindowsBwsTokenSourceOptions>());
    Assert.IsType<WindowsDpapiBwsReadOnlyAccessTokenSource>(provider.GetRequiredService<IBwsReadOnlyAccessTokenSource>());
    Assert.IsType<BitwardenSecretsManagerProvider>(provider.GetRequiredService<ISecretsAbstract>());
  }
}
