using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Resources;
using System.Text;
using System.Threading.Tasks;
using ATAP.Utilities.ComputerInventory.Software;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Serilog;

namespace ATAP.Utilities._1Console.Complicated {

  partial class ProgramComplicated {
    // For Debug builds and ReleaseWithTrace builds use the Windows ETW tracing facility and Fody to write Trace messages via ETW for method entrance and exit
    //#if TRACE
    //  [ETWLogAttribute]
    //#endif
    #region genericHostBuilder creation / configuration
    // This Builder pattern creates a GenericHostBuilder populated by ConsoleApp host or a WebHost, a specific web host as specified by a parameter
    public static IHostBuilder CreateSpecificHostBuilderComplicated(string[] args, IConfigurationRoot genericHostConfigurationRoot, ResourceManager exceptionResourceManager, ResourceManager debugResourceManager) {
      var hb = new HostBuilder()
      // The Generic Host Configuration. Applicable to all Kinds of HostBuildersToBuild (both ConsoleHosts and WebHosts) 
      .ConfigureHostConfiguration(configGenericHostBuilder => {
        // Start with a "compiled-in defaults" for anything that is required to be provided in configuration for Production
        configGenericHostBuilder.AddInMemoryCollection(GenericHostDefaultConfiguration.Production);
        // SetBasePath creates a Physical File provider, which will be used by the two following methods
        configGenericHostBuilder.SetBasePath(Directory.GetCurrentDirectory());
        configGenericHostBuilder.AddJsonFile(StringConstants.genericHostSettingsFileName + StringConstants.hostSettingsFileNameSuffix, optional: true);
        // ToDo: make sure json configuration files are picked up from both the installation directory and from the current directory
        configGenericHostBuilder.AddEnvironmentVariables(prefix: StringConstants.ASPNETCOREEnvironmentVariablePrefix);
        configGenericHostBuilder.AddEnvironmentVariables(prefix: StringConstants.CustomEnvironmentVariablePrefix);
        // ToDo: get all (resolved) commandline args from genericHostConfigurationRoot.  Note the following does not include the command line switchMappings
        if (args != null) {
          configGenericHostBuilder.AddCommandLine(args);
        }
      })
      // The Generic Host loggers, applicable to both ConsoleHosts, Services, and Services hosting WebHosts
      .ConfigureLogging((genericHostBuilderContext, loggingGenericHostBuilder) => {
        // clear default loggingBuilder providers
        loggingGenericHostBuilder.ClearProviders();
        // Always provide the loggers specified in the Logging Configuration element of the Generic Hosts ConfigurationRoot, regardless of Environment or KindOfHostBuilderToBuild
        // Read the Logging section of the ConfigurationRoot
        loggingGenericHostBuilder.AddConfiguration(genericHostBuilderContext.Configuration.GetSection("Logging"));
        // use additional logging providers based on Environment
        // ToDo: replace with latest pattern to determine environment (IsDevelopment on the new 3.x host?)
        //var tst = this.HostEnvironment.IsProduction();
        var env = genericHostBuilderContext.Configuration.GetValue<string>(StringConstants.EnvironmentConfigRootKey);
        switch (env) {
          case StringConstants.EnvironmentDevelopment:
            // This is where many developer conveniences are configured for Development environment
            // In the Development environment, Add Console and Debug Log providers (both are .Net Core provided loggers) 
            loggingGenericHostBuilder.AddConsole();
            loggingGenericHostBuilder.AddDebug();
            loggingGenericHostBuilder.AddSerilog(); // ToDo: This should not be hardcoded, it should be in ConfigurationRoot already, or, maybe added later
            break;
          case StringConstants.EnvironmentProduction:
            loggingGenericHostBuilder.AddSerilog();
            break;
          default:
            // The kindOfHostBuilderToBuildName string parsed into an enumeration, but it is not a supported value
            // ToDo replace with static method that incorporates checking for null returned value from the resourcemanager
            throw new NotSupportedException(String.Format(exceptionResourceManager.GetString("InvalidSupportedEnvironment"), env));
        }
        // use additional logging providers based on the KindOfHostBuilderToBuild
        SupportedKindsOfHostBuilders kindOfHostBuilderToBuild;
        var kindOfHostBuilderToBuildName = genericHostBuilderContext.Configuration.GetValue<string>(StringConstants.KindOfHostBuilderToBuildConfigRootKey, StringConstants.KindOfHostBuilderToBuildStringDefault);
        if (!Enum.TryParse<SupportedKindsOfHostBuilders>(kindOfHostBuilderToBuildName, out kindOfHostBuilderToBuild)) {
          throw new InvalidDataException(String.Format(exceptionResourceManager.GetString("InvalidKindOfHostBuilderToBuildString"), kindOfHostBuilderToBuildName));
        }
        if (!(kindOfHostBuilderToBuild == SupportedKindsOfHostBuilders.ConsoleHostBuilder || kindOfHostBuilderToBuild == SupportedKindsOfHostBuilders.WebHostBuilder)) {
          throw new NotImplementedException(String.Format(exceptionResourceManager.GetString("InvalidSupportedKindsOfHostBuilders"), kindOfHostBuilderToBuild));
        }
        //ToDo: hmmm... should these be part of the ATAP "standard" generic host, or should they be unique to a specific gnereic host project?
        //loggingBuilder.AddEventLog();
        //loggingBuilder.AddEventSourceLogger();
        //loggingBuilder.AddTraceSource(sourceSwitchName); // How does this logger overlap the ETWTraceLogger
      })

      // the HostedApp's configuration, this is where the ConfigurationRoot for the HostedApp is populated
      .ConfigureAppConfiguration((genericHostBuilderContext, configHostedAppHostBuilder) => {
        // Start with a "compiled-in defaults" for anything that is required to be provided in configuration to the WebHost (IIS or Kestrel)
        // configHostedAppHostBuilder.AddInMemoryCollection(DefaultConfiguration.aceCommanderWebHostConfigurationCompileTimeProduction);
        // Add additional required configuration variables to be provided in configuration for other environments
        //ToDo replace the following string case with .IsDevelopment() etc. from IHostExtensions
        string env = genericHostBuilderContext.Configuration.GetValue<string>(StringConstants.EnvironmentConfigRootKey);
        switch (env) {
          case StringConstants.EnvironmentDevelopment:
            // This is where many developer conveniences are configured for Development environment
            // In the Development environment, modify the WebHostBuilder's Configuration settings to use the UserSecrets file
            // This adds the UserSecrets file's Key:value pairs to the WebHostBuilder's Configuration for the specified userSecretsID
            // See the CommonHost .csproj file for the value of the userSecretsID
            // attribution: https://docs.microsoft.com/en-us/aspnet/core/security/app-secrets?view=aspnetcore-3.0&tabs=windows
            // ToDo: How do we implement an exception handler for issues with reading the file?
       //     configHostedAppHostBuilder.AddUserSecrets(userSecretsID);
            break;
          case StringConstants.EnvironmentProduction:
            break;
          default:
            throw new NotImplementedException(String.Format(exceptionResourceManager.GetString("InvalidSupportedEnvironment"), env));
        }
        // configHostedAppHostBuilder configuration can see the genericHost's configuration, and will default to using the Physical File provider present in the GenericHost's configuration
        configHostedAppHostBuilder.AddJsonFile(StringConstants.webHostSettingsFileName, optional: true);
        configHostedAppHostBuilder.AddJsonFile(
              // ToDo: validate `genericHostBuilderContext.HostingEnvironment.EnvironmentName` has the same value as `env.ToString()`, especially case sensitivity
              $"webHostSettingsFileName.{genericHostBuilderContext.HostingEnvironment.EnvironmentName}.json", optional: true);
        // ToDo: Investigate if adding web.config here is needed to support IISInProcesss hosted
        configHostedAppHostBuilder.AddEnvironmentVariables(prefix: StringConstants.ASPNETCOREEnvironmentVariablePrefix);
        configHostedAppHostBuilder.AddEnvironmentVariables(prefix: StringConstants.CustomEnvironmentVariablePrefix);
        // ToDo: get all (resolved) commandline args from genericHostBuilderContext.Configuration
        configHostedAppHostBuilder.AddCommandLine(args);

        // Further configuration of the local hb instance based on the kind of hostedApp to build
        SupportedKindsOfHostBuilders kindOfHostBuilderToBuild;
        var kindOfHostBuilderToBuildName = genericHostBuilderContext.Configuration.GetValue<string>(StringConstants.KindOfHostBuilderToBuildConfigRootKey, StringConstants.KindOfHostBuilderToBuildStringDefault);
        if (!Enum.TryParse<SupportedKindsOfHostBuilders>(kindOfHostBuilderToBuildName, out kindOfHostBuilderToBuild)) {
          throw new InvalidDataException(String.Format(exceptionResourceManager.GetString("InvalidKindOfHostBuilderToBuildString"), kindOfHostBuilderToBuildName));
        }
        if (!(kindOfHostBuilderToBuild == SupportedKindsOfHostBuilders.ConsoleHostBuilder || kindOfHostBuilderToBuild == SupportedKindsOfHostBuilders.WebHostBuilder)) {
          throw new NotImplementedException(String.Format(exceptionResourceManager.GetString("InvalidSupportedKindsOfHostBuilders"), kindOfHostBuilderToBuild));
        }
        switch (kindOfHostBuilderToBuild) {
          case SupportedKindsOfHostBuilders.ConsoleHostBuilder:
            // hostedAppHostBuilder, at this point, is expected to be a HostBuilder for a ConsoleApp
            //hostedAppHostBuilder.
            break;
            //ToDo: Add a case leg for a Service, and additional case legs for other kinds of lifecycle including *nix

            /*
            case SupportedKindsOfHostBuilders.WebHostBuilder:
              // Determine what kind of WebServer to build
              var webHostBuilderName = genericHostConfigurationRoot.GetValue<string>(StringConstants.WebHostBuilderToBuildConfigRootKey, StringConstants.WebHostBuilderToBuildStringDefault);
              SupportedWebHostBuilders webHostBuilderToBuild;
              if (!Enum.TryParse<SupportedWebHostBuilders>(webHostBuilderName, out webHostBuilderToBuild)) {
                throw new InvalidDataException(String.Format(exceptionResourceManager.GetString("InvalidWebHostBuilderToBuildString"), webHostBuilderName));
              }
              // hostedAppHostBuilder, at this point, is expected to be a HostBuilder for a WebApp (an IWebHostBuilder)
              (configHostedAppHostBuilder as IWebHostBuilder).ConfigureWebHostDefaults(webHostBuilder => {
                switch (webHostBuilderToBuild) {
                  case SupportedWebHostBuilders.KestrelAloneWebHostBuilder:
                    webHostBuilder.UseKestrel();
                    // This (older) post has great info and examples on setting up the Kestrel options
                    //https://github.com/aspnet/KestrelHttpServer/issues/1334
                    // In V30P5, all SS interfaces return an error that "synchronous writes are disallowed", see following issue
                    //  https://github.com/aspnet/AspNetCore/issues/8302
                    // Woraround is to configure the default web server to AllowSynchronousIO=true
                    // ToDo: see if this is fixed in a release after V30P5
                    // Configure Kestrel
                    webHostBuilder.ConfigureKestrel((context, options) => {
                      options.AllowSynchronousIO = true;
                    });
                    break;
                  case SupportedWebHostBuilders.IntegratedIISInProcessWebHostBuilder:
                    webHostBuilder.UseIISIntegration();
                    break;
                  default:
                    throw new InvalidEnumArgumentException(StringConstants.InvalidWebHostBuilderToBuildExceptionMessage);
                }
                //ToDo replace the following string case with .IsDevelopment() etc. from IHostExtensions

                string env = genericHostConfigurationRoot.GetValue<string>(StringConstants.EnvironmentConfigRootKey);
                switch (env) {
                  case StringConstants.EnvironmentDevelopment:
                    // This is where many developer conveniences are configured for Development environment
                    // In the Development environment, modify the WebHostBuilder's settings to capture startup errors, and use the detailed error pages, 
                    webHostBuilder.CaptureStartupErrors(true)
                       .UseSetting("detailedErrors", "true");
                    break;
                  case StringConstants.EnvironmentProduction:
                    break;
                  default:
                    throw new InvalidEnumArgumentException(String.Format(StringConstants.InvalidSupportedEnvironmentExceptionMessage, env));
                }
                // Configure the wwwRoot 
                //webHostBuilder.UseWebRoot(Directory.GetCurrentDirectory());
                // Configure WebHost Logging to use Serilog
                //  webHostBuilder.UseSerilog(); // hmmm UseSesrilog does not exisit for the WebHost, just higher, for the GenericHost
                // Specify the class to use when starting the WebHost
                webHostBuilder.UseStartup<Startup>();
                // The URLS to ListenTo are part of the ConfigurationRoot, either from CompiledInDefaults, or as modified by later providers
                //  In fact, there are a number configuration information items preconfigured and available of from the ASPNETCORE_ Environment Variable name patterns
                //  that the Environment Variables Configuration Provider will pickup by default, as documented 
                //   https://docs.microsoft.com/en-us/aspnet/core/fundamentals/configuration/?view=aspnetcore-3.0#environment-variables-configuration-provider
              }
              );
              break;
          */
        }

      });
      return hb;
    }
    #endregion

  }
}
