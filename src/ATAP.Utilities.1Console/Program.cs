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
using ILogger = Microsoft.Extensions.Logging.ILogger;
using System.Text;
using ATAP.Utilities.ComputerInventory.Hardware;
using ATAP.Utilities.Persistence;
using System.Linq;
using StaticExtensions = ATAP.Utilities.ComputerInventory.Hardware.StaticExtensions;

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
      // Enable Serilog's internal debug logging. Note that internal logging will not write to any user-defined sinks
      //  https://github.com/serilog/serilog-sinks-file/blob/dev/example/Sample/Program.cs
      SelfLog.Enable(Console.Out);
      // Another example is at https://stackify.com/serilog-tutorial-net-logging/
      //  This brings in the System.Diagnostics.Debug namespace and writes the SelfLog there
      SelfLog.Enable(msg => Debug.WriteLine(msg));
      SelfLog.WriteLine("in Program.Main(Serilog Self Log)");

      // Setup Serilog's static logger with an initial configuration sufficient to log startup errors
      // Define the logger and create it
      Serilog.Core.Logger logger = new LoggerConfiguration()
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
      // Assign this logger as the logger used by the Serilog static Log entry point
      Log.Logger = logger;

      // When running as a service, the initial working dir is usually %WinDir%\System32, but the program (and configuration files) is probably installed to a different directory
      // When running as a Console App, the initial working dir could be anything
      // get the initial startup directory, and later go back to it after initialization 
      var initialStartupDirectory = Directory.GetCurrentDirectory();
      Log.Debug("in Program.Main(Serilog Static Logger): initialStartupDirectory is {initialStartupDirectory}", initialStartupDirectory);
      logger.Debug("in Program.Main(MEL): initialStartupDirectory is {initialStartupDirectory}", initialStartupDirectory);
      // Cet the directory where the executing assembly (usually .exe) and configuration files are installed to.
      var loadedFromDirectory = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location);
      Log.Debug("in Program.Main: loadedFromDir is {loadedFromDir}", loadedFromDirectory);
      Directory.SetCurrentDirectory(loadedFromDirectory);

      // Load the ResourceManagers from the installation direectory. These provide access to localized exception messages and debug messages
      // Cannot create more-derived types from a ResourceeeManager. Gets Invalid cast. See also https://stackoverflow.com/questions/2500280/invalidcastexception-for-two-objects-of-the-same-type/30623970, the invalid cast might be because resouremanagers are not per-assembly?
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
      logger.Debug("{DebugMessage}", ResourceManagerExtensions.FromRM(debugResourceManager, "EnvNameInitial", initialEnvName));

      // If the initialGenericHostConfigurationRoot specifies the Environment is production, then the final genericHostConfigurationRoot is correect 
      //   but if not, build a 2nd genericHostConfigurationBuilder and .Build it to create the genericHostConfigurationRoot

      // Validate that the environment provided is one this progam understands how to use, and create the final genericHostConfigurationRoot
      // The first switch statement in the following block also provides validation the the initialEnvName is one that this program understands and knows how to use

      IConfigurationBuilder? genericHostConfigurationBuilder = null;
      if (initialEnvName != StringConstants.EnvironmentProduction) {
        // Recreate the ConfigurationBuilder for this genericHost, this time including environment-specific configuration providers.
        // ToDo: Get the string for the Environment_Production from someplace the has it localized
        logger.Debug("{DebugMessage}", ResourceManagerExtensions.FromRM(debugResourceManager, "RecreatingGenericHostConfigurationBuilderForEnvironment", StringConstants.EnvironmentProduction, initialEnvName));
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

      IHostBuilder genericHostBuilder;
      // ToDo: For debugging (and tutorial), figure out how to walk every key:value pair in the ConfigurationRoot, and pretty-print it here
      logger.Debug("{DebugMessage}", ResourceManagerExtensions.FromRM(debugResourceManager, "GenericHostConfigurationRoot", genericHostConfigurationRoot.ToString()));
      if (genericHostConfigurationBuilder != null) {
        // From https://github.com/dotnet/extensions/blob/master/src/Hosting/samples/GenericHostSample/ProgramFullControl.cs
        genericHostBuilder = HostBuilderExtensions.CreateSpecificHostBuilder(args, initialEnvName, loadedFromDirectory, initialStartupDirectory, exceptionResourceManager, debugResourceManager);
      }
      else {
        genericHostBuilder = HostBuilderExtensions.CreateSpecificHostBuilder(args, null, loadedFromDirectory, initialStartupDirectory, exceptionResourceManager, debugResourceManager);
      }

      // Add specific services for this application
      genericHostBuilder.ConfigureServices((hostContext, services) => {
        //services.AddHostedService<MyServiceA>();
        //services.AddHostedService<MyServiceB>();
        services.AddHostedService<FunctionSelectorUI>();
      });

      // Build the Host
      var genericHost = genericHostBuilder.Build();

      using (genericHost) {
        logger.Debug("{DebugMessage}", ResourceManagerExtensions.FromRM(debugResourceManager, "GenericHostStarting", genericHostConfigurationRoot.ToString()));
        // Start the generic host running all its services and setup listeners for stopping
        // all the rigamarole in https://andrewlock.net/introducing-ihostlifetime-and-untangling-the-generic-host-startup-interactions/

        //Log.Debug("in Program.Main: genericHost created, starting RunAsync and awaiting it");
        // Attribution to https://stackoverflow.com/questions/52915015/how-to-apply-hostoptions-shutdowntimeout-when-configuring-net-core-generic-host for OperationCanceledException notes
        // ToDo: further investigation to ensure OperationCanceledException should be ignored in all cases (service or console host, kestrel or IntegratedIISInProcessWebHost)
        try {
          // Note that RunAsync method only exists on a genericHost instance having a DI container instance that resolves a IHostLifetime, but that there are three "standard" implementations of IHostLifetime
          await genericHost.RunAsync(); // genericHost.RunAsync(genericHostCancellationToken);

        }
        catch (OperationCanceledException e) {
          ; // Just ignore OperationCanceledException to suppress it from bubbling upwards if the main program was cancelledOperationCanceledException
            // The Exception should be shown in the ETW trace
            //ToDo: Add Error level or category to ATAPUtilitiesETWProvider, and make OperationCanceled one of the catagories
            // Specificly log the details of the cancellation (where it originated) 
            //ATAPUtilitiesETWProvider.Log.Information($"Exception in Program.Main: {e.Exception.GetType()}: {e.Exception.Message}");
        } // Other kinds of exceptions bubble up to the facility that started this main program

        // The IHostLifetime instance methods take over now
        // Log Program finishing to ETW if it happens to resume execution here for some reason(as of 06/2019, ILWeaving this assembly results in a thrown invalid CLI Program Exception
        // ATAP.Utilities.ETW.ATAPUtilitiesETWProvider.Log("> Program.Main");

        //try {
        //  await genericHost.StopAsync();
        //}
        //catch (OperationCanceledException e) {
        //  ; // Just ignore OperationCanceledException to suppress  it from bubbling upwards if the main program was cancelledOperationCanceledException
        //}

        //Console.WriteLine("Stopped!");
      }
    }
  }

  //internal class MyContainerFactory : IServiceProviderFactory<MyContainer> {
  //  public MyContainer CreateBuilder(IServiceCollection services) {
  //    return new MyContainer();
  //  }

  //  public IServiceProvider CreateServiceProvider(MyContainer containerBuilder) {
  //    throw new NotImplementedException();
  //  }
  //}


  //internal class MyContainer {
  //}

  public class FunctionSelectorUI : BackgroundService {
    public FunctionSelectorUI(ILoggerFactory loggerFactory, IConfiguration configuration, IHostEnvironment hostEnvironment, IHostApplicationLifetime hostApplicationLifetime) {
      Logger = loggerFactory.CreateLogger<FunctionSelectorUI>();
      Configuration = configuration;
      HostApplicationLifetime = hostApplicationLifetime;
      HostEnvironment = hostEnvironment;
    }

    public ILogger Logger { get; }
    public IHostApplicationLifetime HostApplicationLifetime { get; }
    public IConfiguration Configuration { get; }
    public IHostEnvironment HostEnvironment { get; }

    protected override async Task ExecuteAsync(CancellationToken cancellationToken) {
      Logger.LogInformation("FunctionSelectorUI is starting.");
      // Logger.Debug("{DebugMessage}", ResourceManagerExtensions.FromRM(debugResourceManager, "FunctionSelectorUIServiceStarting"));


      cancellationToken.Register(() => Logger.LogInformation("FunctionSelectorUI is stopping."));

      StringBuilder mesg = new StringBuilder();
      // Create a list of choices
      IEnumerable<string> choices = new List<string>() { "1." };
      string inputLineString;
      while (!cancellationToken.IsCancellationRequested) {
        foreach (var choice in choices) { Console.WriteLine(choice); }
        Console.WriteLine("Enter Selection");
        try {
          inputLineString = Console.ReadLine();
        }
        catch (IOException e) {

          throw;
        }

        mesg.Append(string.Format("You selected: {0}", inputLineString));
        Console.WriteLine(mesg);
        mesg.Clear();
        switch (inputLineString) {
          case "1":
            var rootString = Configuration.GetValue<string>(StringConstants.RootStringConfigRootKey, StringConstants.RootStringDefault);
            var asyncFileReadBlockSize = Configuration.GetValue<int>(StringConstants.AsyncFileReadBlockSizeConfigRootKey, int.Parse(StringConstants.AsyncFileReadBlockSizeDefault));  // ToDo: should validate in case the StringConstants assembly is messed up?
            var enableHash = Configuration.GetValue<bool>(StringConstants.EnableHashBoolConfigRootKey, bool.Parse(StringConstants.EnableHashBoolConfigRootKeyDefault));  // ToDo: should validate in case the StringConstants assembly is messed up?
            var enablePersistence = Configuration.GetValue<bool>(StringConstants.EnablePersistenceBoolConfigRootKey, bool.Parse(StringConstants.EnablePersistenceBoolDefault));// ToDo: should validate in case the StringConstants assembly is messed up?
            var enableProgress = Configuration.GetValue<bool>(StringConstants.EnableProgressBoolConfigRootKey, bool.Parse(StringConstants.EnableProgressBoolDefault));// ToDo: should validate in case the StringConstants assembly is messed up?
            var temporaryDirectoryBase = Configuration.GetValue<string>(StringConstants.TemporaryDirectoryBaseConfigRootKey, StringConstants.TemporaryDirectoryBaseDefault);
            var WithPersistenceNodeFileRelativePath = Configuration.GetValue<string>(StringConstants.WithPersistenceNodeFileRelativePathConfigRootKey, StringConstants.WithPersistenceNodeFileRelativePathDefault);
            var WithPersistenceEdgeFileRelativePath = Configuration.GetValue<string>(StringConstants.WithPersistenceEdgeFileRelativePathConfigRootKey, StringConstants.WithPersistenceEdgeFileRelativePathDefault);
            var filePaths = new string[2] { temporaryDirectoryBase + WithPersistenceNodeFileRelativePath, temporaryDirectoryBase + WithPersistenceEdgeFileRelativePath };
            mesg.Append(string.Format("Running PartitionInfoEx Extension Function ConvertFileSystemToObjectGraph, on rootString {0} with an asyncFileReadBlockSize of {1} with hashihg enabled: {2} ; progress enabled {3} and persistence enabled: {4}", rootString, asyncFileReadBlockSize, enableHash, enableProgress, enablePersistence));
            if (enablePersistence) {
              mesg.Append(string.Format(" and persistence filePaths {0}", string.Join(',', filePaths)));
            }
            try { Console.WriteLine(mesg); }
            catch (IOException e) {
              throw;
            }
            // rethrow it for now, eventually accept a Func or Action to possibly filter and accept some, or filter and rethrow a custom exception, or return some in a Results class
            //ret = new Results(false, e);

            #region ProgressReporting
            ConvertFileSystemToGraphProgress? convertFileSystemToGraphProgress; ;
            if (enableProgress) {
              convertFileSystemToGraphProgress = new ConvertFileSystemToGraphProgress();
            }
            else {
              convertFileSystemToGraphProgress = null;
            }
            #endregion
            #region PersistenceViaFiles
            // Ensure the Node and Edge files are empty and can be written to 

            // Call the SetupViaFileFuncBuilder here, execute the Func that comes back, with filePaths as the argument
            // ToDo: create a function that will create subdirectories if needed to fulfill path, and use that function when creating the temp fiiles
            var setupResults = ATAP.Utilities.Persistence.StaticExtensions.SetupViaFileFuncBuilder()(new SetupViaFileData(filePaths));

            //var insertFunc = InsertViaFileFuncBuilder(setupResults);
            // Create an insertFunc that references the local variable setupResults, closing over it
            var insertFunc = new Func<IEnumerable<IEnumerable<object>>, IInsertViaFileResults>((insertData) => {
              int numberOfFiles = insertData.ToArray().Length;
              int numberOfStreamWriters = setupResults.StreamWriters.Length;
              for (var i = 0; i < numberOfFiles; i++) {
                foreach (string str in insertData.ToArray()[i]) {
                  //ToDo: add async versions await setupResults.StreamWriters[i].WriteLineAsync(str);
                  //ToDo: exception handling
                  setupResults.StreamWriters[i].WriteLine(str);
                }
              }
              return new InsertViaFileResults(true);
            });

            Persistence<IInsertResultsAbstract> persistence = new Persistence<IInsertResultsAbstract>(insertFunc);
            #endregion
            ConvertFileSystemToGraphResult convertFileSystemToGraphResult;
            Stopwatch stopWatch = new Stopwatch();
            stopWatch.Start();
            try {
              Func<Task<ConvertFileSystemToGraphResult>> run = () => StaticExtensions.ConvertFileSystemToGraphAsyncTask(rootString, asyncFileReadBlockSize, enableHash, convertFileSystemToGraphProgress, null, cancellationToken);
              convertFileSystemToGraphResult = await run.Invoke().ConfigureAwait(false);
            }
            catch (Exception) {
              throw;
            }

            stopWatch.Stop();
            mesg.Clear();
            mesg.Append(string.Format("Running the function took {0} milliseconds", stopWatch.ElapsedMilliseconds));
            try { Console.WriteLine(mesg); }
            catch (IOException e) {
              throw;
            }

            break;
          default:
            mesg.Append(string.Format("InvalidInputDoesNotMatchAvailableChoices {0}", inputLineString));
            break;
        }

        try {
          Console.WriteLine(mesg);
        }
        catch (IOException e) {
          // rethrow it for now, eventually accept a Func or Action to possibly filter and accept some, or filter and rethrow a custom exception, or return some in a Results class
          //ret = new Results(false, e);
          throw;
        }

        //await Task.Delay(TimeSpan.FromSeconds(1), stoppingToken); // Throttle it if necessary
      }

      Logger.LogInformation("FunctionSelectorUI background task is stopping.");

    }

  }



  public class MyServiceA : BackgroundService {
    public MyServiceA(ILoggerFactory loggerFactory) {
      Logger = loggerFactory.CreateLogger<MyServiceA>();
    }

    public ILogger Logger { get; }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken) {
      Logger.LogInformation("MyServiceA is starting.");

      stoppingToken.Register(() => Logger.LogInformation("MyServiceA is stopping."));

      string inputLineString;
      while (!stoppingToken.IsCancellationRequested) {
        inputLineString = Console.ReadLine();
        Logger.LogInformation("MyServiceA read {0}", inputLineString);

        await Task.Delay(TimeSpan.FromSeconds(1), stoppingToken);
      }

      Logger.LogInformation("MyServiceA background task is stopping.");
    }
  }

  public class MyServiceB : IHostedService, IDisposable {
    private bool _stopping;
    private Task _backgroundTask;

    public MyServiceB(ILoggerFactory loggerFactory) {
      Logger = loggerFactory.CreateLogger<MyServiceB>();
    }

    public ILogger Logger { get; }

    public Task StartAsync(CancellationToken cancellationToken) {
      Logger.LogInformation("MyServiceB is starting.");
      _backgroundTask = BackgroundTask();
      return Task.CompletedTask;
    }

    private async Task BackgroundTask() {
      while (!_stopping) {
        await Task.Delay(TimeSpan.FromSeconds(1));
        Logger.LogInformation("MyServiceB is writing to ConsoleOut.");
        Console.WriteLine("MyServiceB is writing to ConsoleOut!");
      }

      Logger.LogInformation("MyServiceB background task is stopping.");
    }

    public async Task StopAsync(CancellationToken cancellationToken) {
      Logger.LogInformation("MyServiceB is stopping.");
      _stopping = true;
      if (_backgroundTask != null) {
        // TODO: cancellation
        await _backgroundTask;
      }
    }

    public void Dispose() {
      Logger.LogInformation("MyServiceB is disposing.");
    }
  }

  public class WriteToConsole : IHostedService, IDisposable {
    private bool _stopping;
    private Task _backgroundTask;

    public WriteToConsole(ILoggerFactory loggerFactory) {
      Logger = loggerFactory.CreateLogger<WriteToConsole>();
    }

    public ILogger Logger { get; }

    public class Results {
      public Results(bool success, Exception? e) {
        Success = success;
        this.e = e;
      }

      bool Success { get; set; }
      Exception? e { get; set; }
    }
    public Task StartAsync(CancellationToken cancellationToken) {
      Logger.LogInformation("WriteToConsole is starting.");
      _backgroundTask = BackgroundTask(cancellationToken);
      return Task.CompletedTask;
    }


    private async Task BackgroundTask(CancellationToken cancellationToken) {
      while (!_stopping) {
        // wait async for a line(string) to be presented on stdin, continue on any thread
        string inputString;

        // ToDo: Merge the cancellationToken of the GenericHost with this one

        //static async Task<Results> writeToConsoleTaskAsync(string outstr, CancellationToken cancellationToken) {
        //  Results ret = new Results(false,null);
        //  try {
        //    Console.WriteLine(outstr);
        //  }
        //  catch (IOException e) {
        //    // capture the exception and send it back to the consumer
        //    ret = new Results(false, e);
        //  }
        //  return ret;
        //}

        //try {
        //  Func<Task<Results>> run = (outstr, cancellationToken) => { writeToConsoleTaskAsync(outstr, cancellationToken)
        //    };
        //  Results results = await run.Invoke().ConfigureAwait(false);
        //}
        //catch (Exception) {
        //  // record the exception (trace or log)
        //  // rethrow it
        //  throw;
        //}
        //finally {
        //  cancellationTokenSource.Dispose();
        //}

        //Func<string, int, Task<string>> func = waitForStringTaskBuilder;
        //Task<string> waitForStringTask = waitForStringTaskBuilder("", 0);

        //public static async Task<string> LoadAsync(string message, int count) {
        //  await Task.Delay(1500);

        //  var countOutput = count == 0 ? string.Empty : count.ToString();
        //  var output = $"{message} {countOUtput}Exceuted Successfully !";
        //  Console.WriteLine(output);

        //  return "Finished";
        //}
        //Func<string, Task<string>> Builder = new Func<string, Task<string>>(() => { }
        //Task<string> waitForStringTask = new Task<string>(async () => {

        //});

        //try {
        //  Func<Task<ConvertFileSystemToGraphResult>> run = () => StaticExtensions.ConvertFileSystemToGraphAsyncTask(rootstring, asyncFileReadBlockSize, convertFileSystemToGraphProgress, null, cancellationToken);
        //  convertFileSystemToGraphResult = await run.Invoke().ConfigureAwait(false);
        //}
        //catch (Exception) {
        //  throw;
        //}
        //finally {
        //  cancellationTokenSource.Dispose();
        //}

        //    Task<string> oldwaitForStringTask = new Task<string>(async () => {
        //      string ret;
        //      await Task.Delay(TimeSpan.FromSeconds(1));
        //      ret = "abc";
        //      return ret;
        //    });

        //    inputString = waitForStringTask.Result;
        //    Logger.LogInformation("WriteToConsole is writing {0} to ConsoleOut.", inputString);
        //    Console.WriteLine(inputString);
        //  }

        //  Logger.LogInformation("MyServiceB background task is stopping.");
        //}
        //Func<string, int, Task<string>> func = LoadAsync;
        //Task<string> task = func("", 0); // pass parameters you want

        //var result = await task; // later in async method
      }
    }

    public async Task StopAsync(CancellationToken cancellationToken) {
      Logger.LogInformation("MyServiceB is stopping.");
      _stopping = true;
      if (_backgroundTask != null) {
        // TODO: cancellation
        await _backgroundTask;
      }
    }

    public void Dispose() {
      Logger.LogInformation("MyServiceB is disposing.");
    }
  }
  public static class HostBuilderExtensions {
    public static IHostBuilder CreateSpecificHostBuilder(string[] args, string initialEnvName, string loadedFromDirectory, string initialStartupDirectory, ResourceManager exceptionResourceManager, ResourceManager debugResourceManager) {
      IHostBuilder hb
        = new HostBuilder()
                //.UseServiceProviderFactory<MyContainer>(new MyContainerFactory())
                //.ConfigureContainer<MyContainer>((hostContext, container) => {
                //.ConfigureContainer((hostContext, container) => {
                // })
                .ConfigureLogging(logging => {
                  logging.AddConsole();
                })
                .ConfigureAppConfiguration((hostContext, config) => {
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
                ;

      return hb;
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

  internal class SimpleConsole : IHostedService {
    private ILogger<SimpleConsole> Logger { get; }
    private CancellationTokenSource CancellationTokenSource { get; } = new CancellationTokenSource();
    private TaskCompletionSource<bool> TaskCompletionSource { get; } = new TaskCompletionSource<bool>();
    public SimpleConsole(ILogger<SimpleConsole> logger) {
      Logger = logger;
    }
    public Task StartAsync(CancellationToken cancellationToken) {
      // Start our application code.
      Task.Run(() => DoWork(CancellationTokenSource.Token));
      return Task.CompletedTask;
    }
    public Task StopAsync(CancellationToken cancellationToken) {
      CancellationTokenSource.Cancel();
      // Defer completion promise, until our application has reported it is done.
      return TaskCompletionSource.Task;
    }
    public async Task DoWork(CancellationToken cancellationToken) {
      while (!cancellationToken.IsCancellationRequested) {
        Logger.LogInformation("Hello World");
        await Task.Delay(1000);
      }
      Logger.LogInformation("Stopping");
      TaskCompletionSource.SetResult(true);
    }
  }
}
