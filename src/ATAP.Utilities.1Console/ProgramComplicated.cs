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
using ATAP.Utilities.ComputerInventory.Software;
//using ATAP.Utilities.ETW;
//using ATAP.Utilities.LongRunningTasks;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Hosting.Internal;
using Serilog;
//Required for Serilog.SelfLog
using Serilog.Debugging;
//  using the .Dump static method inside of Log.Debug
using ServiceStack.Text;


namespace ATAP.Utilities._1Console.Complicated {

  partial class ProgramComplicated {
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

    public static async Task MainComplicated(string[] args) {

      // Serilog is the logging provider I picked to provide a logging solution for the _1Console application
      // Enable Serilog's internal debug logging. Note that internal logging will not write to any user-defined sinks
      //  https://github.com/serilog/serilog-sinks-file/blob/dev/example/Sample/Program.cs
      SelfLog.Enable(Console.Out);
      // Another example is at https://stackify.com/serilog-tutorial-net-logging/
      //  This brings in the System.Diagnostics.Debug namespace and writes the SelfLog there
      SelfLog.Enable(msg => Debug.WriteLine(msg));
      SelfLog.WriteLine("in Program.Main(Serilog Self Log)");

      // Setup Serilog's static logger with an initial configuration sufficient to log startup errors
      // Define the logger and create it
      Serilog.Core.Logger mainAsyncTaskStartupLogger = new LoggerConfiguration()
          .MinimumLevel.Verbose()
          .Enrich.FromLogContext()
          .Enrich.WithThreadId()
          //.Enrich.WithHttpRequestId()
          //.Enrich.WithUserName()
          //.WithExceptionDetails()
          .WriteTo.Seq(serverUrl: "http://localhost:5341")
          .WriteTo.Debug()
          //.WriteTo.File(path: "Logs/Demo.Serilog.{Date}.log", fileSizeLimitBytes: 1024, outputTemplate: "{Timestamp:yyyy-MM-dd HH:mm:ss.fff zzz} [{Level}] {Message}{NewLine}{Exception}", rollingInterval: RollingInterval.Day, rollOnFileSizeLimit: true, retainedFileCountLimit: 31)
          .CreateLogger();
      // ToDo: figure out how this logger seems to magically gets assigned as the logger to the Serilog static Log entry point
      Log.Logger = mainAsyncTaskStartupLogger;

      // When running as a service, the initial working dir is usually %WinDir%\System32, but the program (and configuration files) is probably installed to a different directory
      // When running as a Console App, the initial working dir could be anything
      // ToDo: figure out how to find json configuration files from both the installation directory (for installation-wide settings) and from the startup directory
      // get the initial startup directory, and go back to it after initialization 
      var initialStartupDirectory = Directory.GetCurrentDirectory();
      Log.Debug("in Program.Main(Serilog Static Logger): initialStartupDirectory is {initialStartupDirectory}", initialStartupDirectory);
      mainAsyncTaskStartupLogger.Debug("in Program.Main(MEL): initialStartupDirectory is {initialStartupDirectory}", initialStartupDirectory);
      // Cet the directory where the executing assembly (usually .exe) and configuration files are installed to.
      var loadedFromDir = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location);
      Log.Debug("in Program.Main: loadedFromDir is {loadedFromDir}", loadedFromDir);
      Directory.SetCurrentDirectory(loadedFromDir);

      // Load the ResourceManagers, provides access to localized exception messages and debug messages
      ResourceManager debugResourceManager = new ResourceManager("ATAP.Utilities._1Console.Properties.ConsoleDebugResources", typeof(ConsoleDebugResources).Assembly);
      ResourceManager exceptionResourceManager = new ResourceManager("ATAP.Utilities._1Console.Properties.ConsoleExceptionResources", typeof(ConsoleExceptionResources).Assembly);

      // Create the initialConfigurationBuilder for this genericHost. This creates an ordered chain of configuration providers. The first providers in the chain have the lowest priority, the last providers in the chain have a higher priority.
      //  Initial configuration does not take Environment into account. 
      var initialGenericHostConfigurationBuilder = new ConfigurationBuilder()
          // Start with a "compiled-in defaults" for anything that is REQUIRED to be provided in configuration for Production
          .AddInMemoryCollection(GenericHostDefaultConfiguration.Production)
          // SetBasePath creates a Physical File provider pointing to the installation directory, which will be used by the following method
          .SetBasePath(loadedFromDir)
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

      // Create this program's initial ConfigurationRoot
      var initialGenericHostConfigurationRoot = initialGenericHostConfigurationBuilder.Build();

      // Determine the environment (Debug, TestingUnit, TestingX, QA, QA1, QA2, ..., Staging, Production) to use from the initialGenericHostConfigurationRoot
      var initialEnvName = initialGenericHostConfigurationRoot.GetValue<string>(StringConstants.EnvironmentConfigRootKey, StringConstants.EnvironmentDefault);
      Log.Debug("{DebugMessage}", ResourceManagerExtensions.FromRM(debugResourceManager, "EnvNameInitial", initialEnvName));

      // declare the final ConfigurationRoot for this genericHost, and set it to the initialGenericHostConfigurationRoot
      IConfigurationRoot genericHostConfigurationRoot = initialGenericHostConfigurationRoot;

      // If the initialGenericHostConfigurationRoot specifies the Environment is production, then the final genericHostConfigurationRoot is correect 
      //   but if not, build a 2nd genericHostConfigurationBuilder and .Build it to create the genericHostConfigurationRoot

      // Validate that the environment provided is one this progam understands how to use, and create the final genericHostConfigurationRoot
      // The first switch statement in the following block also provides validation the the initialEnvName is one that this program understands and knows how to use
      if (initialEnvName != StringConstants.EnvironmentProduction) {
        // Recreate the ConfigurationBuilder for this genericHost, this time including environment-specific configuration providers.
        IConfigurationBuilder genericHostConfigurationBuilder = new ConfigurationBuilder()
        // Start with a "compiled-in defaults" for anything that is REQUIRED to be provided in configuration for Production
        .AddInMemoryCollection(GenericHostDefaultConfiguration.Production)
        // SetBasePath creates a Physical File provider pointing to the installation directory, which will be used by the following method
        .SetBasePath(loadedFromDir)
        // get any Production level GenericHostSettings file present in the installation directory
        .AddJsonFile(StringConstants.genericHostSettingsFileName + StringConstants.hostSettingsFileNameSuffix, optional: true);
        // Add environment-specific settings file
        switch (initialEnvName) {
          case StringConstants.EnvironmentDevelopment:
            genericHostConfigurationBuilder.AddJsonFile(StringConstants.genericHostSettingsFileName + "." + initialEnvName + StringConstants.hostSettingsFileNameSuffix, optional: true);
            break;
          case StringConstants.EnvironmentProduction:
            throw new InvalidOperationException(exceptionResourceManager.GetString("InvalidCircularEnvironment"));
          default:
            throw new NotImplementedException(string.Format(exceptionResourceManager.GetString("InvalidSupportedEnvironment"), initialEnvName));
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
            throw new InvalidOperationException(String.Format(exceptionResourceManager.GetString("InvalidCircularEnvironment"), initialEnvName));
          default:
            throw new NotImplementedException(String.Format(exceptionResourceManager.GetString("InvalidCircularEnvironment"), initialEnvName));
        };
        // Add environment variables for this program
        genericHostConfigurationBuilder
            // ToDo: - Don't think we need any ASPNETCORE environment variables at program  startup time, probably remove the following line
            .AddEnvironmentVariables(prefix: StringConstants.ASPNETCOREEnvironmentVariablePrefix)
            .AddEnvironmentVariables(prefix: StringConstants.CustomEnvironmentVariablePrefix)
            .AddCommandLine(args);
        // Set the final genericHostConfigurationRoot to the .Build() results
        genericHostConfigurationRoot = genericHostConfigurationBuilder.Build();
      }

      var sections = genericHostConfigurationRoot.GetChildren(); // for debugging
      List<IConfigurationSection> sectionsAsListOfIConfigurationSections = new List<IConfigurationSection>();
      List<ConfigurationSection> sectionsAsListOfConfigurationSections = new List<ConfigurationSection>();
      foreach (var isection in sections) sectionsAsListOfIConfigurationSections.Add(isection);
      foreach (var isection in sectionsAsListOfIConfigurationSections) sectionsAsListOfConfigurationSections.Add((ConfigurationSection)isection);

      // Validate that the current Environment matches the Environment from the initialConfigurationRoot
      var envName = genericHostConfigurationRoot.GetValue<string>(StringConstants.EnvironmentConfigRootKey, StringConstants.EnvironmentDefault);
      Log.Debug("{DebugMessage}", string.Format(debugResourceManager.GetString("EnvNameRunning"), envName));
      if (initialEnvName != envName) {
        throw new InvalidOperationException(String.Format(exceptionResourceManager.GetString("InvalidRedeclarationOfEnvironment"), initialEnvName, envName));
      }

      // Setup the Microsoft.Logging.Extensions Logging
      // One of what seems to me to be a limitation, is, the configurationRoot needs to exist before logging can be read from it, so, 
      //    the whole process of getting the environment above, has to be done without the loggers. That seems... wrong?
      //  MEL is anacronym for Microsoft.Extensions.Logging



      // Create a Serilog logger based on the logging section of the final ConfigurationRoot
      // The Serilog.Log is a static entry to the Serilog logging provider
      // Create a Serilog logger based on the final ConfigurationRoot and assign it to the static Serilog.Log object
      // Configure logging based on the information in ConfigurationRoot
      Serilog.Core.Logger logger = new LoggerConfiguration().ReadFrom.Configuration(genericHostConfigurationRoot).CreateLogger(); /// uncomment during development to inspect the logger that gets created 
      Log.Logger = new LoggerConfiguration().ReadFrom.Configuration(genericHostConfigurationRoot).CreateLogger();
      // To Do figure out what's important from Logger and create a DebugMessage
      var stateOfDebugLogging = Log.Logger.IsEnabled(Serilog.Events.LogEventLevel.Debug);
      Log.Debug("{DebugMessage}", string.Format(debugResourceManager.GetString("LoggerImportantCharacteristics"), stateOfDebugLogging));
      logger.Debug("{DebugMessageMEL}", string.Format(debugResourceManager.GetString("LoggerImportantCharacteristics"), stateOfDebugLogging));
      // Introduce a Cancellation token source that can be used to signal the genericHost regardless of KindOfHostedHost, and regardless of having it configured with a ConsoleApplication lifetime or a Service lifetime
      CancellationTokenSource genericHostCancellationTokenSource = new CancellationTokenSource();
      // and its token
      CancellationToken genericHostCancellationToken = genericHostCancellationTokenSource.Token;

      // Validate the value of SupportedKindsOfHostBuilders from the genericHostConfigurationRoot is one that is supported by this program
      SupportedKindsOfHostBuilders kindOfHostBuilderToBuild;
      var kindOfHostBuilderToBuildString = genericHostConfigurationRoot.GetValue<string>(StringConstants.KindOfHostBuilderToBuildConfigRootKey, StringConstants.KindOfHostBuilderToBuildStringDefault);
      if (!Enum.TryParse<SupportedKindsOfHostBuilders>(kindOfHostBuilderToBuildString, out kindOfHostBuilderToBuild)) {
        throw new InvalidDataException(String.Format(exceptionResourceManager.GetString("InvalidKindOfHostBuilderToBuildString"), kindOfHostBuilderToBuildString));
      }

      // If the value of kindOfHostBuilderToBuild is one that needs subsequent lower-level HostBuilders,
      // then validate the value of the lower-level HostBuildersToBuild from the genericHostConfigurationRoot is one that is supported by this program
      switch (kindOfHostBuilderToBuild) {
        case SupportedKindsOfHostBuilders.ConsoleHostBuilder:
          // ToDo: expand this if there ever come into existence different kinds of ConsoleHosts
          break;
        case SupportedKindsOfHostBuilders.WebHostBuilder:
          var webHostBuilderName = genericHostConfigurationRoot.GetValue<string>(StringConstants.WebHostBuilderToBuildConfigRootKey, StringConstants.WebHostBuilderToBuildStringDefault);
          SupportedWebHostBuilders webHostBuilderToBuild;
          if (!Enum.TryParse<SupportedWebHostBuilders>(webHostBuilderName, out webHostBuilderToBuild)) {
            throw new InvalidDataException(String.Format(exceptionResourceManager.GetString("InvalidWebHostBuilderToBuildString"), webHostBuilderName));
          }
          Log.Debug("{DebugMessage}", string.Format(debugResourceManager.GetString("WebHostBuilderToBuild"), webHostBuilderToBuild));
          // The webHostBuilderName string parsed into an enumeration, make sure it is a supported value
          switch (webHostBuilderToBuild) {
            case SupportedWebHostBuilders.IntegratedIISInProcessWebHostBuilder:
              break;
            case SupportedWebHostBuilders.KestrelAloneWebHostBuilder:
              break;
            default:
              throw new NotSupportedException(String.Format(exceptionResourceManager.GetString("UnsupportedWebHostBuilderToBuild"), webHostBuilderToBuild));
          }
          break;
        default:
          // The kindOfHostBuilderToBuildName string parsed into an enumeration, but it is not a supported value
          throw new NotSupportedException(String.Format(exceptionResourceManager.GetString("UnsupportedKindOfHostBuilderToBuild"), kindOfHostBuilderToBuild));
      }

      // Validate the value of GenericHostLifetime from the genericHostConfigurationRoot is one that is supported by this program
      SupportedGenericHostLifetimes genericHostLifetime;
      var genericHostLifetimeString = genericHostConfigurationRoot.GetValue<string>(StringConstants.GenericHostLifetimeConfigRootKey, StringConstants.GenericHostLifetimeStringDefault);
      if (!Enum.TryParse<SupportedGenericHostLifetimes>(genericHostLifetimeString, out genericHostLifetime)) {
        throw new InvalidDataException(String.Format(exceptionResourceManager.GetString("InvalidGenericHostLifetimeString"), genericHostLifetimeString));
      }
      if (!(genericHostLifetime == SupportedGenericHostLifetimes.ConsoleLifetime || genericHostLifetime == SupportedGenericHostLifetimes.ServiceLifetime)) {
        // The supportedGenericHostLifetimes string parsed into an enumeration, but it is not a supported value
        throw new NotSupportedException(String.Format(exceptionResourceManager.GetString("UnsupportedGenericHostLifetime"), genericHostLifetime));
      }

      // During Development and Debugging, a genericHost usually runs as a ConsoleHost.
      // In Development standalone and in Production a genericHost can run as a ConsoleHost, a WebHost, a Service running a Console Host, or a Service running a WebHost.
      // A GenericHost, when running as a Service, can be a Windows Service or a Linux *nix daemon
      // Before creating the GenericHostBuilder, we need to know the lifetime of this specific GenericHost
      // The lifetime is a ConsoleHost if any of the followiing three conditions re met:
      //  if a debugger is attached at this point in the program's execution
      //  if command line args contains --console or -console or -c
      //  if the ConfigurationRoot for the GenericHost specifies a ConsoleAppLifetime
      //  we added a switchMappings to the CommandlineArgs configuration provider so the genericHost's ConfigurationRoot provides information for two of those conditions
      var consoleHostFromCommandLineBool = genericHostConfigurationRoot.GetValue<string>(StringConstants.ConsoleAppConfigRootKey) != null;
      // combine all three conditions
      bool isConsoleHost = Debugger.IsAttached || (genericHostLifetime == SupportedGenericHostLifetimes.ConsoleLifetime) || consoleHostFromCommandLineBool;
      //  A class that encapsulates information about the kind of HostedApp and the OS
      RuntimeKind runtimeKind = new RuntimeKind(isConsoleHost);
      // ToDo: Need to expand runtTimeKind into its string representation. Will need a serializer selected in order to do this
      Log.Debug("{DebugMessage}", string.Format(debugResourceManager.GetString("RunTimeKindDetails"), runtimeKind));

      // Create the GenericHostBuilder instance based on the ConfigurationRoot
      Log.Debug("{DebugMessage}", string.Format(debugResourceManager.GetString("CallingCreateSpecificHostBuilder")));
      IHostBuilder genericHostBuilder;
      try {
        genericHostBuilder = CreateSpecificHostBuilderComplicated(args, genericHostConfigurationRoot, exceptionResourceManager, debugResourceManager);
      }
      catch (Exception) {
        // ToDo Cleanup and exit
        throw;
      }
      Log.Debug("{DebugMessage}", string.Format(debugResourceManager.GetString("GenericHostBuilderDetails"), ((IHostBuilder)genericHostBuilder).Dump<IHostBuilder>()));

      // Attach the appropriate ServiceLifetime structures to the GenericHostBuilder, build the host, and run it async
      if (!runtimeKind.IsConsoleApplication) {
        // This program is a GenericHost configured to run as a service
        // insert a singleton implementation of IHostLifetime into the genericHost's DI container, and any options needed by the IHostLifetime instance
        /*
        Log.Debug("{DebugMessage}", string.Format(debugResourceManager.GetString("AddingAnIHostLifetimeToGenericHostDI"), typeof(GenericHostAsServiceILifetimeImplementation)));
        genericHostBuilder.ConfigureServices((hostContext, servicesGenericHostBuilder) => {
          servicesGenericHostBuilder.AddSingleton<IHostLifetime, GenericHostAsServiceILifetimeImplementation>();
          // add Host options here if needed
          // Extend the generic host timeout to thecvalue specified in the configuration, in seconds, to give all running process time to do a graceful shutdown
          // Ensure that the string value specified in the ConfigurationRoot can be converted to a double
          String shutDownTimeoutInSecondsString = genericHostConfigurationRoot.GetValue<string>(StringConstants.MaxTimeInSecondsToWaitForGenericHostShutdownConfigKey, StringConstants.MaxTimeInSecondsToWaitForGenericHostShutdownStringDefault);
          Double shutDownTimeoutInSecondsDouble;
          if (!Double.TryParse(shutDownTimeoutInSecondsString, out shutDownTimeoutInSecondsDouble)) {
            // ToDo: convert to resource
            throw new InvalidCastException(String.Format(StringConstants.CannotConvertShutDownTimeoutInSecondsToDoubleExceptionMessage, shutDownTimeoutInSecondsString));
          }
          servicesGenericHostBuilder.AddOptions<HostOptions>().Configure(opts => opts.ShutdownTimeout = TimeSpan.FromSeconds(shutDownTimeoutInSecondsDouble));
        });
        // Build generic host as a service/daemon
        // Attribution to https://www.stevejgordon.co.uk/running-net-core-generic-host-applications-as-a-windows-service
        // Attribution to https://docs.microsoft.com/en-us/aspnet/core/host-and-deploy/windows-service?view=aspnetcore-3.0
        Log.Debug("in Program.Main: create genericHost by calling .Build() on the genericHostBuilder");
        var genericHost = genericHostBuilder.Build();
        //Log.Debug("in Program.Main: genericHost.Dump() = {@genericHost}", genericHost);

        // Start the generic host
        //Log.Debug("in Program.Main: webHost created, starting RunAsync and awaiting it");
        // Attribution to https://stackoverflow.com/questions/52915015/how-to-apply-hostoptions-shutdowntimeout-when-configuring-net-core-generic-host for OperationCanceledException notes
        // ToDo: further investigation to ensure OperationCanceledException should be ignored in all cases (service or console host, kestrel or IntegratedIISInProcessWebHost)
        try {
          // Note that RunAsync method only exists on a genericHost instance having a DI container instance that resolves a IHostLifetime
          await genericHost.RunAsync(genericHostCancellationToken);
        }
        catch (OperationCanceledException e) {
          ; // Just ignore OperationCanceledException to suppress  it from bubbling upwards if the main program was cancelledOperationCanceledException
            // The Exception should be shown in the ETW trace
            //ToDo: Add Error level or category to ATAPUtilitiesETWProvider, and make OperationCanceled one of the catagories
            // Specificly log the 
            //ATAPUtilitiesETWProvider.Log.Information($"Exception in Program.Main: {e.Exception.GetType()}: {e.Exception.Message}");
        } // Other kinds of exceptions bubble up to the facility that started this main program

        // The IHostLifetime instance methods take over now
        // Log Program finishing to ETW if it happens to resume execution here for some reason(as of 06/2019, ILWeaving this assembly results in a thrown invalid CLI Program Exception
        // ATAP.Utilities.ETW.ATAPUtilitiesETWProvider.Log("> Program.Main");

  */
      }
      else {
        // This program is GenericHost configured to run as a ConsoleApp
        Log.Debug("{DebugMessage}", string.Format(debugResourceManager.GetString("AddingConsoleLifetimeTogenericHostBuilder")));
        // Define the services this Console application will provide
        // Add them to the genericHostBuilder
        // ConsoleLifetime implements IHostLifetime. IHostLifetime is responsible for controlling when the application shuts down
        genericHostBuilder.ConfigureServices((context, collection) => collection.AddSingleton<IHostLifetime, ConsoleLifetime>());
        //genericHostBuilder.ConfigureServices((context, collection) => collection.AddSingleton<SimpleConsole>());
        // Build the genericHost
        var genericHost = genericHostBuilder.Build();
        //Log.Debug("in Program.Main: genericHost.Dump() = {@genericHost}", genericHost);

        // call the 
        genericHost.Run();
        // Calling UseConsoleLifetime builds the host and runs it
        //genericHostBuilder.UseConsoleLifetime();

      }

      // Override
    }
  }
  //#if TRACE
  //  [ETWLogAttribute]
  //#endif
  public class Startup {
    public IConfiguration Configuration { get; }

    public IHostEnvironment HostEnvironment { get; }

    public Startup(IConfiguration configuration, IHostEnvironment hostEnvironment) {
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


    // This method gets called by the runtime. Use this method to configure the HTTP request pipeline.
    //public void Configure(IApplicationBuilder app, IHostEnvironment hostEnvironment) {

    //  var localHostEnvironment = hostEnvironment;
    //  //app.UseServiceStack(new SSAppHost(hostEnvironment) {
    //  //  AppSettings = new NetCoreAppSettings(Configuration)
    //  //});

    //  //// The supplied lambda becomes the final handler in the HTTP pipeline
    //  //app.Run(async (context) => {
    //  //  Log.Debug("Last HTTP Pipeline handler, cwd = {0}; ContentRootPath = {1}", Directory.GetCurrentDirectory(), HostEnvironment.ContentRootPath);
    //  //  context.Response.StatusCode = 404;
    //  //  await Task.FromResult(0);
    //  //});
    //}
  }

 
}
