using System;
using System.Collections.Generic;
using System.Text;
using System.Resources;
using ATAP.Utilities.ETW;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Serilog;

namespace ATAP.Utilities._1Console {
#if TRACE
  [ETWLogAttribute]
#endif
  public static class GenericHostBuilderExtensions {
    public static IHostBuilder CreateGenericHostBuilder(string[] args, string initialEnvName, string loadedFromDirectory, string initialStartupDirectory, ResourceManager exceptionResourceManager, ResourceManager debugResourceManager) {
      IHostBuilder hb = new HostBuilder()
                // Replace the Microsoft default container with an alternate, if desired
                //.UseServiceProviderFactory<MyContainer>(new MyContainerFactory())
                //.ConfigureContainer<MyContainer>((hostContext, container) => {
                //.ConfigureContainer((hostContext, container) => {
                // })
                //.ConfigureHostConfiguration() is this needed? Should it replace teh AppConfiguration below?
                .ConfigureAppConfiguration((hostContext, config) => {  // This should be replaced with a delegatye and a reuseable lambda
                  // Start Here the duplication
                  // Start with a "compiled-in defaults" for anything that is REQUIRED to be provided in configuration for Production
                  config.AddInMemoryCollection(GenericHostDefaultConfiguration.Production)
                   // SetBasePath creates a Physical File provider pointing to the installation directory, which will be used by the following method
                   .SetBasePath(loadedFromDirectory)
                  // get any Production level GenericHostSettings file present in the installation directory
                  // Todo: File names should be localized
                  .AddJsonFile(StringConstants.genericHostSettingsFileName + StringConstants.hostSettingsFileNameSuffix, optional: true);
                  // Add environment-specific settings file
                  switch (initialEnvName) {
                    case StringConstants.EnvironmentDevelopment:
                      config.AddJsonFile(StringConstants.genericHostSettingsFileName + "." + initialEnvName + StringConstants.hostSettingsFileNameSuffix, optional: true);
                      break;
                    case StringConstants.EnvironmentProduction:
                      throw new InvalidOperationException(ResourceManagerExtensions.FromRM(exceptionResourceManager, "InvalidCircularEnvironment"));
                    default:
                      throw new NotImplementedException(ResourceManagerExtensions.FromRM(exceptionResourceManager, "InvalidSupportedEnvironment", initialEnvName));
                  };
                  // and again, SetBasePath creates a Physical File provider, this time pointing to the initial startup directory, which will be used by the following method
                  config.SetBasePath(initialStartupDirectory)
                  // get any Production level GenericHostSettings file  present in the initial startup directory
                  .AddJsonFile(StringConstants.genericHostSettingsFileName + StringConstants.hostSettingsFileNameSuffix, optional: true);
                  // Add environment-specific settings file
                  switch (initialEnvName) {
                    case StringConstants.EnvironmentDevelopment:
                      config.AddJsonFile(StringConstants.genericHostSettingsFileName + "." + initialEnvName + StringConstants.hostSettingsFileNameSuffix, optional: true);
                      break;
                    case StringConstants.EnvironmentProduction:
                      throw new InvalidOperationException(ResourceManagerExtensions.FromRM(exceptionResourceManager, "InvalidCircularEnvironment", initialEnvName));
                  };
                  // Add environment variables for this program
                  // ToDo: - Don't think we need any ASPNETCORE environment variables at program  startup time, probably remove the following line, if we can add it into a genericHost that osts a webserver
                  config.AddEnvironmentVariables(prefix: StringConstants.ASPNETCOREEnvironmentVariablePrefix)
                      .AddEnvironmentVariables(prefix: StringConstants.CustomEnvironmentVariablePrefix)
                      // Finally, add the command line arguments and any mappings
                      .AddCommandLine(args);
                  // End here the duplication

                })
                // Add support for services with options
                .ConfigureServices((hostContext, services) => services.AddOptions())
                // Logging for the GenericHost
                .UseSerilog()
                ;
      return hb;
    }
  }

}
