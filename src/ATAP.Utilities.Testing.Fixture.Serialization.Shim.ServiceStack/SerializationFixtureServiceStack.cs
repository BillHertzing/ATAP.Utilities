using System;

using Microsoft.Extensions.Configuration;

using ATAP.Utilities.Serializer;

using Ninject;
using Ninject.Modules;

namespace ATAP.Utilities.Testing {

  internal sealed class SerializerInjectionModuleServiceStack : NinjectModule {
    private readonly IConfigurationRoot? configurationRoot;

    public SerializerInjectionModuleServiceStack(IConfiguration configuration) {
      configurationRoot = configuration as IConfigurationRoot;
    }

    public override void Load() {
      Bind<ISerializerConfigurableAbstract>().ToMethod(_ =>
        configurationRoot == null
          ? new ATAP.Utilities.Serializer.Shim.ServiceStack.Serializer()
          : new ATAP.Utilities.Serializer.Shim.ServiceStack.Serializer(configurationRoot));
    }
  }

  public interface ISerializationFixtureServiceStack : IDiFixtureNinject {
    ISerializerConfigurableAbstract Serializer { get; }
  }
  /// <summary>
  /// A Test Fixture that supports Serialization by injecting the ServiceStack libraries as the ISerializerConfigurableAbstract in the DI-based Fixture
  /// </summary>
  public partial class SerializationFixtureServiceStack : DiFixtureNinject, ISerializationFixtureServiceStack {
    public ISerializerConfigurableAbstract Serializer { get; }
    public ISerializerOptionsAbstract Options { get; }

    public SerializationFixtureServiceStack(IConfiguration configuration) : base() {
      ArgumentNullException.ThrowIfNull(configuration);
      Kernel.Load(new SerializerInjectionModuleServiceStack(configuration));
      Serializer = Kernel.Get<ISerializerConfigurableAbstract>();
      Options = Serializer.Options;
    }
  }
}
