using System;

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
    public SerializerInjectionModule() : this(
      DefaultConfiguration.Production[StringConstants.SerializerShimNameStringDefault],
      DefaultConfiguration.Production[StringConstants.SerializerShimNamespaceStringDefault]) { }
    public SerializerInjectionModule(IConfiguration configuration) : this(
      configuration,
      configuration.GetValue<string>(StringConstants.SerializerShimNameConfigRootKey, StringConstants.SerializerShimNameStringDefault),
      configuration.GetValue<string>(StringConstants.SerializerShimNamespaceConfigRootKey, StringConstants.SerializerShimNamespaceStringDefault)
    ) { }

    public SerializerInjectionModule(string serializerShimName = default, string serializerShimNamespace = default) :base() {
      if (String.IsNullOrWhiteSpace(serializerShimName)) { throw new ArgumentNullException(nameof(serializerShimName)); } else { SerializerShimName = serializerShimName; }
      if (String.IsNullOrWhiteSpace(serializerShimNamespace)) { throw new ArgumentNullException(nameof(serializerShimNamespace)); } else { SerializerShimNamespace = serializerShimNamespace; }
      base.Kernel.Load(this);
    }

    public SerializerInjectionModule(IConfiguration configuration, string serializerShimName, string serializerShimNamespace) :base(configuration){
      if (configuration == null) { throw new ArgumentNullException(nameof(configuration)); }
      if (String.IsNullOrWhiteSpace(serializerShimName)) { throw new ArgumentNullException(nameof(serializerShimName)); } else { SerializerShimName = serializerShimName; }
      if (String.IsNullOrWhiteSpace(serializerShimNamespace)) { throw new ArgumentNullException(nameof(serializerShimNamespace)); } else { SerializerShimNamespace = serializerShimNamespace; }
      base.Kernel.Load(this);
    }


  //Kernel = new StandardKernel(new SerializerInjectionModule(configuration: configuration));

    // public override void Load() {
    //   // ToDo make this lazy ISerializerConfigurableAbstract t = ATAP.Utilities.Serializer.SerializerLoader.LoadSerializerFromAssembly();
    //   var loader = new ATAP.Utilities.Loader.Loader<ISerializerConfigurableAbstract>();
    //   var serializer = loader.LoadExactlyOneInstanceOfITypeFromAssemblyGlob(
    //     new DynamicGlobAndPredicate() {
    //       Glob = new Glob() { Pattern = ".\\Plugins\\ATAP.Utilities.Serializer.Shim.SystemTextJson.dll" },
    //       Predicate =
    //         new Predicate<Type>(type => {
    //           return typeof(ISerializerConfigurableAbstract).IsAssignableFrom(type) && !type.IsAbstract && type.Namespace == "ATAP.Utilities.Serializer.Shim.SystemTextJson";
    //         })

    //     }
    //     );
    //   //  var serializer = ATAP.Utilities.Loader.Loader<ISerializerConfigurableAbstract>.LoadFromAssembly(SerializerShimName, SerializerShimNamespace, new string[] { pluginsDirectory }, services);
    //   //  var serializer = Loader.LoadFromAssembly(SerializerShimName, SerializerShimNamespace);
    //   // attribution: https://stackoverflow.com/questions/16916140/ninject-registering-an-already-created-instance-with-ninject
    //   Bind<ISerializerConfigurableAbstract>().ToConstant(serializer);
    //   //Bind<ISerializerConfigurableAbstract>().To<Serializer.Serializer>();

    // }
  }

  public class SerializationFixture : DiFixtureNinject, ISerializationFixture {

    public SerializationFixture() : base() {
      Serializer = Kernel.Get<ISerializerConfigurableAbstract>();
      // Set Serializer options for unit tests that use this base DiFixture class
      ISerializerOptionsAbstract options = new() { WriteIndented = false };
      Serializer.Configure(new SerializerOptions() { WriteIndented = false });
    }
    public SerializationFixture(IConfiguration configuration) : base(configuration) {
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
