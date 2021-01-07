using System;

using Microsoft.Extensions.Configuration;
using ATAP.Utilities.Serializer;

using Ninject;

namespace ATAP.Utilities.Testing {

  public interface IDiFixture {
    ISerializer Serializer { get; set; }
  }

  public class SerializerInjectionModule : Ninject.Modules.NinjectModule {
    string SerializerShimName { get; set; }
    string SerializerShimNamespace { get; set; }
    public SerializerInjectionModule() : this("ATAP.Utilities.Serializer.Shim.SystemTextJson.dll", "ATAP.Utilities.Serializer") {}
    public SerializerInjectionModule(IConfiguration configuration = default){
      if (configuration == null) {
        throw new ArgumentNullException("configuration");
      }
      // ToDo:Use stringconstants from Serializer.StringConstants to read from the configurationroot
      SerializerShimName = "ATAP.Utilities.Serializer.Shim.SystemTextJson.dll";
      SerializerShimNamespace ="ATAP.Utilities.Serializer";
    }
    public SerializerInjectionModule(string serializerShimName = default, string serializerShimNamespace = default) {
      if (String.IsNullOrWhiteSpace(serializerShimName)) { throw new ArgumentNullException(nameof(serializerShimName)); } else { SerializerShimName = serializerShimName; }
      if (String.IsNullOrWhiteSpace(serializerShimNamespace)) { throw new ArgumentNullException(nameof(serializerShimNamespace)); } else { SerializerShimNamespace = serializerShimNamespace; }
    }

    public override void Load() {
      // ToDo make this lazy ISerializer t = ATAP.Utilities.Serializer.SerializerLoader.LoadSerializerFromAssembly();
      var serializer = ATAP.Utilities.Serializer.SerializerLoader.LoadSerializerFromAssembly(SerializerShimName, SerializerShimNamespace);
      //attribution: https://stackoverflow.com/questions/16916140/ninject-registering-an-already-created-instance-with-ninject
      Bind<ISerializer>().ToConstant(serializer);
      //Bind<ISerializer>().To<Serializer.Serializer>();

    }
  }
  public class DiFixture : IDiFixture {
    public DiFixture() {
      Kernel = new StandardKernel(new SerializerInjectionModule());
      Serializer = Kernel.Get<ISerializer>();
      // Set Serializer options for unit tests that use this base DiFixture class
      Serializer.Configure(WriteIndented : false);
    }
    public DiFixture(IConfiguration configuration) {
      Kernel = new StandardKernel(new SerializerInjectionModule(configuration:configuration));
      // Bind the Serializer implementation to the interface using Ninject conventions
      Serializer = Kernel.Get<ISerializer>();
    }
    public DiFixture(string serializerShimName = default, string serializerShimNamespace = default) {
      if (String.IsNullOrWhiteSpace(serializerShimName)) { throw new ArgumentNullException(nameof(serializerShimName)); }
      if (String.IsNullOrWhiteSpace(serializerShimNamespace)) { throw new ArgumentNullException(nameof(serializerShimNamespace)); }

      Kernel = new StandardKernel(new SerializerInjectionModule(
         serializerShimName
        , serializerShimNamespace

));
      // Bind the Serializer implementation to the interface using Ninject conventions
      Serializer = Kernel.Get<ISerializer>();
    }

    public ISerializer Serializer { get; set; }
    private Ninject.IKernel Kernel { get; set; }
  }
}
