using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;

using System.Reflection;
using System.Resources;
using System.Threading;

using System.Threading.Tasks;
using ATAP.Utilities._1Console.Properties;
using ATAP.Utilities.ComputerInventory.ProcessInfo;
//using ATAP.Utilities.LongRunningTasks;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Serilog;
//Required for Serilog.SelfLog
using Serilog.Debugging;
//  using the .Dump static method inside of Log.Debug
using ServiceStack.Text;
using ILogger = Microsoft.Extensions.Logging.ILogger;
using System.Text;
using ATAP.Utilities.ComputerInventory.Hardware;
using ATAP.Utilities.Persistence;
using System.Linq;
using Serilog.Extensions.Logging;
using Microsoft.Extensions.Localization;
using ComputerInventoryHardwareStaticExtensions = ATAP.Utilities.ComputerInventory.Hardware.StaticExtensions;
using PersistenceStaticExtensions = ATAP.Utilities.Persistence.StaticExtensions;
using Microsoft.Extensions.Hosting.Internal;
using ATAP.Utilities.ETW;
using ATAP.Utilities.HostedServices;

namespace ATAP.Utilities._1Console {
  public class DebugResourceManager : ResourceManager {

  }
  public class ExceptionResourceManager : ResourceManager {

  }
  public class UIResourceManager : ResourceManager {

  }

  partial class Program {
    // Log Program Startup to ETW (as of 06/2019, ILWeaving this assembly results in a thrown invalid CLI Program Exception
    // ATAP.Utilities.ETW.ATAPUtilitiesETWProvider.Log.MethodBoundry("<");


    // Extend the CommandLine Configuration Provider with these switch mappings
    // https://docs.microsoft.com/en-us/aspnet/core/fundamentals/configuration/?view=aspnetcore-3.0#switch-mappings
    public static readonly Dictionary<string, string> switchMappings =
        new Dictionary<string, string>
        {
                { "-Console", StringConstants.ConsoleAppConfigRootKey },
                { "-C", StringConstants.ConsoleAppConfigRootKey },
        };

    public const string userSecretsID = "TBD a GUID GOES HERE";

    public static async Task Main(string[] args) {

      // Serilog is the logging provider I picked to provide a logging solution for the _1Console application
      // Enable Serilog's internal debug logging. Note that internal logging will not write to any user-defined Sources
      //  https://github.com/serilog/serilog-sinks-file/blob/dev/example/Sample/Program.cs
      SelfLog.Enable(Console.Out);
      // Another example is at https://stackify.com/serilog-tutorial-net-logging/
      //  This brings in the System.Diagnostics.Debug namespace and writes the SelfLog there
      SelfLog.Enable(msg => Debug.WriteLine(msg));
      SelfLog.WriteLine("in Program.Main(Serilog Self Log)");
      // Another example is at https://github.com/serilog/serilog-extensions-logging/blob/dev/samples/Sample/Program.cs
      // Another is https://nblumhardt.com/2019/10/serilog-in-aspnetcore-3/
      // Creating a `LoggerProviderCollection` lets Serilog optionally write events through other dynamically-added MEL ILoggerProviders.
      var providers = new LoggerProviderCollection();
      // Setup Serilog's static logger with an initial configuration sufficient to log startup errors
      Log.Logger = new LoggerConfiguration()
          .MinimumLevel.Verbose()
          .Enrich.FromLogContext()
          .Enrich.WithThreadId()
          //.Enrich.WithHttpRequestId()
          //.Enrich.WithUserName()
          //.WithExceptionDetails()
          .WriteTo.Seq(serverUrl: "http://localhost:5341")
          .WriteTo.Providers(providers)
          .WriteTo.Debug()
          //.WriteTo.File(path: "Logs/Demo.Serilog.{Date}.log", fileSizeLimitBytes: 1024, outputTemplate: "{Timestamp:yyyy-MM-dd HH:mm:ss.fff zzz} [{Level}] {Message}{NewLine}{Exception}", rollingInterval: RollingInterval.Day, rollOnFileSizeLimit: true, retainedFileCountLimit: 31)
          .CreateLogger();

      // When running as a service, the initial working dir is usually %WinDir%\System32, but the program (and configuration files) is probably installed to a different directory
      // When running as a Console App, the initial working dir could be anything, but the program (and machine-wide configuration files) is probably installed to a different directory. When running as a console app, it is very possible that there may be local configuraiton files to load
      // get the initial startup directory
      // get the directory where the executing assembly (usually .exe) and possibly machine-wide configuration files are installed to.
      var initialStartupDirectory = Directory.GetCurrentDirectory();
      var loadedFromDirectory = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location);
      Log.Debug("in Program.Main(Serilog Static Logger): initialStartupDirectory is {initialStartupDirectory}", initialStartupDirectory);
      Log.Debug("in Program.Main(Serilog Static Logger): loadedFromDir is {loadedFromDir}", loadedFromDirectory);
      // Directory.SetCurrentDirectory(loadedFromDirectory); // Should be able to get machine-widw files by setting the content path then resetting it to initial later

      // Load the ResourceManagers from the installation direectory. These provide access to localized exception messages and debug messages
      // Cannot create more-derived types from a ResourceeManager. Gets Invalid cast. See also https://stackoverflow.com/questions/2500280/invalidcastexception-for-two-objects-of-the-same-type/30623970, the invalid cast might be because resouremanagers are not per-assembly?
      //DebugResourceManager debugResourceManager = (DebugResourceManager)new ResourceManager("ATAP.Utilities._1Console.Properties.ConsoleDebugResources", typeof(ConsoleDebugResources).Assembly);
      //ExceptionResourceManager exceptionResourceManager = (ExceptionResourceManager)new ResourceManager("ATAP.Utilities._1Console.Properties.ConsoleExceptionResources", typeof(ConsoleExceptionResources).Assembly);
      //UIResourceManager uIResourceManager = (UIResourceManager) new ResourceManager("ATAP.Utilities._1Console.Properties.ConsoleUIResources", typeof(ConsoleUIResources).Assembly);
      var debugResourceManager = new ResourceManager("ATAP.Utilities._1Console.Properties.ConsoleDebugResources", typeof(ConsoleDebugResources).Assembly);
      var exceptionResourceManager = new ResourceManager("ATAP.Utilities._1Console.Properties.ConsoleExceptionResources", typeof(ConsoleExceptionResources).Assembly);
      var uIResourceManager = new ResourceManager("ATAP.Utilities._1Console.Properties.ConsoleUIResources", typeof(ConsoleUIResources).Assembly);

      // Create the initialConfigurationBuilder for this genericHost. This creates an ordered chain of configuration providers. The first providers in the chain have the lowest priority, the last providers in the chain have a higher priority.
      //  Initial configuration does not take Environment into account.
      // ToDo: validate this is the best way to find json configuration files from both the installation directory (for installation-wide settings) and from the startup directory

      var initialGenericHostConfigurationBuilder = new ConfigurationBuilder()
          // Start with a "compiled-in defaults" for anything that is REQUIRED to be provided in configuration for Production
          .AddInMemoryCollection(GenericHostDefaultConfiguration.Production)
          // SetBasePath creates a Physical File provider pointing to the installation directory, which will be used by the following method
          .SetBasePath(loadedFromDirectory)
          // get any Production level GenericHostSettings file present in the installation directory
          .AddJsonFile(StringConstants.genericHostSettingsFileName + StringConstants.hostSettingsFileNameSuffix, optional: true)
          // and again, SetBasePath creates a Physical File provider, this time pointing to the initial startup directory, which will be used by the following method
          .SetBasePath(initialStartupDirectory)
          // get any Production level GenericHostSettings file  present in the initial startup directory
          .AddJsonFile(StringConstants.genericHostSettingsFileName + StringConstants.hostSettingsFileNameSuffix, optional: true)
          // ToDo: - Don't think we need any ASPNETCORE environment variables at program  startup time, probably remove the following line
          .AddEnvironmentVariables(prefix: StringConstants.ASPNETCOREEnvironmentVariablePrefix)
          .AddEnvironmentVariables(prefix: StringConstants.CustomEnvironmentVariablePrefix) // only environment variables that start with the given prefix
                                                                                            //.AddEnvironmentVariables() // All environment variables
                                                                                            // Add command-line switch provider and map -console to --console:true
          .AddCommandLine(args, switchMappings);

      // Create this program's initialGenericHostConfigurationRoot
      var initialGenericHostConfigurationRoot = initialGenericHostConfigurationBuilder.Build();
      // declare the final ConfigurationRoot for this genericHost, and set it to the same instance as pointed to by the initialGenericHostConfigurationRoot
      var genericHostConfigurationRoot = initialGenericHostConfigurationRoot;

      // Determine the environment (Debug, TestingUnit, TestingX, QA, QA1, QA2, ..., Staging, Production) to use from the initialGenericHostConfigurationRoot
      var initialEnvName = initialGenericHostConfigurationRoot.GetValue<string>(StringConstants.EnvironmentConfigRootKey, StringConstants.EnvironmentDefault);
      Log.Debug("{DebugMessage}", ResourceManagerExtensions.FromRM(debugResourceManager, "EnvNameInitial", initialEnvName));
      //logger.LogDebug("{DebugMessage}", ResourceManagerExtensions.FromRM(debugResourceManager, "EnvNameInitial", initialEnvName));

      // If the initialGenericHostConfigurationRoot specifies the Environment is production, then the final genericHostConfigurationRoot is correect 
      //   but if not, build a 2nd genericHostConfigurationBuilder and .Build it to create the genericHostConfigurationRoot

      // Validate that the environment provided is one this progam understands how to use, and create the final genericHostConfigurationRoot
      // The first switch statement in the following block also provides validation the the initialEnvName is one that this program understands and knows how to use

      IConfigurationBuilder? genericHostConfigurationBuilder = null;
      if (initialEnvName != StringConstants.EnvironmentProduction) {
        // Recreate the ConfigurationBuilder for this genericHost, this time including environment-specific configuration providers.
        // ToDo: Get the string for the EnvironmentProduction from someplace the has it localized
        Log.Debug("{DebugMessage}", ResourceManagerExtensions.FromRM(debugResourceManager, "RecreatingGenericHostConfigurationBuilderForEnvironment", StringConstants.EnvironmentProduction, initialEnvName));
        genericHostConfigurationBuilder = new ConfigurationBuilder()
        // Start Here the duplication
        // Start with a "compiled-in defaults" for anything that is REQUIRED to be provided in configuration for Production
        .AddInMemoryCollection(GenericHostDefaultConfiguration.Production)
        // SetBasePath creates a Physical File provider pointing to the installation directory, which will be used by the following method
        .SetBasePath(loadedFromDirectory)
        // get any Production level GenericHostSettings file present in the installation directory
        // Todo: File names should be localized
        .AddJsonFile(StringConstants.genericHostSettingsFileName + StringConstants.hostSettingsFileNameSuffix, optional: true);
        // Add environment-specific settings file
        switch (initialEnvName) {
          case StringConstants.EnvironmentDevelopment:
            genericHostConfigurationBuilder.AddJsonFile(StringConstants.genericHostSettingsFileName + "." + initialEnvName + StringConstants.hostSettingsFileNameSuffix, optional: true);
            break;
          case StringConstants.EnvironmentProduction:
            throw new InvalidOperationException(ResourceManagerExtensions.FromRM(exceptionResourceManager, "InvalidCircularEnvironment"));
          default:
            throw new NotImplementedException(ResourceManagerExtensions.FromRM(exceptionResourceManager, "InvalidSupportedEnvironment", initialEnvName));
        };
        // and again, SetBasePath creates a Physical File provider, this time pointing to the initial startup directory, which will be used by the following method
        genericHostConfigurationBuilder.SetBasePath(initialStartupDirectory)
        // get any Production level GenericHostSettings file  present in the initial startup directory
        .AddJsonFile(StringConstants.genericHostSettingsFileName + StringConstants.hostSettingsFileNameSuffix, optional: true);
        // Add environment-specific settings file
        switch (initialEnvName) {
          case StringConstants.EnvironmentDevelopment:
            genericHostConfigurationBuilder.AddJsonFile(StringConstants.genericHostSettingsFileName + "." + initialEnvName + StringConstants.hostSettingsFileNameSuffix, optional: true);
            break;
          case StringConstants.EnvironmentProduction:
            throw new InvalidOperationException(ResourceManagerExtensions.FromRM(exceptionResourceManager, "InvalidCircularEnvironment", initialEnvName));
        };
        // Add environment variables for this program
        genericHostConfigurationBuilder
            // ToDo: - Don't think we need any ASPNETCORE environment variables at program  startup time, probably remove the following line
            .AddEnvironmentVariables(prefix: StringConstants.ASPNETCOREEnvironmentVariablePrefix)
            .AddEnvironmentVariables(prefix: StringConstants.CustomEnvironmentVariablePrefix)
            .AddCommandLine(args);
        // End here the duplication
        // Set the final genericHostConfigurationRoot to the .Build() results
        genericHostConfigurationRoot = genericHostConfigurationBuilder.Build();
      }
      else {
        genericHostConfigurationRoot = initialGenericHostConfigurationRoot;
        genericHostConfigurationBuilder = null;
      }

      // Make a GenericHostBuilder with the Configuration (as above) and Logging (Serilog) and Service Options and IHostLifetime (ToDo;)
      IHostBuilder genericHostBuilder;
      // ToDo: For debugging (and tutorial), figure out how to walk every key:value pair in the ConfigurationRoot, and pretty-print it here
      // genericHostConfigurationRoot.PrintDump();
      // Log.Debug("{DebugMessage}", ResourceManagerExtensions.FromRM(debugResourceManager, "GenericHostConfigurationRoot", genericHostConfigurationRoot.PrintDump())); // .GetAllStrings().Select(x => x.Name);

      // From https://github.com/dotnet/extensions/blob/master/src/Hosting/samples/GenericHostSample/ProgramFullControl.cs
      genericHostBuilder = GenericHostBuilderExtensions.CreateGenericHostBuilder(args,
        genericHostConfigurationBuilder != null ? initialEnvName : StringConstants.EnvironmentProduction,
        loadedFromDirectory, initialStartupDirectory, exceptionResourceManager, debugResourceManager);

      // Add the specific IHostLifetime for this program (or service)
      //ToDo move to teh specifichostbuilder static method
      genericHostBuilder.ConfigureServices((hostContext, services) => {
        services.AddSingleton<IHostLifetime, ConsoleLifetime>();
      });

      // Add specific services for this application
      genericHostBuilder.ConfigureServices((hostContext, services) => {
        // Localization for the Generic Host
        services.AddLocalization(options => options.ResourcesPath = "Resources");
        services.AddHostedService<ConsoleMonitorBackgroundService>(); // Only use this service in a GenericHost having a DI-injected IHostLifetime of type ConsoleLifetime. 
        services.AddHostedService<ConsoleSourceHostedService>();  // Only use this service in a GenericHost having a DI-injected IHostLifetime of type ConsoleLifetime. 
        services.AddSingleton<IConsoleSinkHostedService, ConsoleSinkHostedService>(); // Only use this service in a GenericHost having a DI-injected IHostLifetime of type ConsoleLifetime. 
        services.AddSingleton<IConsoleSourceHostedService, ConsoleSourceHostedService>(); // Only use this service in a GenericHost having a DI-injected IHostLifetime of type ConsoleLifetime. 
        services.AddHostedService<ObservableResetableTimersHostedService>();
        services.AddHostedService<FileWatchersHostedService>();
        //services.AddHostedService<MyServiceB>();
        //services.AddHostedService<SimpleDelayLoopWithSharedCancellationToken>();
        //services.AddHostedService<SimpleDelayLoop>();
        //services.AddHostedService<SimpleConsole>();
      });

      // Surpress the startup messages appearing on the Console stdout
      //genericHostBuilder.ConfigureHostConfiguration(options => options.ConsoleLifetimeOptions.SuppressStatusMessages = true);

      // Build the Host
      var genericHost = genericHostBuilder.Build();
      IDisposable? DisposeThis = null;
      // Start it going
      try {
        using (genericHost) {
          Log.Debug("{DebugMessage}", ResourceManagerExtensions.FromRM(debugResourceManager, "GenericHostStarting", genericHostConfigurationRoot.ToString()));
          // Start the generic host running all its services and setup listeners for stopping
          // all the rigamarole in https://andrewlock.net/introducing-ihostlifetime-and-untangling-the-generic-host-startup-interactions/

          // Attribution to https://stackoverflow.com/questions/52915015/how-to-apply-hostoptions-shutdowntimeout-when-configuring-net-core-generic-host for OperationCanceledException notes
          // ToDo: further investigation to ensure OperationCanceledException should be ignored in all cases (service or console host, kestrel or IntegratedIISInProcessWebHost)
          try {
            // The RunAsync method exists on a genericHost instance having a DI container instance that resolves a IHostLifetime. There are three "standard" implementations of IHostLifetime, Console, Service (Windows) and Serviced (*nix)
            // await genericHost.RunAsync().ConfigureAwait(false);
            // From MSMQ process sample at https://github.com/dotnet/extensions/blob/master/src/Hosting/samples/SampleMsmqHost/Program.cs
            // start the genericHost
            await genericHost.StartAsync().ConfigureAwait(false);
            //ToDo: Better understanding - should the primary BackgroundService be run here instead of as a Background service?
            //// Hook console.out observer to console.in observable
            //IConsoleSourceHostedService consoleSourceHostedService = genericHost.Services.GetRequiredService<IConsoleSourceHostedService>();
            //IConsoleSinkHostedService consoleSinkHostedService = genericHost.Services.GetRequiredService<IConsoleSinkHostedService>();
            //DisposeThis = ConsoleSourceHostedService.ConsoleReadLineAsyncAsObservable().Subscribe(async evt => { await consoleSinkHostedService.WriteMessage(evt).ConfigureAwait(false); });
            // Nothing to do, the HostedServices and BackgroundServices do it all;
            // Get the CancellationToken stored in IHostApplicationLifetime ApplicationStopping
            //var applicationLifetime = genericHost.Services.GetRequiredService<IHostApplicationLifetime>();
            //var cT = applicationLifetime.ApplicationStopping;
            //// hang out until cancellation is requested
            ///
            //while (!cT.IsCancellationRequested) {
            //  cT.ThrowIfCancellationRequested();
            //}
            // wait for the genericHost to shutdown
            await genericHost.WaitForShutdownAsync().ConfigureAwait(false);
          }
          catch (OperationCanceledException e) {
            ; // Just ignore OperationCanceledException to suppress it from bubbling upwards if the main program was cancelledOperationCanceledException
              // The Exception should be shown in the ETW trace
              //ToDo: Add Error level or category to ATAPUtilitiesETWProvider, and make OperationCanceled one of the catagories
              // Specificly log the details of the cancellation (where it originated) 
              // ATAPUtilitiesETWProvider.Log.Information($"Exception in Program.Main: {e.Exception.GetType()}: {e.Exception.Message}");
          } // Other kinds of exceptions bubble up to the catch block for the surrounding try, where the Serilog logger records it
          finally {
            if (DisposeThis != null) { DisposeThis.Dispose(); }
          }

          // The IHostLifetime instance methods take over now
          // Log Program finishing to ETW if it happens to resume execution here for some reason(as of 06/2019, ILWeaving this assembly results in a thrown invalid CLI Program Exception
          // ATAP.Utilities.ETW.ATAPUtilitiesETWProvider.Log("> Program.Main");


        }
      }
      catch (Exception ex) {
        Log.Fatal(ex, "Application start-up failed");
        throw;
      }
      finally {
        Log.CloseAndFlush();
      }


    }

  }

  // This static method is an extension on a ResourceManager, that validates the requested string resource and formats it. Exceptions here usually mean a invalid/incorrect satelite assembly
  public static class ResourceManagerExtensions {
    public static string FromRM(this ResourceManager rm, string key, params string[] args) {
      try {
        return string.Format(rm.GetString(key), args);
      }
      catch (Exception e) {
        //ToDo: Create a specific exception for the key not present, or, one or more of the expected args not present. Either condition indicates aproblem wit the satelite assemblies
        throw;
      }
    }
  }

  #if TRACE
    [ETWLogAttribute]
  #endif
  public class Startup {
    public IConfiguration Configuration { get; }

    public IHostEnvironment HostEnvironment { get; }

    public Startup(ILoggerFactory loggerFactory, IConfiguration configuration, IHostEnvironment hostEnvironment, IHostApplicationLifetime hostApplicationLifetime) {
      Configuration = configuration;
      HostEnvironment = hostEnvironment;
    }

    // This method gets called by the runtime. Use this method to add servicesGenericHostBuilder to the container.
    public void ConfigureServices(IServiceCollection services) {
    }

    //      .ConfigureServices((hostContext, servicesGenericHostBuilder) =>
    //{
    //      servicesGenericHostBuilder.AddHostedService<LifetimeEventsHostedService>();
    //      servicesGenericHostBuilder.AddHostedService<TimedHostedService>();
    //    })


  }
}
