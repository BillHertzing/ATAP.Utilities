using System;

using Microsoft.Extensions.Configuration;
using ATAP.Utilities.Serializer;

using Ninject;

// ToDo: make a separate assembly for subloading, to be included only if the code will be loaded dynamically
#if NETCORE
using ATAP.Utilities.Loader;
using ATAP.Utilities.FileIO;
using System.Reflection;
#endif

namespace ATAP.Utilities.Testing {

  public interface IDiFixtureNInject {

  }
  /// <summary>
  /// A Test Fixture that  that support DI using the NInject  library
  /// </summary>
  public class DiFixtureNInject : SimpleFixture, IDiFixtureNInject {
    public DiFixtureNInject() {
      Kernel = new StandardKernel(new SerializerInjectionModule());
    }
    /// <summary>
    /// Constructor that takes an IConfiguration parameter
    /// </summary>
    /// <param name="configuration"></param>
    public DiFixtureNInject(IConfiguration configuration) {
      Kernel = new StandardKernel(new SerializerInjectionModule(configuration: configuration));
    }
    /// <summary>
    /// The NInject Kernel instance
    /// </summary>
    public Ninject.IKernel Kernel { get; set; }
  }
}
