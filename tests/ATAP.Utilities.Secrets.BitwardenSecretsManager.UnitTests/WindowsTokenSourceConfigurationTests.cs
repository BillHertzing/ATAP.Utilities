using System.Runtime.Versioning;
using ATAP.Utilities.Secrets.BitwardenSecretsManager.Windows;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace ATAP.Utilities.Secrets.BitwardenSecretsManager.UnitTests;

[SupportedOSPlatform("windows")]
public sealed class WindowsTokenSourceConfigurationTests
{
  [Theory]
  [InlineData("aceoutpost-application")]
  [InlineData("aceoutpost-developer")]
  public void AddWindowsDpapiBwsReadOnlyAccessTokenSource_BindsRegisteredAceOutpostProfile(string slotId)
  {
    var configuration = CreateConfiguration(slotId);
    var services = new ServiceCollection();

    services.AddWindowsDpapiBwsReadOnlyAccessTokenSource(configuration);

    var registration = Assert.Single(services.Where(descriptor => descriptor.ServiceType == typeof(WindowsBwsTokenSourceOptions)));
    var options = Assert.IsType<WindowsBwsTokenSourceOptions>(registration.ImplementationInstance);
    Assert.Equal(slotId, options.EnabledSlotId);
    Assert.Equal("AceOutpost", options.ApplicationId);
    Assert.Equal("AceOutpost", options.VaultGroupingId);
    Assert.Equal(WindowsBwsTokenPhysicalFormat.AtapBwsDpapiEnvelopeV1, options.ResolveConfiguredSlot().PhysicalFormat);
  }

  [Theory]
  [InlineData("acecommander-application")]
  [InlineData("acecommander-developer")]
  public void AddWindowsDpapiBwsReadOnlyAccessTokenSource_BindsRegisteredAceCommanderProfile(string slotId)
  {
    var configuration = CreateConfiguration(slotId);
    var services = new ServiceCollection();

    services.AddWindowsDpapiBwsReadOnlyAccessTokenSource(configuration);

    var registration = Assert.Single(services.Where(descriptor => descriptor.ServiceType == typeof(WindowsBwsTokenSourceOptions)));
    var options = Assert.IsType<WindowsBwsTokenSourceOptions>(registration.ImplementationInstance);
    Assert.Equal(slotId, options.EnabledSlotId);
    Assert.Equal("AceCommander", options.ApplicationId);
    Assert.Equal("AceCommander", options.VaultGroupingId);
    Assert.Equal(WindowsBwsTokenPhysicalFormat.AtapBwsDpapiEnvelopeV1, options.ResolveConfiguredSlot().PhysicalFormat);
  }

  [Fact]
  public void RegisteredProfiles_KeepAceCommanderAndAceOutpostApplicationIdentitiesDisjoint()
  {
    var aceCommander = WindowsBwsTokenSlotProfile.Registered["acecommander-application"];
    var aceOutpost = WindowsBwsTokenSlotProfile.Registered["aceoutpost-application"];

    Assert.NotEqual(aceOutpost.ApplicationId, aceCommander.ApplicationId);
    Assert.NotEqual(aceOutpost.VaultGroupingId, aceCommander.VaultGroupingId);
    Assert.Equal(BwsTokenPurpose.ReadOnly, aceCommander.Descriptor.Purpose);
  }

  [Theory]
  [InlineData("unknown-slot")]
  [InlineData("application-envelope")]
  public void AddWindowsDpapiBwsReadOnlyAccessTokenSource_UnknownOrUnregisteredSlotId_ThrowsTypedStartupFailure(string slotId)
  {
    var configuration = CreateConfiguration(slotId);
    var services = new ServiceCollection();

    var error = Assert.Throws<BwsException>(() => services.AddWindowsDpapiBwsReadOnlyAccessTokenSource(configuration));

    Assert.Equal(BwsFailureKind.InvalidConfiguration, error.Kind);
  }

  private static IConfiguration CreateConfiguration(string slotId) => new ConfigurationBuilder()
    .AddInMemoryCollection(new Dictionary<string, string?>
    {
      [$"{WindowsBwsTokenSourceOptions.DefaultConfigurationSectionName}:EnabledSlotId"] = slotId,
    })
    .Build();
}