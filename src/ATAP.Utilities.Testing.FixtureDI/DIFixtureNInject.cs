using System;

using Microsoft.Extensions.Configuration;

using Ninject;
using Ninject.Modules;

namespace ATAP.Utilities.Testing {

  public interface IDiFixtureNinject {
    Ninject.IKernel Kernel { get; }

  }
  /// <summary>
  /// A Configurable Test Fixture that supports DI using the NInject library
  /// </summary>
  public class DiFixtureNinject : ConfigurableFixture, IDiFixtureNinject {

    /// <summary>
    /// The NInject Kernel instance
    /// </summary>
    public Ninject.IKernel Kernel { get; set; }

    public DiFixtureNinject() {
      Kernel = new StandardKernel();
    }
    public DiFixtureNinject(params INinjectModule[] modules) {
      Kernel = new StandardKernel();
      Kernel.Load(modules);
    }
    /// <summary>
    /// Constructor that takes an IConfiguration parameter
    /// </summary>
    /// <param name="configuration"></param>
    public DiFixtureNinject(IConfigurationRoot configuration) :base(configuration) {
      Kernel = new StandardKernel();
    }
    public DiFixtureNinject(IConfigurationRoot configuration, params INinjectModule[] modules) :base(configuration) {
      Kernel = new StandardKernel();
      Kernel.Load(modules);
    }
  }
}
