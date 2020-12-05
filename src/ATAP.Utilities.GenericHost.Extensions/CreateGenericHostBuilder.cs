using System;
using System.Collections.Generic;
using System.Text;
using System.Resources;
using ATAP.Utilities.ETW;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Hosting.Internal;

namespace ATAP.Utilities.GenericHost {
#if TRACE
  [ETWLogAttribute]
#endif
  public static class Extensions {

    /// <summary>
    /// standard form of a GenericHost builder
    /// </summary>
    /// <param name="compiledInConfiguration"></param>
    /// <param name="isProduction"></param>
    /// <param name="envNameFromConfiguration"></param>
    /// <param name="settingsFileName"></param>
    /// <param name="settingsFileNameSuffix"></param>
    /// <param name="loadedFromDirectory"></param>
    /// <param name="initialStartupDirectory"></param>
    /// <param name="envVarPrefixs"></param>
    /// <param name="args"></param>
    /// <returns></returns>
    //public static IHostBuilder ATAPStandardGenericHostBuilder(IHostLifetime hostLifetime, Action<IConfigurationBuilder> hostConfigurationBuilder) {
      public static IHostBuilder ATAPStandardGenericHostBuilderForConsoleLifetime(IConfigurationBuilder hostConfigurationBuilder, IConfigurationBuilder appConfigurationBuilder) {
        IHostBuilder hb = new HostBuilder()
                // Replace the Microsoft default container with an alternate, if desired
                //.UseServiceProviderFactory<MyContainer>(new MyContainerFactory())
                //.ConfigureContainer<MyContainer>((hostContext, container) => {
                //.ConfigureContainer((hostContext, container) => {
                // })
                .ConfigureServices((hostContext, services) => {
                  services.AddSingleton<IHostLifetime, ConsoleLifetime>();
                })
                // pass an Action<IConfigurationBuilder> to .ConfigureHostConfiguration and to .ConfigureAppConfiguration
                .ConfigureHostConfiguration((builder) => { builder = hostConfigurationBuilder; })
                .ConfigureAppConfiguration((builder) => { builder = appConfigurationBuilder; })
                // Add support for services with options
                .ConfigureServices((hostContext, services) => services.AddOptions())
                ;
      return hb;
    }
  }

}
