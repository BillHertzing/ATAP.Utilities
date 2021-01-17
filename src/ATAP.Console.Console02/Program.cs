#undef TRACE
using ATAP.Utilities.ComputerInventory.Hardware;
using ATAP.Utilities.ETW;
using ATAP.Utilities.HostedServices;
using ATAP.Utilities.HostedServices.ConsoleSourceHostedService;
using ATAP.Utilities.HostedServices.ConsoleSinkHostedService;
using ATAP.Services.GenerateCode;
using ATAP.Utilities.Loader;
using ATAP.Utilities.Logging;
using ATAP.Utilities.Persistence;
using ATAP.Utilities.Serializer;

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
using PersistenceStaticExtensions = ATAP.Utilities.Persistence.Extensions;
using GenericHostExtensions = ATAP.Utilities.GenericHost.Extensions;
using ConfigurationExtensions = ATAP.Utilities.Configuration.Extensions;
using appStringConstants = ATAP.Console.Console02.StringConstants;
using serializerStringConstants = ATAP.Utilities.Serializer.StringConstants;
using GenerateProgramServiceStringConstants = ATAP.Services.GenerateCode.StringConstants;
using Serilog;
using ILogger = Serilog.ILogger;

using Microsoft.CodeAnalysis;

namespace ATAP.Console.Console02 {

  /// <summary>
  /// This program is going to be a Console program reads the GenerateProgramDB and mechanically re-creates the Console01 program as Console01Mechanical, by populating Artifacts with mechanically created files, and then building the ATAP.Console,Console01Mechanical.csproj file
  /// </summary>
  static partial class Program {

    // Log Program Startup to ETW (as of 06/2019, ILWeaving this assembly results in a thrown invalid CLI Program Exception
    // ATAP.Utilities.ETW.ATAPUtilitiesETWProvider.Log.MethodBoundary("<");

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
    public static string[] hostEnvPrefixes = new string[1] { "Console02GenericHost_" };
    public static string[] appEnvPrefixes = new string[1] { "Console02App_" };

    // Use the Secrets pattern to access confidential information stored per-user
    public const string userSecretsID = "TBD a GUID GOES HERE";

    /// <summary>
    /// The program's Main is an <see langword="async"/> Task . Entry point to the Program
    /// </summary>
    /// <param name="args"></param>
    /// <returns></returns>

    public static async Task Main(string[] args) {


      #region Startup logger
      // Configure a startup Logger, prior to getting the Logger configuration from the ConfigurationRoot
      // Serilog is the logging provider I picked to provide a logging solution for the Console02 application
      // Enable Serilog's internal debug logging. Note that internal logging will not write to any user-defined Sources
      //  https://github.com/serilog/serilog-sinks-file/blob/dev/example/Sample/Program.cs
      Serilog.Debugging.SelfLog.Enable(System.Console.Out);
      // Another example is at https://stackify.com/serilog-tutorial-net-logging/
      //  This brings in the System.Diagnostics.Debug namespace and writes the SelfLog there
      Serilog.Debugging.SelfLog.Enable(msg => Debug.WriteLine(msg));
      Serilog.Debugging.SelfLog.WriteLine("in Program.Main(Serilog Self Log)");
      // Another example is at https://github.com/serilog/serilog-extensions-logging/blob/dev/samples/Sample/Program.cs
      // Another is https://nblumhardt.com/2019/10/serilog-in-aspnetcore-3/
      // Creating a `LoggerProviderCollection` lets Serilog optionally write events through other dynamically-added MEL ILoggerProviders.
      //var providers = new LoggerProviderCollection();

      // Setup Serilog's static Logger with an initial configuration sufficient to log startup errors
      // create a local Serilog Logger for use during Program startup
      var serilogLoggerConfiguration = new Serilog.LoggerConfiguration()
        .MinimumLevel.Verbose()
        .Enrich.FromLogContext()
        //.Enrich.WithExceptionDetails()
        .Enrich.WithThreadId()
        .WriteTo.Console(outputTemplate: "Static startup Serilog {Timestamp:HH:mm:ss zzz} [{Level}] ({Name:l}) {Message}{NewLine}{Exception}")
        .WriteTo.Seq(serverUrl: "http://localhost:5341")
        .WriteTo.File(path: @"C:\Dropbox\whertzing\GitHub\ATAP.Utilities\devlog\ATAP.Console.Console02.{Timestamp:yyyy-MM-dd HH:mm:ss}.log", fileSizeLimitBytes: 1024, outputTemplate: "Static startup Serilog {Timestamp:yyyy-MM-dd HH:mm:ss.fff zzz} [{Level}] {Message}{NewLine}{Exception}", rollingInterval: RollingInterval.Day, rollOnFileSizeLimit: true, retainedFileCountLimit: 31)
        .WriteTo.Debug();
      //.Enrich.WithHttpRequestId()
      //.Enrich.WithUserName()
      //.WriteTo.Providers(providers)

      Serilog.Core.Logger serilogLogger = serilogLoggerConfiguration.CreateLogger();
      // Set the Static Logger called Log to use this LoggerConfiguration
      Serilog.Log.Logger = serilogLogger;
      Serilog.Log.Debug("{0} {1}: The program Console02 is starting", "Program", "Main");
      Serilog.Log.Debug("{0} {1}: LoggerFactory and local Logger defined with a default startup configuration:", "Program", "Main");
      // Temp
#if TRACE
Log.Debug("TRACE is defined");
#else
      Log.Debug("TRACE is NOT defined");
#endif
      // end temp

      // Set the MEL LoggerFactory to use this LoggerConfiguration
      Microsoft.Extensions.Logging.ILoggerFactory mELoggerFactory = new Microsoft.Extensions.Logging.LoggerFactory().AddSerilog();
      Microsoft.Extensions.Logging.ILogger mELlogger = mELoggerFactory.CreateLogger("Program");
      mELlogger.LogDebug("{0} {1}: The program Console02 is starting", "Program", "Main");
      mELlogger.LogDebug("{0} {1}: LoggerFactory and local Logger defined with a default startup configuration:", "Program", "Main");
      #endregion

      #region stringLocalizers and optionally resource managers for InternationalizatioN (AKA I18N)
      // populate the string localizers for Program
      options = Options.Create(new LocalizationOptions());
      stringLocalizerFactory = new ResourceManagerStringLocalizerFactory(options, NullLoggerFactory.Instance);
      debugLocalizer = stringLocalizerFactory.Create(nameof(ATAP.Console.Console2.DebugResources), "ATAP.Console.Console02");
      exceptionLocalizer = stringLocalizerFactory.Create(nameof(ATAP.Console.Console2.ExceptionResources), "ATAP.Console.Console02");
      uILocalizer = stringLocalizerFactory.Create(nameof(ATAP.Console.Console2.UIResources), "ATAP.Console.Console02");

      // If localized non-string resources are needed, uncomment the following block
      // Load the ResourceManagers from the installation directory. These provide access to all localized resources including non-string resources
      // Cannot create more-derived types from a ResourceManager. Gets Invalid cast. See also https://stackoverflow.com/questions/2500280/invalidcastexception-for-two-objects-of-the-same-type/30623970, the invalid cast might be because ResourceManagers are not per-assembly?
      // i.e., the following will no compile DebugResourceManager debugResourceManager = (DebugResourceManager)new ResourceManager("ATAP.Console.Console02.Properties.ConsoleDebugResources", typeof(ConsoleDebugResources).Assembly);
      // These will compile if needed
      //var debugResourceManager = new ResourceManager("ATAP.Console.Console02.Properties.ConsoleDebugResources", typeof(ConsoleDebugResources).Assembly);
      //var exceptionResourceManager = new ResourceManager("ATAP.Console.Console02.Properties.ConsoleExceptionResources", typeof(ConsoleExceptionResources).Assembly);
      //var uIResourceManager = new ResourceManager("ATAP.Console.Console02.Properties.ConsoleUIResources", typeof(ConsoleUIResources).Assembly);
      #endregion region

      #region initialStartup and loadedFrom directories
      // When running as a Windows service, the initial working dir is usually %WinDir%\System32, but the program (and configuration files) is probably installed to a different directory
      // When running as a *nix service, the initial working dir could be anything. The program (and machine-wide configuration files) are probably installed in the location where the service starts. //ToDo: verify this
      // When running as a Windows or Linux Console App, the initial working dir could be anything, but the program (and machine-wide configuration files) is probably installed to a different directory.
      // When running as a console app, it is very possible that there may be local (to the initial startup directory) configuration files to load
      // get the initial startup directory
      // get the directory where the executing assembly (usually .exe) and possibly machine-wide configuration files are installed to.
      var initialStartupDirectory = Directory.GetCurrentDirectory(); //ToDo: Catch exceptions
      mELlogger.LogDebug(debugLocalizer["{0} {1}: initialStartupDirectory: {2}"], "Program", "Main", initialStartupDirectory);
      var loadedFromDirectory = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location); //ToDo: Catch exceptions
      mELlogger.LogDebug(debugLocalizer["{0} {1}: loadedFromDirectory: {2}"], "Program", "Main", loadedFromDirectory);
      #endregion region

      #region Probing Paths
      // for debugging, uncomment to see the Host Configured Probing Properties for finding dynamically loaded assemblies
      /*
      mELlogger.LogDebug(debugLocalizer["{0} {1}: The list of all *.deps.json files used by the application = {2}"], "Program", "Main", System.AppContext.GetData("APP_CONTEXT_DEPS_FILES"));
      mELlogger.LogDebug(debugLocalizer["{0} {1}: The list of TRUSTED_PLATFORM_ASSEMBLIES = {2}"], "Program", "Main", System.AppContext.GetData("TRUSTED_PLATFORM_ASSEMBLIES"));
      mELlogger.LogDebug(debugLocalizer["{0} {1}: The list of PLATFORM_RESOURCE_ROOTS = {2}"], "Program", "Main", System.AppContext.GetData("PLATFORM_RESOURCE_ROOTS"));
      mELlogger.LogDebug(debugLocalizer["{0} {1}: The list of NATIVE_DLL_SEARCH_DIRECTORIES = {2}"], "Program", "Main", System.AppContext.GetData("NATIVE_DLL_SEARCH_DIRECTORIES"));
      mELlogger.LogDebug(debugLocalizer["{0} {1}: The list of APP_PATHS = {2}"], "Program", "Main", System.AppContext.GetData("APP_PATHS"));
      mELlogger.LogDebug(debugLocalizer["{0} {1}: The list of APP_NI_PATHS = {2}"], "Program", "Main", System.AppContext.GetData("APP_NI_PATHS"));
      mELlogger.LogDebug(debugLocalizer["{0} {1}: The Environment variable ADDITIONAL_DEPS = {2}"], "Program", "Main", System.Environment.GetEnvironmentVariable("ADDITIONAL_DEPS"));
      */
      // For debugging: uncomment to see all referenced assemblies and their full name
      /*
      Assembly a = typeof(Program).Assembly;
      foreach (AssemblyName an in a.GetReferencedAssemblies() )
      {
        mELlogger.LogDebug(debugLocalizer["{0} {1}: ReferencedAssemblies Name={2}, Version={3}, Culture={4}, PublicKey token={5}"], "Program", "Main", an.Name, an.Version, an.CultureInfo.Name, (BitConverter.ToString (an.GetPublicKeyToken())));
        mELlogger.LogDebug(debugLocalizer["{0} {1}: ReferencedAssemblies FullName={2}"], "Program", "Main", an.FullName);
      }
      */
      #endregion

      #region initial genericHostConfigurationBuilder and genericHostConfigurationRoot
      // Create the initial genericHostConfigurationBuilder for this genericHost's ConfigurationRoot. This creates an ordered chain of configuration providers. The first providers in the chain have the lowest priority, the last providers in the chain have a higher priority.
      // Initial configuration does not take Environment into account.
      var genericHostConfigurationBuilder = ConfigurationExtensions.ATAPStandardConfigurationBuilder(
        GenericHostDefaultConfiguration.Production, true, null, GenericHostStringConstants.genericHostSettingsFileName,
        GenericHostStringConstants.hostSettingsFileNameSuffix, loadedFromDirectory, initialStartupDirectory, hostEnvPrefixes, args, switchMappings);

      // Create this program's initial genericHost's ConfigurationRoot
      var genericHostConfigurationRoot = genericHostConfigurationBuilder.Build();
      #endregion
      /*
      #region (optional) Debugging the  Configuration
      // for debugging and education, uncomment this region and inspect the two section Lists (using debugger Locals) to see exactly what is in the configuration
      var sections = genericHostConfigurationRoot.GetChildren();
      List<IConfigurationSection> sectionsAsListOfIConfigurationSections = new List<IConfigurationSection>();
      List<ConfigurationSection> sectionsAsListOfConfigurationSections = new List<ConfigurationSection>();
      foreach (var iSection in sections) sectionsAsListOfIConfigurationSections.Add(iSection);
      foreach (var iSection in sectionsAsListOfIConfigurationSections) sectionsAsListOfConfigurationSections.Add((ConfigurationSection)iSection);
      #endregion
      */
      #region Environment determination and validation
      // ToDo: Before the genericHost is built, have to use a StringConstant for the string that means "Production", and hope the ConfigurationRoot value for Environment matches the StringConstant
      // Determine the environment (Debug, TestingUnit, TestingX, QA, QA1, QA2, ..., Staging, Production) to use from the initialGenericHostConfigurationRoot
      var envNameFromConfiguration = genericHostConfigurationRoot.GetValue<string>(GenericHostStringConstants.EnvironmentConfigRootKey, GenericHostStringConstants.EnvironmentDefault);
      mELlogger.LogDebug(debugLocalizer["{0} {1}: Initial environment name: {2}"], "Program", "Main", envNameFromConfiguration);

      // optional: Validate that the environment provided is one this program understands how to use
      // Accepting any string for envNameFromConfiguration might pose a security risk, as it will allow arbitrary files to be loaded into the configuration root
      switch (envNameFromConfiguration) {
        case GenericHostStringConstants.EnvironmentDevelopment:
          // ToDo: Make the launching of the debugger conditional
          if (!Debugger.IsAttached) {
            // ToDo: Figure out how to make this launch a VSC debugger instead of a VS debugger
            // Debugger.Launch();
          }
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
        mELlogger.LogDebug(debugLocalizer["{0} {1}: Recreating genericHostConfigurationBuilder for Environment: {2}"], "Program", "Main", envNameFromConfiguration);
        genericHostConfigurationBuilder = ConfigurationExtensions.ATAPStandardConfigurationBuilder(GenericHostDefaultConfiguration.Production, false, envNameFromConfiguration,
          GenericHostStringConstants.genericHostSettingsFileName, GenericHostStringConstants.hostSettingsFileNameSuffix, loadedFromDirectory, initialStartupDirectory, hostEnvPrefixes, args, switchMappings);
      }

      // Create the appConfigurationBuilder, either as Production or as some other environment specific
      IConfigurationBuilder appConfigurationBuilder;
      mELlogger.LogDebug(debugLocalizer["{0} {1}: Creating appConfigurationBuilder for Environment: {2}"], "Program", "Main", envNameFromConfiguration);
      appConfigurationBuilder = ConfigurationExtensions.ATAPStandardConfigurationBuilder(Console02DefaultConfiguration.Production, envNameFromConfiguration == GenericHostStringConstants.EnvironmentProduction, envNameFromConfiguration,
        appStringConstants.SettingsFileName, appStringConstants.SettingsFileNameSuffix, loadedFromDirectory, initialStartupDirectory, appEnvPrefixes, args, switchMappings);
      // Create a local instance of the appConfiguration
      var appConfiguration = appConfigurationBuilder.Build();
      #endregion

      #region Configure the genericHostBuilder, including DI-Container, IHostLifetime, services in the services collection, genericHostConfiguration, and appConfiguration

      // Make a GenericHostBuilder with the Configuration (as above), and chose a specific instance of an IHostLifetime
      var genericHostBuilder = GenericHostExtensions.ATAPStandardGenericHostBuilderForConsoleLifetime(genericHostConfigurationBuilder, appConfigurationBuilder);

      // Add the specific IHostLifetime for this program (or service)
      //ToDo: implement service and serviced, then see if this can be moved to the ATAPStandardGenericHostBuilder static extension method
      genericHostBuilder.ConfigureServices((hostContext, services) => {
        services.AddSingleton<IHostLifetime, ConsoleLifetime>();
        //services.AddOptions<ConsoleLifetime>(options => options.SuppressStatusMessages = true);
      });

      // in Production, surpress the startup messages appearing on the Console stdout
      if (envNameFromConfiguration == GenericHostStringConstants.EnvironmentProduction) {
        //genericHostBuilder.Configure<ConsoleLifetimeOptions>(options => options.SuppressStatusMessages = true); //
      }

      #region Configure the GenericHost logging per the Logging section in ConfigurationRoot
      genericHostBuilder.ConfigureLogging((hostContext, loggingBuilder) => {
        loggingBuilder.AddConfiguration(genericHostConfigurationRoot.GetSection("Logging"));
      });
      genericHostBuilder.UseSerilog();

      // Build the GH configuration
      //genericHostConfigurationRoot = genericHostConfigurationBuilder.Build();
      // Various experiments with trying to get the Logger(s) to work as hoped for
      //// Create a LoggerFactory, configure it to use Serilog
      //loggerConfiguration = genericHostConfigurationRoot.GetSection("Logging");
      //// redefine the factory according to the new configuration
      //factory = new LoggerFactory();
      //factory.AddSerilog(loggerConfiguration.CreateLogger());
      //// Set the LogFactory in the ATAP.Utilities.Logging class
      //LogProvider.SetLogFactory(factory);
      //// Set the LogFactory in the DI-Services
      //// ToDo: LoggerFactory LoggerFactory.SetLogFactory(factory);
      //// redefine the local Logger from this factory, configured with the startup logging as defined in the Logging section of the configurationRoot
      //Logger = factory.CreateLogger("Console02");
      //serilogLogger.LogDebug(DebugLocalizer["{0} {1}: LoggerFactory and local Logger redefined per the Logging section in the configuration settings:"], "Program", "Main");
      //// Copy this tour "standard Logger
      //// Create a LoggerFactory, configure it to use Serilog
      //var factory = new LoggerFactory();
      //var x = serilogLoggerConfiguration.CreateLoggerF();
      //factory.AddSerilog(serilogLoggerConfiguration.CreateLogger());
      //LogProvider.SetLogFactory(factory);
      //// Create a local Logger from this factory, configured with the startup logging defined above
      //Logger = factory.CreateLogger("Console02");
      //// For this program, I've selected Serilog as the underlying Logger.
      //genericHostBuilder.UseSerilog();
      #endregion

      #region Get the full list of places to probe for Plugin assemblies
      /// ToDo: make this either a string[] or a delimited string
      var pluginsDirectory = appConfiguration.GetValue<string>(appStringConstants.PluginsDirectoryBaseConfigRootKey, appStringConstants.PluginsDirectoryBaseDefault);
      #endregion

      #region Select the desired Serializer library per the Serializer section in the appConfiguration
      var _serializerShimName = appConfiguration.GetValue<string>(serializerStringConstants.SerializerNameConfigRootKey, serializerStringConstants.SerializerNameDefault);
      var _serializerShimNamespace = appConfiguration.GetValue<string>(serializerStringConstants.SerializerNamespaceConfigRootKey, serializerStringConstants.SerializerNamespaceDefault);
      mELlogger.LogDebug(debugLocalizer["{0} {1}: from appConfiguration ShimName: {2} and ShimNamespace {3}"], "Program", "Main", _serializerShimName, _serializerShimNamespace);
      // ToDo: Test to ensure the assembly specified in the Configuration exists in at least one of the places probed by assembly load
      #endregion

      // Add specific services for this application
      genericHostBuilder.ConfigureServices((hostContext, services) => {
        // Localization for the services
        services.AddLocalization(options => options.ResourcesPath = "Resources");
        // Asynchronous wrappers around stdin and stdout as DI-injected services
        services.AddSingleton<IConsoleSinkHostedService, ConsoleSinkHostedService>(); // Only use this service in a GenericHost having a DI-injected IHostLifetime of type ConsoleLifetime.
        services.AddSingleton<IConsoleSourceHostedService, ConsoleSourceHostedService>(); // Only use this service in a GenericHost having a DI-injected IHostLifetime of type ConsoleLifetime.
        //services.AddHostedService<ConsoleMonitorBackgroundService>(); // Only use this service in a GenericHost having a DI-injected IHostLifetime of type ConsoleLifetime.
        // ObservableFileSystemWatchers as a DI-injected service
        //services.AddSingleton<IFileSystemWatchersAsObservableFactoryService, FileSystemWatchersAsObservableFactoryService>();
        //services.AddSingleton<IFileSystemWatchersHostedService, FileSystemWatchersHostedService>();
        // ObservableTimers as a DI-injected service
        //services.AddSingleton<IObservableResetableTimersHostedService, ObservableResetableTimersHostedService>();
        // The service for generating code
        services.AddSingleton<IGenerateProgramHostedService, GenerateProgramHostedService>(); // Only use this service in a GenericHost having a DI-injected IHostLifetime of type ConsoleLifetime.
        // The Serialization library service, dynamically loaded based on configuration settings
        // Attribution: http://codebuckets.com/2020/05/29/dynamically-loading-assemblies-for-dependency-injection-in-net-core/ , Comment by 'David'
        // ToDo: improve to cover more cases, e.g., if only one implementation per interface is found, or if multiple implementations of an interface are in the Plugin path(s), add just the one matching a namespace from configuration
        ATAP.Utilities.Loader.Loader<ISerializer>.LoadFromAssembly(_serializerShimName, _serializerShimNamespace, new string[] { pluginsDirectory }, services);
        // ToDo: Plugin services, added to the IServices collection simply because they exist somewhere in the plugins Directory tree
        // The primary service (loop) that this program does
        services.AddHostedService<Console02BackgroundService>(); // Only use this service in a GenericHost having a DI-injected IHostLifetime of type ConsoleLifetime.
      });
      #endregion

      // Build the Host
      var genericHost = genericHostBuilder.Build();

      // Use the ConfigurationSettings for ConsoleLifetimeOptions.SuppressStatusMessages
      //services.Configure<ConsoleLifetimeOptions>(opts opts.SuppressStatusMessages = Configuration["SuppressStatusMessages"] != null)

      // Start it going
      try {
        mELlogger.LogDebug(debugLocalizer["{0} {1}: \"using\" the genericHost."], "Program", "Main");

        using (genericHost) {
          mELlogger.LogDebug(debugLocalizer["{0} {1}: Calling StartAsync on the genericHost."], "Program", "Main");

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
              //ToDo: Add Error level or category to ATAPUtilitiesETWProvider, and make OperationCanceled one of the categories
              // Specifically log the details of the cancellation (where it originated)
              // ATAPUtilitiesETWProvider.Log.Information($"Exception in Program.Main: {e.Exception.GetType()}: {e.Exception.Message}");
          } // Other kinds of exceptions bubble up to the catch block for the surrounding try, where the Serilog Logger records it
          finally {
            // Dispose of any resources held directly by this program. Resources held by services in the DI-Container will be disposed of by the genericHost as it tears down
            //if (DisposeThis != null) { DisposeThis.Dispose(); }
          }

          // Here, the StartAsync has completed, the Main method is over
          // Log Program finishing to ETW if it happens to resume execution here for some reason(as of 06/2019, ILWeaving this assembly results in a thrown invalid CLI Program Exception
          // ATAP.Utilities.ETW.ATAPUtilitiesETWProvider.Log(">Program.Main");
          mELlogger.LogDebug(debugLocalizer["{0} {1}: the genericHost has exitied "], "Program", "Main");

        }
      }
      catch (Exception ex) {
        mELLogger.LogCritical(exceptionLocalizer["{0} {1}: genericHost start-up failed. ExceptionMessage: {2}", "Program", "Main", ex.Message]);
        throw;
      }
      finally {
        Log.CloseAndFlush();
        // ToDo: Figure out how to do a similar CloseAndFlush for the mELLogger
        //mELLogger.Dispose();
      }

      #region Playing with CSharpSyntaxTree
      // Just playing with the CSharpSyntaxTree feature here
      //SyntaxTree tree = CSharpSyntaxTree.ParseText(programText);
      //CompilationUnitSyntax root = tree.GetCompilationUnitRoot();
      // Use the debugger and Locals window to see these objects
      #endregion region
      mELlogger.LogDebug(debugLocalizer["{0} {1}: Program:Main is exiting", "Program", "Main"]);

    }

    #region Static properties of the program
    static IOptions<LocalizationOptions> options { get; set; }
    static ResourceManagerStringLocalizerFactory stringLocalizerFactory { get; set; }
    static IStringLocalizer debugLocalizer { get; set; }
    static IStringLocalizer exceptionLocalizer { get; set; }
    static IStringLocalizer uILocalizer { get; set; }
    // MEL Logger;
    static Microsoft.Extensions.Logging.ILogger mELLogger { get; set; }
    #endregion

  }

  //// ToDo: move this into an ATAP extension assembly
  //// This static method is an extension on a ResourceManager, that validates the requested string resource and formats it. Exceptions here usually mean a invalid/incorrect satelite assembly
  //public static class ResourceManagerExtensions {
  //  public static string FromRM(this ResourceManager rm, string key, params string[] args) {
  //    try {
  //      return string.Format(rm.GetString(key), args);
  //    }
  //    catch (Exception e) {
  //      //ToDo: Create a specific exception for the key not present, or, one or more of the expected args not present. Either condition indicates a problem wit the satelite assemblies
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

  //    public Startup(ILoggerFactory LoggerFactory, IConfiguration configuration, IHostEnvironment HostEnvironment, IHostApplicationLifetime HostApplicationLifetime) {
  //      Configuration = configuration;
  //      HostEnvironment = HostEnvironment;
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
