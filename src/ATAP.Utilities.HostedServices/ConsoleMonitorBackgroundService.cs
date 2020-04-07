using System;
using System.Collections.Generic;
using System.Text;
using ATAP.Utilities.ComputerInventory.Software;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using ATAP.Utilities.ETW;
using System.Threading.Tasks;
using Microsoft.Extensions.Localization;
using System.Diagnostics;
using ComputerInventoryHardwareStaticExtensions = ATAP.Utilities.ComputerInventory.Hardware.StaticExtensions;
using PersistenceStaticExtensions = ATAP.Utilities.Persistence.StaticExtensions;
using HostedServicesStringConstants = ATAP.Utilities.HostedServices.StringConstants;
using ConsoleMonitorStringConstants = ATAP.Utilities.HostedServices.ConsoleMonitor.StringConstants;
using ConsoleMonitorDefaultConfiguration = ATAP.Utilities.HostedServices.ConsoleMonitor.DefaultConfiguration;
using System.Threading;
using ATAP.Utilities.ComputerInventory.Hardware;
using ATAP.Utilities.Persistence;
using System.IO;
using System.Linq;
using System.Reactive.Linq;
using ATAP.Utilities.Reactive;

namespace ATAP.Utilities.HostedServices {
#if TRACE
  [ETWLogAttribute]
#endif
  // A Function to read stdin (Console) and act on the choices
  public class ConsoleMonitorBackgroundService : BackgroundService {
    #region Common Constructor-injected fields from the GenericHost
    private readonly ILogger<ConsoleMonitorBackgroundService> logger;
    private readonly IStringLocalizer<ConsoleMonitorBackgroundService> stringLocalizer;
    private readonly IHostEnvironment hostEnvironment;
    private readonly IConfiguration hostConfiguration;
    private readonly IHostLifetime hostLifetime;
    private readonly IHostApplicationLifetime hostApplicationLifetime;
    #endregion
    #region Internal and Linked CancellationTokenSource and Tokens
    private readonly CancellationTokenSource internalCancellationTokenSource = new CancellationTokenSource();
    private CancellationToken internalCancellationToken;
    private CancellationTokenSource linkedCancellationTokenSource;
    #endregion
    #region Constructor-injected fields unique to this service
    private readonly IConsoleSinkHostedService consoleSinkHostedService;
    private readonly IConsoleSourceHostedService consoleSourceHostedService;
    #endregion
    #region Data for this Service
    IConfigurationRoot configurationRoot;
    IEnumerable<string> choices;
    StringBuilder mesg = new StringBuilder();
    IDisposable DisposeThis { get; set; }
    IDisposable SubscriptionToConsoleReadLineAsyncAsObservableDisposeHandle { get; set; }
    Stopwatch stopWatch; // ToDo: utilize a much more powerfull and ubiquitious timing and profiling tool than a stopwatch

    #endregion
    //public ConsoleMonitorBackgroundService(IConsoleSinkHostedService hostedServiceConsoleSink, IConsoleSourceHostedService consoleSourceHostedService, ILoggerFactory loggerFactory, IStringLocalizerFactory stringLocalizerFactory, IHostEnvironment hostEnvironment, IConfiguration hostConfiguration, IHostLifetime hostLifetime, IHostApplicationLifetime hostApplicationLifetime) {
    //public ConsoleMonitorBackgroundService(IConsoleSinkHostedService hostedServiceConsoleSink, IConsoleSourceHostedService consoleSourceHostedService, ILoggerFactory loggerFactory, IStringLocalizer stringLocalizer, IHostEnvironment hostEnvironment, IConfiguration hostConfiguration, IHostLifetime hostLifetime, IHostApplicationLifetime hostApplicationLifetime) {
    /// <summary>
    /// Constructor that populates all the injected services provided by a GenericHost, along with teh injected services specific to this program that are needed by this HostedService (or derivitive like BackgroundService)
    /// </summary>
    /// <param name="consoleSinkHostedService"></param>
    /// <param name="consoleSourceHostedService"></param>
    /// <param name="loggerFactory"></param>
    /// <param name="hostEnvironment"></param>
    /// <param name="hostConfiguration"></param>
    /// <param name="hostLifetime"></param>
    /// <param name="hostApplicationLifetime"></param>
    public ConsoleMonitorBackgroundService(IConsoleSinkHostedService consoleSinkHostedService, IConsoleSourceHostedService consoleSourceHostedService, ILoggerFactory loggerFactory, IHostEnvironment hostEnvironment, IConfiguration hostConfiguration, IHostLifetime hostLifetime, IHostApplicationLifetime hostApplicationLifetime) {
      this.logger = loggerFactory.CreateLogger<ConsoleMonitorBackgroundService>();
      //this.stringLocalizer = stringLocalizer ?? throw new ArgumentNullException(nameof(stringLocalizer));;
      this.hostEnvironment = hostEnvironment ?? throw new ArgumentNullException(nameof(hostEnvironment));
      this.hostConfiguration = hostConfiguration ?? throw new ArgumentNullException(nameof(hostConfiguration));
      this.hostLifetime = hostLifetime ?? throw new ArgumentNullException(nameof(hostLifetime));
      this.hostApplicationLifetime = hostApplicationLifetime ?? throw new ArgumentNullException(nameof(hostApplicationLifetime));
      this.consoleSinkHostedService = consoleSinkHostedService ?? throw new ArgumentNullException(nameof(consoleSinkHostedService));
      this.consoleSourceHostedService = consoleSourceHostedService ?? throw new ArgumentNullException(nameof(consoleSourceHostedService));
    }

    #region static helper methods to reduce code clutter
    // Helper methods to reduce code clutter
    void CheckAndHandleCancellationToken(int checkpointNumber, CancellationToken cancellationToken) {
      // check CancellationToken to see if this task is cancelled
      if (cancellationToken.IsCancellationRequested) {
        // ToDo localize the Log message
        logger.LogDebug($"in ConvertFileSystemToGraphAsyncTask: Cancellation requested, checkpoint number {checkpointNumber}");
        cancellationToken.ThrowIfCancellationRequested();
      }
    }
    // Build a menu for the user to see and interact with
    void BuildMenu(StringBuilder mesg, IEnumerable<string> choices, CancellationToken cancellationToken) {
      // check CancellationToken to see if this task is cancelled
      CheckAndHandleCancellationToken(2, cancellationToken);
      mesg.Clear();

      foreach (var choice in choices) {
        mesg.Append(choice);
        mesg.Append(Environment.NewLine);
      }
      mesg.Append("Enter Selection>");
    }

    // Output a message, wrapped with exception handling
    async Task WriteMessageSafelyAsync(StringBuilder mesg, IConsoleSinkHostedService consoleSinkHostedService, CancellationToken cancellationToken) {
      // check CancellationToken to see if this task is cancelled
      CheckAndHandleCancellationToken(3, cancellationToken);
      try {
        await consoleSinkHostedService.WriteMessageAsync(mesg.ToString()).ConfigureAwait(false);
      }
      catch (Exception) {
        throw;
      }
      mesg.Clear();
    }

    // Format an instance of ConvertFileSystemToGraphResults for UI presentation
    void BuildConvertFileSystemToGraphResults(StringBuilder mesg, ConvertFileSystemToGraphResult convertFileSystemToGraphResult, Stopwatch? stopwatch) {
      mesg.Clear();
      if (stopwatch != null) {
        mesg.Append(string.Format("Running the function took {0} milliseconds", stopwatch.ElapsedMilliseconds));
        mesg.Append(Environment.NewLine);
      }
      mesg.Append(string.Format("DeepestDirectoryTree: {0}", convertFileSystemToGraphResult.DeepestDirectoryTree));
      mesg.Append(Environment.NewLine);
      mesg.Append(string.Format("LargestFile: {0}", convertFileSystemToGraphResult.LargestFile));
      mesg.Append(Environment.NewLine);
      mesg.Append(string.Format("EarliestDirectoryCreationTime: {0}", convertFileSystemToGraphResult.EarliestDirectoryCreationTime));
      mesg.Append(Environment.NewLine);
      mesg.Append(string.Format("LatestDirectoryCreationTime: {0}", convertFileSystemToGraphResult.LatestDirectoryCreationTime));
      mesg.Append(Environment.NewLine);
      mesg.Append(string.Format("EarliestFileCreationTime: {0}", convertFileSystemToGraphResult.EarliestFileCreationTime));
      mesg.Append(Environment.NewLine);
      mesg.Append(string.Format("LatestFileCreationTime: {0}", convertFileSystemToGraphResult.LatestFileCreationTime));
      mesg.Append(Environment.NewLine);
      mesg.Append(string.Format("EarliestFileModificationTime: {0}", convertFileSystemToGraphResult.EarliestFileModificationTime));
      mesg.Append(Environment.NewLine);
      mesg.Append(string.Format("LatestFileModificationTime: {0}", convertFileSystemToGraphResult.LatestFileModificationTime));
      mesg.Append(Environment.NewLine);
      mesg.Append(string.Format("Number of AcceptableExceptions: {0}", convertFileSystemToGraphResult.AcceptableExceptions.Count));
      mesg.Append(Environment.NewLine);
      //ToDo: break out AcceptableExceptions by type

    }
    #endregion

    #region ConfigurationBuilder
    IConfigurationBuilder ATAPConfigurationBuilder(string loadedFromDirectory, string initialStartupDirectory, IConfiguration hostConfiguration, IStringLocalizer stringLocalizer, Dictionary<string, string> defaultConfiguration, string settingsFileName, string settingsFileNameSuffix, string customEnvironmentVariablePrefix) {
      IConfigurationBuilder configurationBuilder = new ConfigurationBuilder()
      // Start with a "compiled-in defaults" for anything that is REQUIRED to be provided in configuration for Production
      .AddInMemoryCollection(defaultConfiguration)
      // SetBasePath creates a Physical File provider pointing to the directory where this assembly was loaded from
      .SetBasePath(Path.GetFullPath(loadedFromDirectory));
      // get any Production level Settings file present in the installation directory
      // ToDo: File names should be localized
      configurationBuilder.AddJsonFile(settingsFileName+"."+ settingsFileNameSuffix, optional: true);
      // Add environment-specific settings file
      if (!hostEnvironment.IsProduction()) {
        configurationBuilder.AddJsonFile(settingsFileName+"."+ hostEnvironment.EnvironmentName+"."+ settingsFileNameSuffix, optional: true);
      }
      // and again, SetBasePath creates a Physical File provider, this time pointing to the initial startup directory, which will be used by the following method
      configurationBuilder.SetBasePath(Path.GetFullPath(initialStartupDirectory));
      configurationBuilder.AddJsonFile(settingsFileName + "." + settingsFileNameSuffix, optional: true);
      if (!hostEnvironment.IsProduction()) {
        configurationBuilder.AddJsonFile(settingsFileName + "." + hostEnvironment.EnvironmentName + "." + settingsFileNameSuffix, optional: true);
      }
      // Add environment variables, only environment variables that start with the given prefix
      configurationBuilder.AddEnvironmentVariables(prefix: customEnvironmentVariablePrefix);
      // Note that command line arguments are available on hostConfig
      return configurationBuilder;
    }
    #endregion

    protected override async Task ExecuteAsync(CancellationToken externalCancellationToken) {

      #region CancellationToken creation and linking
      // Combine the cancellation tokens,so that either can stop this HostedService
      internalCancellationToken = internalCancellationTokenSource.Token;
      linkedCancellationTokenSource = CancellationTokenSource.CreateLinkedTokenSource(internalCancellationToken, externalCancellationToken);
      var linkedCancellationToken = linkedCancellationTokenSource.Token;
      #endregion
      #region Register actions with the CancellationToken (s)
      externalCancellationToken.Register(() => logger.LogInformation("ConsoleMonitorBackgroundService: externalCancellationToken has signalled stopping."));
      internalCancellationToken.Register(() => logger.LogInformation("ConsoleMonitorBackgroundService: internalCancellationToken has signalled stopping."));
      linkedCancellationToken.Register(() => logger.LogInformation("ConsoleMonitorBackgroundService: linkedCancellationToken has signalled stopping."));
      #endregion
      #region Instantiate this service's Data structure
      #region configurationRoot for this HostedService
      // Create the configurationBuilder for this HostedService. This creates an ordered chain of configuration providers. The first providers in the chain have the lowest priority, the last providers in the chain have a higher priority.
      // The Environment has been configured by the GenericHost before this point is reached
      // Both LoadedFromDirectory and InitialStartupDirectory have been configured by the GenericHost before this point is reached

      var loadedFromDirectory = hostConfiguration.GetValue<string>("SomeStringConstantConfigrootKey", "./"); //ToDo suport dynamic assembly loading form other Startup directories -  Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location);
      var initialStartupDirectory = hostConfiguration.GetValue<string>("SomeStringConstantConfigrootKey", "./");
      var configurationBuilder = ATAPConfigurationBuilder(loadedFromDirectory, initialStartupDirectory, hostConfiguration, stringLocalizer, ConsoleMonitorDefaultConfiguration.Production, ConsoleMonitorStringConstants.SettingsFileName, ConsoleMonitorStringConstants.SettingsFileNameSuffix, StringConstants.CustomEnvironmentVariablePrefix);
      configurationRoot = configurationBuilder.Build();
      #endregion
      // Create a list of choices
      choices = new List<string>() { "1. Run ConvertFileSystemToGraphAsyncTask", "2. Subscribe ConsoleOut to ConsoleIn", "2. Unsubscribe ConsoleOut from ConsoleIn" };
      #endregion
      #region Build and write menu
      BuildMenu(mesg, choices, linkedCancellationToken);
      await WriteMessageSafelyAsync(mesg, consoleSinkHostedService, linkedCancellationToken).ConfigureAwait(false); // ToDo: handle Task.Faulted when Console.Out has been closed
      #endregion
      #region define the ConsoleMonitorFunc<string,Task> that will be executed every time the consoleSourceHostedService.ConsoleReadLineAsyncAsObservable produces a sequence element
      // This Action closes over the current local variables' values
      Func<string, Task> ConsoleMonitorFunc = new Func<string, Task>(async (inputLineString) => {
        // check CancellationToken to see if this task is canceled
        CheckAndHandleCancellationToken(1, linkedCancellationToken);
        logger.LogDebug(string.Format("ConsoleMonitorFunc inputLineString = {0}", inputLineString));
        mesg.Append(string.Format("You selected: {0}", inputLineString));
        await WriteMessageSafelyAsync(mesg, consoleSinkHostedService, linkedCancellationToken).ConfigureAwait(false); // ToDo: handle Task.Faulted when Console.Out has been closed
        mesg.Clear();
        switch (inputLineString) {
          case "1":
            // ToDo: Get these from the configRoot in the Data instance in the ConsoleMonitor service
            var rootString = configurationRoot.GetValue<string>(ConsoleMonitorStringConstants.RootStringConfigRootKey, ConsoleMonitorStringConstants.RootStringDefault);
            var asyncFileReadBlockSize = hostConfiguration.GetValue<int>(ConsoleMonitorStringConstants.AsyncFileReadBlockSizeConfigRootKey, int.Parse(ConsoleMonitorStringConstants.AsyncFileReadBlockSizeDefault));  // ToDo: should validate in case the ConsoleMonitorStringConstants assembly is messed up?
            var enableHash = hostConfiguration.GetValue<bool>(ConsoleMonitorStringConstants.EnableHashBoolConfigRootKey, bool.Parse(ConsoleMonitorStringConstants.EnableHashBoolConfigRootKeyDefault));  // ToDo: should validate in case the ConsoleMonitorStringConstants assembly is messed up?
            var enableProgress = hostConfiguration.GetValue<bool>(ConsoleMonitorStringConstants.EnableProgressBoolConfigRootKey, bool.Parse(ConsoleMonitorStringConstants.EnableProgressBoolDefault));// ToDo: should validate in case the ConsoleMonitorStringConstants assembly is messed up?
            var enablePersistence = hostConfiguration.GetValue<bool>(ConsoleMonitorStringConstants.EnablePersistenceBoolConfigRootKey, bool.Parse(ConsoleMonitorStringConstants.EnablePersistenceBoolDefault));// ToDo: should validate in case the ConsoleMonitorStringConstants assembly is messed up?
            var enablePickAndSave = hostConfiguration.GetValue<bool>(ConsoleMonitorStringConstants.EnablePickAndSaveBoolConfigRootKey, bool.Parse(ConsoleMonitorStringConstants.EnablePickAndSaveBoolDefault));// ToDo: should validate in case the ConsoleMonitorStringConstants assembly is messed up?
            var temporaryDirectoryBase = hostConfiguration.GetValue<string>(ConsoleMonitorStringConstants.TemporaryDirectoryBaseConfigRootKey, ConsoleMonitorStringConstants.TemporaryDirectoryBaseDefault);
            var WithPersistenceNodeFileRelativePath = hostConfiguration.GetValue<string>(ConsoleMonitorStringConstants.WithPersistenceNodeFileRelativePathConfigRootKey, ConsoleMonitorStringConstants.WithPersistenceNodeFileRelativePathDefault);
            var WithPersistenceEdgeFileRelativePath = hostConfiguration.GetValue<string>(ConsoleMonitorStringConstants.WithPersistenceEdgeFileRelativePathConfigRootKey, ConsoleMonitorStringConstants.WithPersistenceEdgeFileRelativePathDefault);
            var filePathsPersistence = new string[2] { temporaryDirectoryBase + WithPersistenceNodeFileRelativePath, temporaryDirectoryBase + WithPersistenceEdgeFileRelativePath };
            var WithPickAndSaveNodeFileRelativePath = hostConfiguration.GetValue<string>(ConsoleMonitorStringConstants.WithPickAndSaveNodeFileRelativePathConfigRootKey, ConsoleMonitorStringConstants.WithPickAndSaveNodeFileRelativePathDefault);
            var filePathsPickAndSave = new string[1] { temporaryDirectoryBase + WithPickAndSaveNodeFileRelativePath };
            mesg.Append(string.Format("Running PartitionInfoEx Extension Function ConvertFileSystemToObjectGraph, on rootString {0} with an asyncFileReadBlockSize of {1} with hashihg enabled: {2} ; progress enabled: {3} ; persistence enabled: {5} ; pickAndSave enabled: {4}", rootString, asyncFileReadBlockSize, enableHash, enableProgress, enablePersistence, enablePickAndSave));
            if (enablePersistence) {
              mesg.Append(Environment.NewLine);
              mesg.Append(string.Format("  persistence filePaths: {0}", string.Join(",", filePathsPersistence)));
            }
            if (enablePickAndSave) {
              mesg.Append(Environment.NewLine);
              mesg.Append(string.Format("  pickAndSave filePaths {0}", string.Join(",", filePathsPickAndSave)));
            }
            if (enableProgress) {
              mesg.Append(Environment.NewLine);
              mesg.Append(string.Format("  progressReporting TBD{0}", "ProgressReportingDataStructureDetails"));
            }

            await WriteMessageSafelyAsync(mesg, consoleSinkHostedService, linkedCancellationToken).ConfigureAwait(false); // ToDo: handle Task.Faulted when Console.Out has been closed

            #region ProgressReporting setup
            ConvertFileSystemToGraphProgress? convertFileSystemToGraphProgress; ;
            if (enableProgress) {
              convertFileSystemToGraphProgress = new ConvertFileSystemToGraphProgress();
            }
            else {
              convertFileSystemToGraphProgress = null;
            }
            #endregion
            #region PersistenceViaFiles setup
            // Ensure the Node and Edge files are empty and can be written to

            // Call the SetupViaFileFuncBuilder here, execute the Func that comes back, with filePaths as the argument
            // ToDo: create a function that will create subdirectories if needed to fulfill path, and use that function when creating the temp fiiles
            var setupResultsPersistence = PersistenceStaticExtensions.SetupViaFileFuncBuilder()(new SetupViaFileData(filePathsPersistence));

            // Create an insertFunc that references the local variable setupResults, closing over it
            var insertFunc = new Func<IEnumerable<IEnumerable<object>>, IInsertViaFileResults>((insertData) => {
              int numberOfDatas = insertData.ToArray().Length;
              int numberOfStreamWriters = setupResultsPersistence.StreamWriters.Length;
              for (var i = 0; i < numberOfDatas; i++) {
                foreach (string str in insertData.ToArray()[i]) {
                  //ToDo: add async versions await setupResults.StreamWriters[i].WriteLineAsync(str);
                  //ToDo: exception handling
                  setupResultsPersistence.StreamWriters[i].WriteLine(str);
                }
              }
              return new InsertViaFileResults(true);
            });
            Persistence<IInsertResultsAbstract> persistence = new Persistence<IInsertResultsAbstract>(insertFunc);
            #endregion
            #region PickAndSaveViaFiles setup
            // Ensure the Node and Edge files are empty and can be written to

            // Call the SetupViaFileFuncBuilder here, execute the Func that comes back, with filePaths as the argument
            // ToDo: create a function that will create subdirectories if needed to fulfill path, and use that function when creating the temp fiiles
            var setupResultsPickAndSave = PersistenceStaticExtensions.SetupViaFileFuncBuilder()(new SetupViaFileData(filePathsPickAndSave));
            // Create a pickFunc
            var pickFuncPickAndSave = new Func<object, bool>((objToTest) => {
              return FileIOExtensions.IsArchiveFile(objToTest.ToString()) || FileIOExtensions.IsMailFile(objToTest.ToString());
            });
            // Create an insert Func
            var insertFuncPickAndSave = new Func<IEnumerable<IEnumerable<object>>, IInsertViaFileResults>((insertData) => {
              int numberOfStreamWriters = setupResultsPickAndSave.StreamWriters.Length;
              for (var i = 0; i < numberOfStreamWriters; i++) {
                foreach (string str in insertData.ToArray()[i]) {
                  //ToDo: add async versions await setupResults.StreamWriters[i].WriteLineAsync(str);
                  //ToDo: exception handling
                  // ToDo: Make formatting a parameter
                  setupResultsPickAndSave.StreamWriters[i].WriteLine(str);
                }
              }
              return new InsertViaFileResults(true);
            });
            PickAndSave<IInsertResultsAbstract> pickAndSave = new PickAndSave<IInsertResultsAbstract>(pickFuncPickAndSave, insertFuncPickAndSave);
            #endregion

            ConvertFileSystemToGraphResult convertFileSystemToGraphResult;
            #region Method timing setup
            Stopwatch stopWatch = new Stopwatch(); // ToDo: utilize a much more powerfull and ubiquitious timing and profiling tool than a stopwatch
            stopWatch.Start();
            #endregion
            try {
              Func<Task<ConvertFileSystemToGraphResult>> run = () => ComputerInventoryHardwareStaticExtensions.ConvertFileSystemToGraphAsyncTask(rootString, asyncFileReadBlockSize, enableHash, convertFileSystemToGraphProgress, persistence, pickAndSave, linkedCancellationToken);
              convertFileSystemToGraphResult = await run.Invoke().ConfigureAwait(false);
              stopWatch.Stop(); // ToDo: utilize a much more powerfull and ubiquitious timing and profiling tool than a stopwatch
              // ToDo: put the results someplace
            }
            catch (Exception) { // ToDo: define explicit exceptions to catch and report upon
              throw;
            }
            finally {
              // Dispose of the objects that need disposing
              setupResultsPickAndSave.Dispose();
              setupResultsPersistence.Dispose();
            }
            #region Build the results
            BuildConvertFileSystemToGraphResults(mesg, convertFileSystemToGraphResult, stopWatch);
            #endregion
            break;
          case "2":
            #region define the Func<string,Task> to be executed when the ConsoleSourceHostedService.ConsoleReadLineAsyncAsObservable produces a sequence element
            // This Action closes over the current local variables' values
            Func<string, Task> SimpleEchoToConsoleOutFunc = new Func<string, Task>(async (inputLineString) => {
              await consoleSinkHostedService.WriteMessage(inputLineString).ConfigureAwait(false); // ToDo: catch exceptions, return a task in a faulted state
            });
            #endregion
            // create subscription between the ConsoleInAsObservable source and the ConsoleOutHostedService.WriteMessage sink
            // ToDo: add OnError and OnCompleted handelers
            DisposeThis = ConsoleSourceHostedService.ConsoleReadLineAsyncAsObservable().SubscribeAsync<string>(SimpleEchoToConsoleOutFunc); // ToDo: add OnError and OnCompleted handleers
            mesg.Clear();
            mesg.Append(string.Format("subscription between the ConsoleInAsObservable source and the ConsoleOutHostedService.WriteMessage sink has been created"));
            break;
          case "3":
            // remove subscription between the ConsoleInAsObservable and the ConsoleOutHostedService.WriteMessage tasks
            DisposeThis.Dispose();
            mesg.Clear();
            mesg.Append(string.Format("subscription between the ConsoleInAsObservable source and the ConsoleOutHostedService.WriteMessage sink has been Disposed"));
            break;
          default:
            mesg.Clear();
            mesg.Append(string.Format("InvalidInputDoesNotMatchAvailableChoices {0}", inputLineString));
            break;
        }

        await WriteMessageSafelyAsync(mesg, consoleSinkHostedService, linkedCancellationToken).ConfigureAwait(false); // ToDo: handle Task.Faulted when Console.Out has been closed

        BuildMenu(mesg, choices, linkedCancellationToken);
        await WriteMessageSafelyAsync(mesg, consoleSinkHostedService, linkedCancellationToken).ConfigureAwait(false); // ToDo: handle Task.Faulted when Console.Out has been closed
      }
        );
      #endregion

      // Subscribe to consoleSourceHostedService. Run the Func<string,Task> every time ConsoleReadLineAsyncAsObservable() produces aa sequence element
      // ToDo:  Add OnError and OnCompleted handlers
      SubscriptionToConsoleReadLineAsyncAsObservableDisposeHandle = ConsoleSourceHostedService.ConsoleReadLineAsyncAsObservable().SubscribeAsync<string>(ConsoleMonitorFunc);

      // Wait for the conjoined cancellation token (or individually if the hosted service does not define its own internal cts)
      WaitHandle.WaitAny(new[] { linkedCancellationToken.WaitHandle });
      logger.LogInformation("{ExecuteAsync} ConsoleMonitorBackgroundService is stopping.");
      SubscriptionToConsoleReadLineAsyncAsObservableDisposeHandle.Dispose();
    }

  }


}
