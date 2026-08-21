using System;
using System.IO;

using Microsoft.Extensions.Configuration;
using ATAP.Utilities.Serializer;

using Ninject;

namespace ATAP.Utilities.Testing.Fixture.Serialization {

  public interface ISerializationFixture : IDiFixtureNinject {
    ISerializerConfigurableAbstract Serializer { get; set; }
  }

  public class SerializerInjectionModule : Ninject.Modules.NinjectModule {
    string SerializerShimName { get; set; }
    string SerializerShimNamespace { get; set; }
    IConfigurationRoot? ConfigurationRoot { get; set; }
    public SerializerInjectionModule() : this(
      DefaultConfiguration.Production[StringConstants.SerializerShimNameConfigRootKey],
      DefaultConfiguration.Production[StringConstants.SerializerShimNamespaceConfigRootKey]) { }
    public SerializerInjectionModule(IConfiguration configuration) : this(
      configuration,
      configuration.GetValue<string>(StringConstants.SerializerShimNameConfigRootKey, StringConstants.SerializerShimNameStringDefault),
      configuration.GetValue<string>(StringConstants.SerializerShimNamespaceConfigRootKey, StringConstants.SerializerShimNamespaceStringDefault)
    ) { }

    public SerializerInjectionModule(string serializerShimName = default, string serializerShimNamespace = default) :base() {
      if (String.IsNullOrWhiteSpace(serializerShimName)) { throw new ArgumentNullException(nameof(serializerShimName)); } else { SerializerShimName = serializerShimName; }
      if (String.IsNullOrWhiteSpace(serializerShimNamespace)) { throw new ArgumentNullException(nameof(serializerShimNamespace)); } else { SerializerShimNamespace = serializerShimNamespace; }
    }

    public SerializerInjectionModule(IConfiguration configuration, string serializerShimName, string serializerShimNamespace) : base() {
      if (configuration == null) { throw new ArgumentNullException(nameof(configuration)); }
      ConfigurationRoot = configuration as IConfigurationRoot ?? new ConfigurationBuilder().AddConfiguration(configuration).Build();
      if (String.IsNullOrWhiteSpace(serializerShimName)) { throw new ArgumentNullException(nameof(serializerShimName)); } else { SerializerShimName = serializerShimName; }
      if (String.IsNullOrWhiteSpace(serializerShimNamespace)) { throw new ArgumentNullException(nameof(serializerShimNamespace)); } else { SerializerShimNamespace = serializerShimNamespace; }
    }


    public override void Load() {
      var assemblyName = Path.GetFileNameWithoutExtension(SerializerShimName);
      var serializerType = Type.GetType($"{SerializerShimNamespace}.Serializer, {assemblyName}", throwOnError: true);
      if (serializerType == null || !typeof(ISerializerConfigurableAbstract).IsAssignableFrom(serializerType) || serializerType.IsAbstract) {
        throw new InvalidOperationException($"{SerializerShimNamespace}.Serializer is not a concrete {nameof(ISerializerConfigurableAbstract)} implementation.");
      }

      Bind<ISerializerConfigurableAbstract>().ToMethod(_ =>
        (ISerializerConfigurableAbstract)((ConfigurationRoot == null
          ? Activator.CreateInstance(serializerType)
          : Activator.CreateInstance(serializerType, new object?[] { ConfigurationRoot }))
          ?? throw new InvalidOperationException($"Could not construct serializer type {serializerType.FullName}.")));
    }
  }

  public class SerializationFixture : DiFixtureNinject, ISerializationFixture {

    public SerializationFixture() : base() {
      Kernel = new StandardKernel(new SerializerInjectionModule());
      Serializer = Kernel.Get<ISerializerConfigurableAbstract>();
    }
    public SerializationFixture(IConfiguration configuration) : base(configuration as IConfigurationRoot ?? new ConfigurationBuilder().AddConfiguration(configuration).Build()) {
      Kernel = new StandardKernel(new SerializerInjectionModule(configuration: configuration));
      // Bind the Serializer implementation to the interface using Ninject conventions
      Serializer = Kernel.Get<ISerializerConfigurableAbstract>();
    }
    public SerializationFixture(string serializerShimName = default, string serializerShimNamespace = default) : base() {
      if (String.IsNullOrWhiteSpace(serializerShimName)) { throw new ArgumentNullException(nameof(serializerShimName)); }
      if (String.IsNullOrWhiteSpace(serializerShimNamespace)) { throw new ArgumentNullException(nameof(serializerShimNamespace)); }

      Kernel = new StandardKernel(new SerializerInjectionModule(
         serializerShimName
        , serializerShimNamespace

));
      // Bind the Serializer implementation to the interface using Ninject conventions
      Serializer = Kernel.Get<ISerializerConfigurableAbstract>();
    }

    public ISerializerConfigurableAbstract Serializer { get; set; }
  }
}
