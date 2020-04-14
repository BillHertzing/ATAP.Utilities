
using ATAP.Utilities.ComputerInventory.Hardware;
using ATAP.Utilities.ETW;
using ATAP.Utilities.HostedServices;
using ATAP.Utilities.HostedServices.GenerateProgram;
using ATAP.Utilities.Logging;
using ATAP.Utilities.Persistence;

using Microsoft.Extensions.Localization;
using Microsoft.Extensions.Options;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Hosting.Internal;

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Reflection;
using System.Resources;
using System.Threading;
using System.Threading.Tasks;
using System.Text;
using System.Linq;
using ComputerInventoryHardwareStaticExtensions = ATAP.Utilities.ComputerInventory.Hardware.StaticExtensions;
using PersistenceStaticExtensions = ATAP.Utilities.Persistence.StaticExtensions;
using GenericHostExtensions = ATAP.Utilities.Extensions.GenericHost.Extensions;
using ConfigurationExtensions = ATAP.Utilities.Extensions.Configuration.Extensions;

using Serilog;
using ILogger = Microsoft.Extensions.Logging.ILogger;
//Required for Serilog.SelfLog
using Serilog.Debugging;

namespace ATAP.Utilities.AConsole01 {

  /// <summary>
  /// This program is going to be a Console program that displays a menu on stdout, gets a line of data (a string) from stdin, evaluates it,  performs a function or action, displays on stdout the information returned, then redisplays the menu on stdout
  /// </summary>
  static partial class Program {

    // Log Program Startup to ETW (as of 06/2019, ILWeaving this assembly results in a thrown invalid CLI Program Exception
    // ATAP.Utilities.ETW.ATAPUtilitiesETWProvider.Log.MethodBoundry("<");

    // ToDo: figure out how to localize the ConfigurationRoot keys. Use StringConstants for now

    // Extend the CommandLine Configuration Provider with these switch mappings
    // https://docs.microsoft.com/en-us/aspnet/core/fundamentals/configuration/?view=aspnetcore-3.0#switch-mappings
    public static readonly Dictionary<string, string> switchMappings =
        new Dictionary<string, string>
        {
                { "-Console", GenericHostStringConstants.ConsoleAppConfigRootKey },
                { "-C", GenericHostStringConstants.ConsoleAppConfigRootKey },
        };

    // The list of environment prefixes this program wants to use
    public static string[] hostEnvPrefixes = new string[1] { "AConsole01GenericHost" };
    public static string[] appEnvPrefixes = new string[1] { "AConsole01App" };

    // Use the Secrets pattern to access confidential information stored per-user
    public const string userSecretsID = "TBD a GUID GOES HERE";

    /// <summary>
    /// The program's Main is an <see langword="async"/> Task . Entry point to the Program
    /// </summary>
    /// <param name="args"></param>
    /// <returns></returns>

    public static async Task Main(string[] args) {

      #region Startup logger
      // Configure a startup logger, prior to getting the Logger configuration from the ConfigurationRoot
      // Serilog is the logging provider I picked to provide a logging solution for the AConsole01 application
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
      //var providers = new LoggerProviderCollection();
      // Setup Serilog's static logger with an initial configuration sufficient to log startup errors
      //logger= new LoggerConfiguration()
      //    .MinimumLevel.Verbose()
      //    .Enrich.FromLogContext()
      //    .Enrich.WithThreadId()
      //    //.Enrich.WithHttpRequestId()
      //    //.Enrich.WithUserName()
      //    //.WithExceptionDetails()
      //    .WriteTo.Seq(serverUrl: "http://localhost:5341")
      //    //.WriteTo.Providers(providers)
      //    .WriteTo.Debug()
      //    //.WriteTo.File(path: "Logs/Demo.Serilog.{Date}.log", fileSizeLimitBytes: 1024, outputTemplate: "{Timestamp:yyyy-MM-dd HH:mm:ss.fff zzz} [{Level}] {Message}{NewLine}{Exception}", rollingInterval: RollingInterval.Day, rollOnFileSizeLimit: true, retainedFileCountLimit: 31)
      //    .CreateLogger();
      //Log.Logger = logger;

      var loggerConfiguration = new LoggerConfiguration()
        .MinimumLevel.Verbose()
        .Enrich.FromLogContext()
        .Enrich.WithThreadId()
        .WriteTo.Seq(serverUrl: "http://localhost:5341")
        .WriteTo.Console(outputTemplate: "{Timestamp:HH:mm} [{Level}] ({Name:l}) {Message}\n")
        .WriteTo.Seq(serverUrl: "http://localhost:5341")
        // .WriteTo.Debug() // ToDo:
        //.Enrich.WithHttpRequestId()
        //.Enrich.WithUserName()
        //.WithExceptionDetails()
        //.WriteTo.File(path: "C:\Dropbox\whertzing\GitHub\ATAP.Utilities\devlog\A01Console.{Date}.log", fileSizeLimitBytes: 1024, outputTemplate: "{Timestamp:yyyy-MM-dd HH:mm:ss.fff zzz} [{Level}] {Message}{NewLine}{Exception}", rollingInterval: RollingInterval.Day, rollOnFileSizeLimit: true, retainedFileCountLimit: 31)
        //.WriteTo.Providers(providers)
        ;

      var factory = new LoggerFactory();
      factory.AddSerilog(loggerConfiguration.CreateLogger());
      logger = factory.CreateLogger("AConsole01");
      logger.LogInformation("A01Console Starting");
      #endregion

      #region stringLocalizers and optionally resource managers for InternationalizatioN (AKA I18N)
      // populate the string localizers for Program
      options = Options.Create(new LocalizationOptions());
      stringLocalizerFactory = new ResourceManagerStringLocalizerFactory(options, NullLoggerFactory.Instance);
      debugLocalizer = stringLocalizerFactory.Create(nameof(Resources), "ATAP.Utilities.1Console");
      exceptionLocalizer = stringLocalizerFactory.Create(nameof(Resources), "ATAP.Utilities.1Console");
      configLCL = stringLocalizerFactory.Create(nameof(Resources), "ATAP.Utilities.1Console");
      uILocalizer = stringLocalizerFactory.Create(nameof(Resources), "ATAP.Utilities.1Console");

      // If localized non-string resources are needed, uncomment the following block
      // Load the ResourceManagers from the installation directory. These provide access to all localized resources including non-string resources
      // Cannot create more-derived types from a ResourceeManager. Gets Invalid cast. See also https://stackoverflow.com/questions/2500280/invalidcastexception-for-two-objects-of-the-same-type/30623970, the invalid cast might be because resouremanagers are not per-assembly?
      // i.e., the following will no compile DebugResourceManager debugResourceManager = (DebugResourceManager)new ResourceManager("ATAP.Utilities.AConsole01.Properties.ConsoleDebugResources", typeof(ConsoleDebugResources).Assembly);
      // These will compile if needed
      //var debugResourceManager = new ResourceManager("ATAP.Utilities.AConsole01.Properties.ConsoleDebugResources", typeof(ConsoleDebugResources).Assembly);
      //var exceptionResourceManager = new ResourceManager("ATAP.Utilities.AConsole01.Properties.ConsoleExceptionResources", typeof(ConsoleExceptionResources).Assembly);
      //var uIResourceManager = new ResourceManager("ATAP.Utilities.AConsole01.Properties.ConsoleUIResources", typeof(ConsoleUIResources).Assembly);
      #endregion region

      #region initialStartup and loadedFrom direcotries
      // When running as a Windows service, the initial working dir is usually %WinDir%\System32, but the program (and configuration files) is probably installed to a different directory
      // When running as a *nix service, the initial working dir could be anything. The program (and machine-wide configuration files) are probably installed in the location whwere teh service starts. //ToDo: verify this
      // When running as a Windows or Linux Console App, the initial working dir could be anything, but the program (and machine-wide configuration files) is probably installed to a different directory.
      // When running as a console app, it is very possible that there may be local (to the initial startup directory) configuration files to load
      // get the initial startup directory
      // get the directory where the executing assembly (usually .exe) and possibly machine-wide configuration files are installed to.
      var initialStartupDirectory = Directory.GetCurrentDirectory(); //ToDo: Catch exceptions
      logger.LogDebug(debugLocalizer["{0} {1}: initialStartupDirectory: {2}", "Program", "Main", initialStartupDirectory]);
      var loadedFromDirectory = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location); //ToDo: Catch exceptions
      logger.LogDebug(debugLocalizer["{0} {1}: loadedFromDirectory: {2}", "Program", "Main", loadedFromDirectory]);
      #endregion region

      #region initial genericHostConfigurationBuilder and genericHostConfigurationRoot
      // Create the initial genericHostConfigurationBuilder for this genericHost's ConfigurationRoot. This creates an ordered chain of configuration providers. The first providers in the chain have the lowest priority, the last providers in the chain have a higher priority.
      // Initial configuration does not take Environment into account.
      var genericHostConfigurationBuilder = ConfigurationExtensions.ATAPStandardConfigurationBuilder(
        GenericHostDefaultConfiguration.Production, true, null, GenericHostStringConstants.genericHostSettingsFileName,
        GenericHostStringConstants.hostSettingsFileNameSuffix, loadedFromDirectory, initialStartupDirectory, hostEnvPrefixes, args, switchMappings);

      // Create this program's initial genericHost's ConfigurationRoot
      var genericHostConfigurationRoot = genericHostConfigurationBuilder.Build();
      #endregion

      #region (optional) Debugging the  Configuration
      // for debugging and education, uncomment this region and inspect the two section Lists (using debugger Locals) to see exactly what is in the configuration
      //    var sections = genericHostConfigurationRoot.GetChildren(); 
      //    List<IConfigurationSection> sectionsAsListOfIConfigurationSections = new List<IConfigurationSection>();
      //    List<ConfigurationSection> sectionsAsListOfConfigurationSections = new List<ConfigurationSection>();
      //    foreach (var isection in sections) sectionsAsListOfIConfigurationSections.Add(isection);
      //    foreach (var isection in sectionsAsListOfIConfigurationSections) sectionsAsListOfConfigurationSections.Add((ConfigurationSection)isection);
      #endregion

      #region Environment determination and validation
      // ToDo: Hmmm... Before the genericHost is built, have to use a StringConstant for the string that means "Production", and hope the ConfigurationRoot value for Environment matches the StringConstant
      // Determine the environment (Debug, TestingUnit, TestingX, QA, QA1, QA2, ..., Staging, Production) to use from the initialGenericHostConfigurationRoot
      var envNameFromConfiguration = genericHostConfigurationRoot.GetValue<string>(GenericHostStringConstants.EnvironmentConfigRootKey, GenericHostStringConstants.EnvironmentDefault);
      logger.LogDebug(debugLocalizer["{0} {1}: Initial environment name: {2}", "Program", "Main", envNameFromConfiguration]);

      // optional: Validate that the environment provided is one this program understands how to use
      // Accepting any string for envNameFromConfiguration might pose a security risk, as it will allow arbitrary files to be loaded into the configuration root
      switch (envNameFromConfiguration) {
        case GenericHostStringConstants.EnvironmentDevelopment:
          // ToDo: Programmers can add things here 
          break;
        case GenericHostStringConstants.EnvironmentProduction:
          // This is the expected leg for Production environment
          break;
        default:
          // IF you want to accept any environment name as OK, just comment out the following throw
          // Keep the throw in here if you want to explicitly disallow any environment other than ones specified in the switch
          throw new NotImplementedException(exceptionLocalizer["The Environment {0} is not supported", envNameFromConfiguration]);
      };
      #endregion

      #region final (Environment-aware) genericHostConfigurationBuilder and appConfigurationBuilder
      // If the initial genericHostConfigurationRoot specifies the Environment is production, then the genericHostConfigurationBuilder is correct  "as-is"
      //   but if not, build a 2nd (final) genericHostConfigurationBuilder, this time including environment-specific configuration providers
      if (envNameFromConfiguration != GenericHostStringConstants.EnvironmentProduction) {
        // Recreate the ConfigurationBuilder for this genericHost, this time including environment-specific configuration providers.
        logger.LogDebug(debugLocalizer["{0} {1}: Recreating genericHostConfigurationBuilder for Environment: {3}"], "Program", "Main", envNameFromConfiguration);
        genericHostConfigurationBuilder = ConfigurationExtensions.ATAPStandardConfigurationBuilder(GenericHostDefaultConfiguration.Production, false, envNameFromConfiguration,
          GenericHostStringConstants.genericHostSettingsFileName, GenericHostStringConstants.hostSettingsFileNameSuffix, loadedFromDirectory, initialStartupDirectory, hostEnvPrefixes, args, switchMappings);
      }

      #region recreate the logger, this time per the Logging section in ConfigurationRoot
      //ToDo: recreate the logger,
      #endregion

      // Create the appConfigurationBuilder, either as Production or as some other environment specific
      IConfigurationBuilder appConfigurationBuilder;
      Log.Debug(debugLocalizer["{0} {1}: Creating appConfigurationBuilder for Environment: {3}"], "Program", "Main", envNameFromConfiguration);
      appConfigurationBuilder = ConfigurationExtensions.ATAPStandardConfigurationBuilder(AConsole01DefaultConfiguration.Production, envNameFromConfiguration == GenericHostStringConstants.EnvironmentProduction, envNameFromConfiguration,
        AConsole01StringConstants.SettingsFileName, AConsole01StringConstants.SettingsFileNameSuffix, loadedFromDirectory, initialStartupDirectory, appEnvPrefixes, args, switchMappings);
      #endregion

      #region Configure the genericHostBuilder, including DI-Container, IHostLifetime, services in the services collection, genericHostConfiguration, and appConfiguration
      // Make a GenericHostBuilder with the Configuration (as above), and chose a specific instance of an IHostLifetime 
      var genericHostBuilder = GenericHostExtensions.ATAPStandardGenericHostBuilderForConsoleLifetime(genericHostConfigurationBuilder, appConfigurationBuilder);
      // Add the specific IHostLifetime for this program (or service)
      //ToDo: implement service and serviced, then see if this can be moved to the ATAPStandardGenericHostBuilder static extension method
      genericHostBuilder.ConfigureServices((hostContext, services) => {
        services.AddSingleton<IHostLifetime, ConsoleLifetime>();
      });

      // in Production, surpress the startup messages appearing on the Console stdout
      // genericHostBuilder.ConfigureHostConfiguration(options => options.ConsoleLifetimeOptions.SuppressStatusMessages = true);

      // For this program, I've selected Serilog as the underlying logger.
      //genericHostBuilder.UseSerilog();


      // Add specific services for this application
      genericHostBuilder.ConfigureServices((hostContext, services) => {
        // Localization for the services
        services.AddLocalization(options => options.ResourcesPath = "Resources");
        services.AddSingleton<IConsoleSinkHostedService, ConsoleSinkHostedService>();
        services.AddSingleton<IConsoleSourceHostedService, ConsoleSourceHostedService>();
        services.AddHostedService<ConsoleMonitorBackgroundService>(); // Only use this service in a GenericHost having a DI-injected IHostLifetime of type ConsoleLifetime.
        services.AddHostedService<AConsole01BackgroundService>(); // Only use this service in a GenericHost having a DI-injected IHostLifetime of type ConsoleLifetime.
        services.AddSingleton<IFileSystemWatchersHostedService, FileSystemWatchersHostedService>();
        services.AddSingleton<IObservableResetableTimersHostedService, ObservableResetableTimersHostedService>();
        //services.AddSingleton<IFileSystemWatchersAsObservableFactoryService, FileSystemWatchersAsObservableFactoryService>();
        //services.AddHostedService<MyServiceB>();
        //services.AddHostedService<SimpleDelayLoopWithSharedCancellationToken>();
        //services.AddHostedService<SimpleDelayLoop>();
        //services.AddHostedService<SimpleConsole>();
      });
      #endregion

      // Build the Host
      var genericHost = genericHostBuilder.Build();
      // Start it going
      try {
        Log.Debug(debugLocalizer["{0} {1}: \"using\" the genericHost", "Program", "Main"]);
        using (genericHost) {
          Log.Debug(debugLocalizer["{0} {1}: Calling StartAsync on the genericHost", "Program", "Main"]);

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

            // Nothing to do, the HostedServices and BackgroundServices do it all
            ////// ToDo:  Deal with application lifetime? can applications stop, and restart, within the lifetime of the genericHost
            //////// Get the CancellationToken stored in IHostApplicationLifetime ApplicationStopping
            ////// var applicationLifetime = genericHost.Services.GetRequiredService<IHostApplicationLifetime>();
            ////// var cT = applicationLifetime.ApplicationStopping;
            //////// hang out until cancellation is requested
            //////while (!cT.IsCancellationRequested) {
            //////  cT.ThrowIfCancellationRequested();
            //////}
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
            // Dispose of any resources held directly by this program. Resources held by services in the DI-Container will be disposed of by the genricHost as it tears down
            //if (DisposeThis != null) { DisposeThis.Dispose(); }
          }

          // Here, the StartAsync has completed, the Main method is over
          // Log Program finishing to ETW if it happens to resume execution here for some reason(as of 06/2019, ILWeaving this assembly results in a thrown invalid CLI Program Exception
          // ATAP.Utilities.ETW.ATAPUtilitiesETWProvider.Log(">Program.Main");
          logger.LogDebug(debugLocalizer["{0} {1}: the genericHost has exitied {3}"], "Program", "Main", envNameFromConfiguration);

        }
      }
      catch (Exception ex) {
        logger.LogCritical(exceptionLocalizer["{0} {1}: genericHost start-up failed. ExceptionMessage: {2}", "Program", "Main", ex.Message]);
        throw ex;
      }
      finally {
        // ToDo: How to do something similar for MEL logger?
        Log.CloseAndFlush();
      }
      logger.LogCritical(debugLocalizer["{0} {1}: Program:Main is exiting", "Program", "Main"]);

    }
    static IOptions<LocalizationOptions> options { get; set; }
    static ResourceManagerStringLocalizerFactory stringLocalizerFactory { get; set; }
    static IStringLocalizer debugLocalizer { get; set; }
    static IStringLocalizer exceptionLocalizer { get; set; }
    static IStringLocalizer configLCL { get; set; }
    static IStringLocalizer uILocalizer { get; set; }
    // MEL logger;
    static ILogger logger { get; set; }  

  }

  //// ToDo: move this into an ATAP extension assembly 
  //// This static method is an extension on a ResourceManager, that validates the requested string resource and formats it. Exceptions here usually mean a invalid/incorrect satelite assembly
  //public static class ResourceManagerExtensions {
  //  public static string FromRM(this ResourceManager rm, string key, params string[] args) {
  //    try {
  //      return string.Format(rm.GetString(key), args);
  //    }
  //    catch (Exception e) {
  //      //ToDo: Create a specific exception for the key not present, or, one or more of the expected args not present. Either condition indicates aproblem wit the satelite assemblies
  //      throw;
  //    }
  //  }
  //}

  //#if TRACE
  //  [ETWLogAttribute]
  //#endif
  //  public class Startup {
  //    public IConfiguration Configuration { get; }

  //    public IHostEnvironment HostEnvironment { get; }

  //    public Startup(ILoggerFactory loggerFactory, IConfiguration configuration, IHostEnvironment hostEnvironment, IHostApplicationLifetime hostApplicationLifetime) {
  //      Configuration = configuration;
  //      HostEnvironment = hostEnvironment;
  //    }

  //    // This method gets called by the runtime. Use this method to add servicesGenericHostBuilder to the container.
  //    public void ConfigureServices(IServiceCollection services) {
  //    }

  //    //      .ConfigureServices((hostContext, servicesGenericHostBuilder) =>
  //    //{
  //    //      servicesGenericHostBuilder.AddHostedService<LifetimeEventsHostedService>();
  //    //      servicesGenericHostBuilder.AddHostedService<TimedHostedService>();
  //    //    })


  //  }
}
