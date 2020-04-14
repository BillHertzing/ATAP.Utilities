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
using ConfigurationExtensions = ATAP.Utilities.Extensions.Configuration.Extensions;

using System.Threading;
using ATAP.Utilities.ComputerInventory.Hardware;
using ATAP.Utilities.Persistence;
using System.IO;
using System.Linq;
using System.Reactive.Linq;
using ATAP.Utilities.Reactive;
using System.Globalization;

namespace ATAP.Utilities.HostedServices {
#if TRACE
  [ETWLogAttribute]
#endif
  // A Function to read stdin (Console) and act on the choices
  public class ConsoleMonitorBackgroundService : BackgroundService {
    #region Common Constructor-injected fields from the GenericHost
    private readonly ILoggerFactory loggerFactory;
    private readonly ILogger<ConsoleMonitorBackgroundService> logger;
    private readonly IStringLocalizerFactory stringLocalizerFactory;
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
    #region Constructor-injected fields unique to this service. These repersent other services expected to bepresent in the app's DI container
    private readonly IConsoleSinkHostedService consoleSinkHostedService;
    private readonly IConsoleSourceHostedService consoleSourceHostedService;
    #endregion
    #region Data for this Service
    IConfigurationRoot configurationRoot;
    private readonly IStringLocalizer debugLocalizer;
    private readonly IStringLocalizer exceptionLocalizer;
    private readonly IStringLocalizer uILocalizer;
    IEnumerable<string> choices;
    StringBuilder mesg = new StringBuilder();
    IDisposable DisposeThis { get; set; }
    IDisposable SubscriptionToConsoleReadLineAsyncAsObservableDisposeHandle { get; set; }
    Stopwatch stopWatch; // ToDo: utilize a much more powerfull and ubiquitious timing and profiling tool than a stopwatch

    #endregion
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
    //public ConsoleMonitorBackgroundService(IConsoleSinkHostedService hostedServiceConsoleSink, IConsoleSourceHostedService consoleSourceHostedService, ILoggerFactory loggerFactory, IStringLocalizerFactory stringLocalizerFactory, IHostEnvironment hostEnvironment, IConfiguration hostConfiguration, IHostLifetime hostLifetime, IHostApplicationLifetime hostApplicationLifetime) {
    public ConsoleMonitorBackgroundService(IConsoleSinkHostedService consoleSinkHostedService, IConsoleSourceHostedService consoleSourceHostedService, ILoggerFactory loggerFactory, IStringLocalizerFactory stringLocalizerFactory, IHostEnvironment hostEnvironment, IConfiguration hostConfiguration, IHostLifetime hostLifetime, IHostApplicationLifetime hostApplicationLifetime) {
      this.stringLocalizerFactory = stringLocalizerFactory ?? throw new ArgumentNullException(nameof(stringLocalizerFactory));
      exceptionLocalizer = stringLocalizerFactory.Create(nameof(Resources.ExceptionResources), "ATAP.Utilities.HostedServices");
      debugLocalizer = stringLocalizerFactory.Create(nameof(Resources.DebugResources), "ATAP.Utilities.HostedServices");
      uILocalizer = stringLocalizerFactory.Create(nameof(Resources.UIResources), "ATAP.Utilities.HostedServices");
      this.loggerFactory = loggerFactory ?? throw new ArgumentNullException(nameof(loggerFactory));
      this.logger = loggerFactory.CreateLogger<ConsoleMonitorBackgroundService>();
      this.stringLocalizerFactory = stringLocalizerFactory ?? throw new ArgumentNullException(nameof(stringLocalizerFactory));
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
        logger.LogDebug(debugLocalizer["{0}: Cancellation requested, checkpoint number {1}", "ConsoleMonitorBackgroundService", checkpointNumber.ToString(CultureInfo.CurrentCulture)]);
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
      //ToDo: use String.Format and CurrentCulture
      mesg.Append(uILocalizer["Enter a number for a choice, Ctrl-C to Exit"]);
    }

    // Output a message, wrapped with exception handling
    async Task WriteMessageSafelyAsync(StringBuilder mesg, IConsoleSinkHostedService consoleSinkHostedService, CancellationToken cancellationToken) {
      // check CancellationToken to see if this task is cancelled
      CheckAndHandleCancellationToken(3, cancellationToken);
      try {
        await consoleSinkHostedService.WriteMessageAsync(mesg).ConfigureAwait(false);
        // ToDo: Handle Task Faulted
      }
      catch (Exception) {// ToDo: Better excpetion handling
        throw;
      }
      mesg.Clear();
    }

    // Format an instance of ConvertFileSystemToGraphResults for UI presentation
    // // Uses the CurrentCulture, converts File Sizes to UnitsNet.Information types, and DateTimes to ITenso Times
    void BuildConvertFileSystemToGraphResults(StringBuilder mesg, ConvertFileSystemToGraphResult convertFileSystemToGraphResult, Stopwatch? stopwatch) {
      mesg.Clear();
      if (stopwatch != null) {
        mesg.Append(uILocalizer["Running the function took {0} milliseconds", string.Format(CultureInfo.CurrentCulture,stopwatch.ElapsedMilliseconds.ToString())]);
        mesg.Append(Environment.NewLine);
      }
      mesg.Append(string.Format("DeepestDirectoryTree: {0}", convertFileSystemToGraphResult.DeepestDirectoryTree));
      mesg.Append(Environment.NewLine);
      mesg.Append(uILocalizer["LargestFile: {0}", new UnitsNet.Information(convertFileSystemToGraphResult.LargestFile, UnitsNet.Units.InformationUnit.Byte).ToString(CultureInfo.CurrentCulture)]);
      mesg.Append(Environment.NewLine);
      mesg.Append(uILocalizer["EarliestDirectoryCreationTime: {0}", convertFileSystemToGraphResult.EarliestDirectoryCreationTime.ToString(CultureInfo.CurrentCulture)]);
      mesg.Append(Environment.NewLine);
      mesg.Append(uILocalizer["LatestDirectoryCreationTime: {0}", convertFileSystemToGraphResult.LatestDirectoryCreationTime.ToString(CultureInfo.CurrentCulture)]);
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
      // List the acceptable Exceptions that occurred
      //ToDo: break out AcceptableExceptions by type

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
      // InitialStartupDirectory has been set by the GenericHost before this point is reached, and is where the GenericHost program or service was started
      // LoadedFromDirectory has been configured by the GenericHost before this point is reached. It is the location where this assembly resides
      // ToDo: Implement these two values into the GenericHost configurationRoot somehow, then remove from the constructor signature
      var loadedFromDirectory = hostConfiguration.GetValue<string>("SomeStringConstantConfigrootKey", "./"); //ToDo suport dynamic assembly loading form other Startup directories -  Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location);
      var initialStartupDirectory = hostConfiguration.GetValue<string>("SomeStringConstantConfigrootKey", "./");
      // Build the configurationRoot for this service
      var configurationBuilder = ConfigurationExtensions.StandardConfigurationBuilder(loadedFromDirectory, initialStartupDirectory, ConsoleMonitorDefaultConfiguration.Production, ConsoleMonitorStringConstants.SettingsFileName, ConsoleMonitorStringConstants.SettingsFileNameSuffix, StringConstants.CustomEnvironmentVariablePrefix, loggerFactory,  stringLocalizerFactory, hostEnvironment, hostConfiguration, linkedCancellationToken);
      configurationRoot = configurationBuilder.Build();
      #endregion
      // Create a list of choices
      // ToDo: Get the list from the configurationRoot, with secure vetting
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
            var asyncFileReadBlockSize = configurationRoot.GetValue<int>(ConsoleMonitorStringConstants.AsyncFileReadBlockSizeConfigRootKey, int.Parse(ConsoleMonitorStringConstants.AsyncFileReadBlockSizeDefault));  // ToDo: should validate in case the ConsoleMonitorStringConstants assembly is messed up?
            var enableHash = configurationRoot.GetValue<bool>(ConsoleMonitorStringConstants.EnableHashBoolConfigRootKey, bool.Parse(ConsoleMonitorStringConstants.EnableHashBoolConfigRootKeyDefault));  // ToDo: should validate in case the ConsoleMonitorStringConstants assembly is messed up?
            var enableProgress = configurationRoot.GetValue<bool>(ConsoleMonitorStringConstants.EnableProgressBoolConfigRootKey, bool.Parse(ConsoleMonitorStringConstants.EnableProgressBoolDefault));// ToDo: should validate in case the ConsoleMonitorStringConstants assembly is messed up?
            var enablePersistence = configurationRoot.GetValue<bool>(ConsoleMonitorStringConstants.EnablePersistenceBoolConfigRootKey, bool.Parse(ConsoleMonitorStringConstants.EnablePersistenceBoolDefault));// ToDo: should validate in case the ConsoleMonitorStringConstants assembly is messed up?
            var enablePickAndSave = configurationRoot.GetValue<bool>(ConsoleMonitorStringConstants.EnablePickAndSaveBoolConfigRootKey, bool.Parse(ConsoleMonitorStringConstants.EnablePickAndSaveBoolDefault));// ToDo: should validate in case the ConsoleMonitorStringConstants assembly is messed up?
            var temporaryDirectoryBase = configurationRoot.GetValue<string>(ConsoleMonitorStringConstants.TemporaryDirectoryBaseConfigRootKey, ConsoleMonitorStringConstants.TemporaryDirectoryBaseDefault);
            var WithPersistenceNodeFileRelativePath = configurationRoot.GetValue<string>(ConsoleMonitorStringConstants.WithPersistenceNodeFileRelativePathConfigRootKey, ConsoleMonitorStringConstants.WithPersistenceNodeFileRelativePathDefault);
            var WithPersistenceEdgeFileRelativePath = configurationRoot.GetValue<string>(ConsoleMonitorStringConstants.WithPersistenceEdgeFileRelativePathConfigRootKey, ConsoleMonitorStringConstants.WithPersistenceEdgeFileRelativePathDefault);
            var filePathsPersistence = new string[2] { temporaryDirectoryBase + WithPersistenceNodeFileRelativePath, temporaryDirectoryBase + WithPersistenceEdgeFileRelativePath };
            var WithPickAndSaveNodeFileRelativePath = configurationRoot.GetValue<string>(ConsoleMonitorStringConstants.WithPickAndSaveNodeFileRelativePathConfigRootKey, ConsoleMonitorStringConstants.WithPickAndSaveNodeFileRelativePathDefault);
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
            //ToDo: add exception handling if the setup function fails
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
              // ToDo: catch FileIO.FileNotFound, sometimes the file disappears 
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
