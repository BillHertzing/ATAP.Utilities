using ATAP.Utilities.ETW;
using ATAP.Utilities.HostedServices;
using ATAP.Utilities.HostedServices.ConsoleSinkHostedService;
using ATAP.Utilities.HostedServices.ConsoleSourceHostedService;
using ATAP.Utilities.ComputerInventory.Hardware;
using ATAP.Utilities.Logging;
using ATAP.Utilities.Persistence;
using ATAP.Utilities.Reactive;

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
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Diagnostics;
using System.Globalization;
using System.Linq;
using System.Reactive;
using System.Reactive.Linq;

using ComputerInventoryHardwareStaticExtensions = ATAP.Utilities.ComputerInventory.Hardware.StaticExtensions;
using PersistenceStaticExtensions = ATAP.Utilities.Persistence.Extensions;
using GenericHostExtensions = ATAP.Utilities.GenericHost.Extensions;
using ConfigurationExtensions = ATAP.Utilities.Configuration.Extensions;
using appStringConstants = ATAP.Console.Console01.Console01StringConstants;

namespace ATAP.Console.Console01 {
  // This file contains the "boilerplate" code that creates the Background Service
#if TRACE
  [ETWLogAttribute]
#endif
  public partial class Console01BackgroundService : BackgroundService {
    #region Common Constructor-injected Auto-Implemented Properties
    // These properties can only be set in the class constructor.
    // Class constructor for a BackgroundService is called from the GenericHost and the DI-injected services are referenced
    ILoggerFactory loggerFactory { get; }
    ILogger<Console01BackgroundService> logger { get; }
    IStringLocalizerFactory stringLocalizerFactory { get; }
    IHostEnvironment hostEnvironment { get; }
    IConfiguration hostConfiguration { get; }
    IHostLifetime hostLifetime { get; }
    IConfiguration appConfiguration { get; }
    IHostApplicationLifetime hostApplicationLifetime { get; }
    #endregion
    #region Internal and Linked CancellationTokenSource and Tokens
    CancellationTokenSource internalCancellationTokenSource { get; } = new CancellationTokenSource();
    CancellationToken internalCancellationToken { get; }
    // Set in the ExecuteAsync method
    CancellationTokenSource linkedCancellationTokenSource { get; set; }
    // Set in the ExecuteAsync method
    CancellationToken linkedCancellationToken { get; set; }
    #endregion
    #region Constructor-injected fields unique to this service. These represent other services used by this service that are expected to be present in the app's DI container, and constructor-injected
    IConsoleSinkHostedService consoleSinkHostedService { get; }
    IConsoleSourceHostedService consoleSourceHostedService { get; }
    #endregion
    #region Data for Console01
    IStringLocalizer debugLocalizer { get; }
    IStringLocalizer exceptionLocalizer { get; }
    IStringLocalizer uiLocalizer { get; }

    IEnumerable<string> choices;
    StringBuilder mesg = new StringBuilder();
    IDisposable SubscriptionToConsoleReadLineAsyncAsObservableDisposeHandle { get; set; }
    Stopwatch stopWatch; // ToDo: utilize a much more powerfull and ubiquitous timing and profiling tool than a stopwatch
    #endregion
    #region Constructor
    /// <summary>
    /// Constructor that populates all the injected services provided by a GenericHost, along with the injected services specific to this program that are needed by this HostedService (or derivitive like BackgroundService)
    /// </summary>
    /// <param name="consoleSinkHostedService"></param>
    /// <param name="consoleSourceHostedService"></param>
    /// <param name="loggerFactory"></param>
    /// <param name="hostEnvironment"></param>
    /// <param name="hostConfiguration"></param>
    /// <param name="hostLifetime"></param>
    /// <param name="hostApplicationLifetime"></param>
    public Console01BackgroundService(IConsoleSinkHostedService consoleSinkHostedService, IConsoleSourceHostedService consoleSourceHostedService, ILoggerFactory loggerFactory, IStringLocalizerFactory stringLocalizerFactory, IHostEnvironment hostEnvironment, IConfiguration hostConfiguration, IHostLifetime hostLifetime, IConfiguration appConfiguration, IHostApplicationLifetime hostApplicationLifetime) {
      this.stringLocalizerFactory = stringLocalizerFactory ?? throw new ArgumentNullException(nameof(stringLocalizerFactory));
      exceptionLocalizer = stringLocalizerFactory.Create(nameof(Resources), "ATAP.Console.Console01");
      debugLocalizer = stringLocalizerFactory.Create(nameof(Resources), "ATAP.Console.Console01");
      uiLocalizer = stringLocalizerFactory.Create(nameof(Resources), "ATAP.Console.Console01");
      this.loggerFactory = loggerFactory ?? throw new ArgumentNullException(nameof(loggerFactory));
      this.logger = loggerFactory.CreateLogger<Console01BackgroundService>();
      // this.logger = (Logger<Console01BackgroundService>) ATAP.Utilities.Logging.LogProvider.GetLogger("Console01BackgroundService");
      logger.LogDebug("Console01BackgroundService", ".ctor");
      this.hostEnvironment = hostEnvironment ?? throw new ArgumentNullException(nameof(hostEnvironment));
      this.hostConfiguration = hostConfiguration ?? throw new ArgumentNullException(nameof(hostConfiguration));
      this.hostLifetime = hostLifetime ?? throw new ArgumentNullException(nameof(hostLifetime));
      this.appConfiguration = appConfiguration ?? throw new ArgumentNullException(nameof(appConfiguration));
      this.hostApplicationLifetime = hostApplicationLifetime ?? throw new ArgumentNullException(nameof(hostApplicationLifetime));
      this.consoleSinkHostedService = consoleSinkHostedService ?? throw new ArgumentNullException(nameof(consoleSinkHostedService));
      this.consoleSourceHostedService = consoleSourceHostedService ?? throw new ArgumentNullException(nameof(consoleSourceHostedService));
      internalCancellationToken = internalCancellationTokenSource.Token;
    }
    #endregion

    #region Helper methods to reduce code clutter
    #region CheckAndHandleCancellationToken
    void CheckAndHandleCancellationToken(int checkpointNumber) {
      // check CancellationToken to see if this task is cancelled
      if (linkedCancellationTokenSource.IsCancellationRequested) {
        logger.LogDebug(debugLocalizer["{0}: Cancellation requested, checkpoint number {1}", "ConsoleMonitorBackgroundService", checkpointNumber.ToString(CultureInfo.CurrentCulture)]);
        linkedCancellationToken.ThrowIfCancellationRequested();
      }
    }
    void CheckAndHandleCancellationToken(string locationMessage) {
      // check CancellationToken to see if this task is cancelled
      if (linkedCancellationTokenSource.IsCancellationRequested) {
        logger.LogDebug(debugLocalizer["{0}: Cancellation requested, checkpoint number {1}", "ConsoleMonitorBackgroundService", locationMessage]);
        linkedCancellationToken.ThrowIfCancellationRequested();
      }
    }
    #endregion
    #region WriteMessageSafelyAsync
    // Output a message, wrapped with exception handling
    async Task<Task> WriteMessageSafelyAsync() {
      // check CancellationToken to see if this task is cancelled
      CheckAndHandleCancellationToken("WriteMessageSafelyAsync");
      var task = await consoleSinkHostedService.WriteMessageAsync(mesg).ConfigureAwait(false);
      if (!task.IsCompletedSuccessfully) {
        if (task.IsCanceled) {
          // Ignore if user cancelled the operation during a large file output (internal cancellation)
          // re-throw if the cancellation request came from outside the ConsoleMonitor
          /// ToDo: evaluate the linked, inner, and external tokens
          throw new OperationCanceledException();
        }
        else if (task.IsFaulted) {
          //ToDo: Go through the innere exception
          //foreach (var e in t.Exception) {
          //  https://docs.microsoft.com/en-us/dotnet/standard/io/handling-io-errors
          // ToDo figure out what to do if the output stream is closed
          throw new Exception("ToDo: in WriteMessageSafelyAsync");
          //}
        }
      }
      return Task.CompletedTask;
    }
    #endregion
    #region Build and write menu
    /// <summary>
    /// Build a multiline menu from the choices, and send to stdout
    /// </summary>
    /// <param name="mesg"></param>
    /// <param name="choices"></param>
    /// <param name="consoleSinkHostedService"></param>
    /// <param name="uILocalizer"></param>
    /// <param name="exceptionLocalizer"></param>
    /// <param name="cancellationToken"></param>
    /// <returns></returns>
    async Task BuildMenu() {
      // check CancellationToken to see if this task is cancelled
      CheckAndHandleCancellationToken("BuildAndWriteMenu");
      mesg.Clear();

      foreach (var choice in choices) {
        mesg.Append(choice);
        mesg.Append(Environment.NewLine);
      }
      mesg.Append(uiLocalizer["Enter a number for a choice, Ctrl-C to Exit"]);

    }
    #endregion
    #region PrettyPrintConvertFileSystemToGraphResults
    // Format an instance of ConvertFileSystemToGraphResults for UI presentation
    // // Uses the CurrentCulture, converts File Sizes to UnitsNet.Information types, and DateTimes to ITenso Times
    void BuildConvertFileSystemToGraphResults(StringBuilder mesg, ConvertFileSystemToGraphResult convertFileSystemToGraphResult, Stopwatch? stopwatch) {
      mesg.Clear();
      if (stopwatch != null) {
        mesg.Append(uiLocalizer["Running the function took {0} milliseconds", stopwatch.ElapsedMilliseconds.ToString(CultureInfo.CurrentCulture)]);
        mesg.Append(Environment.NewLine);
      }
      mesg.Append(uiLocalizer["DeepestDirectoryTree: {0}", convertFileSystemToGraphResult.DeepestDirectoryTree]);
      mesg.Append(Environment.NewLine);
      mesg.Append(uiLocalizer["LargestFile: {0}", new UnitsNet.Information(convertFileSystemToGraphResult.LargestFile, UnitsNet.Units.InformationUnit.Byte).ToString(CultureInfo.CurrentCulture)]);
      mesg.Append(Environment.NewLine);
      mesg.Append(uiLocalizer["EarliestDirectoryCreationTime: {0}", convertFileSystemToGraphResult.EarliestDirectoryCreationTime.ToString(CultureInfo.CurrentCulture)]);
      mesg.Append(Environment.NewLine);
      mesg.Append(uiLocalizer["LatestDirectoryCreationTime: {0}", convertFileSystemToGraphResult.LatestDirectoryCreationTime.ToString(CultureInfo.CurrentCulture)]);
      mesg.Append(Environment.NewLine);
      mesg.Append(uiLocalizer["EarliestFileCreationTime: {0}", convertFileSystemToGraphResult.EarliestFileCreationTime]);
      mesg.Append(Environment.NewLine);
      mesg.Append(uiLocalizer["LatestFileCreationTime: {0}", convertFileSystemToGraphResult.LatestFileCreationTime]);
      mesg.Append(Environment.NewLine);
      mesg.Append(uiLocalizer["EarliestFileModificationTime: {0}", convertFileSystemToGraphResult.EarliestFileModificationTime]);
      mesg.Append(Environment.NewLine);
      mesg.Append(uiLocalizer["LatestFileModificationTime: {0}", convertFileSystemToGraphResult.LatestFileModificationTime]);
      mesg.Append(Environment.NewLine);
      mesg.Append(uiLocalizer["Number of AcceptableExceptions: {0}", convertFileSystemToGraphResult.AcceptableExceptions.Count]);
      mesg.Append(Environment.NewLine);
      // List the acceptable Exceptions that occurred
      //ToDo: break out AcceptableExceptions by type
    }
    #endregion
    #endregion

    async Task DoLoopAsync(string inputLine) {

      // check CancellationToken to see if this task is canceled
      CheckAndHandleCancellationToken(1);

      logger.LogDebug(uiLocalizer["{0} {1} inputLineString = {2}", "Console01BackgroundService", "DoLoopAsync", inputLine]);

      // Echo to stdOut the line that came in on stdIn
      mesg.Append(uiLocalizer["You selected: {0}", inputLine]);
      #region Write the mesg to stdout
      using (Task task = await WriteMessageSafelyAsync().ConfigureAwait(false)) {
        if (!task.IsCompletedSuccessfully) {
          if (task.IsCanceled) {
            // Ignore if user cancelled the operation during output to stdout (internal cancellation)
            // re-throw if the cancellation request came from outside the stdInLineMonitorAction
            /// ToDo: evaluate the linked, inner, and external tokens
            throw new OperationCanceledException();
          }
          else if (task.IsFaulted) {
            //ToDo: Go through the inner exception
            //foreach (var e in t.Exception) {
            //  https://docs.microsoft.com/en-us/dotnet/standard/io/handling-io-errors
            // ToDo figure out what to do if the output stream is closed
            throw new Exception("ToDo: WriteMessageSafelyAsync returned an AggregateException");
            //}
          }
        }
        mesg.Clear();
      }
      #endregion
      #region tempout
      switch (inputLine) {
        case "1":
          // ToDo: Get these from the appConfiguration
          var rootString = appConfiguration.GetValue<string>(appStringConstants.RootStringConfigRootKey, appStringConstants.RootStringDefault);
          var asyncFileReadBlockSize = appConfiguration.GetValue<int>(appStringConstants.AsyncFileReadBlockSizeConfigRootKey, int.Parse(appStringConstants.AsyncFileReadBlockSizeDefault));  // ToDo: should validate in case the appStringConstants assembly is messed up?
          var enableHash = appConfiguration.GetValue<bool>(appStringConstants.EnableHashBoolConfigRootKey, bool.Parse(appStringConstants.EnableHashBoolConfigRootKeyDefault));  // ToDo: should validate in case the appStringConstants assembly is messed up?
          var enableProgress = appConfiguration.GetValue<bool>(appStringConstants.EnableProgressBoolConfigRootKey, bool.Parse(appStringConstants.EnableProgressBoolDefault));// ToDo: should validate in case the appStringConstants assembly is messed up?
          var enablePersistence = appConfiguration.GetValue<bool>(appStringConstants.EnablePersistenceBoolConfigRootKey, bool.Parse(appStringConstants.EnablePersistenceBoolDefault));// ToDo: should validate in case the appStringConstants assembly is messed up?
          var enablePickAndSave = appConfiguration.GetValue<bool>(appStringConstants.EnablePickAndSaveBoolConfigRootKey, bool.Parse(appStringConstants.EnablePickAndSaveBoolDefault));// ToDo: should validate in case the appStringConstants assembly is messed up?
          var temporaryDirectoryBase = appConfiguration.GetValue<string>(appStringConstants.TemporaryDirectoryBaseConfigRootKey, appStringConstants.TemporaryDirectoryBaseDefault);
          var WithPersistenceNodeFileRelativePath = appConfiguration.GetValue<string>(appStringConstants.WithPersistenceNodeFileRelativePathConfigRootKey, appStringConstants.WithPersistenceNodeFileRelativePathDefault);
          var WithPersistenceEdgeFileRelativePath = appConfiguration.GetValue<string>(appStringConstants.WithPersistenceEdgeFileRelativePathConfigRootKey, appStringConstants.WithPersistenceEdgeFileRelativePathDefault);
          var filePathsPersistence = new string[2] { temporaryDirectoryBase + WithPersistenceNodeFileRelativePath, temporaryDirectoryBase + WithPersistenceEdgeFileRelativePath };
          var WithPickAndSaveNodeFileRelativePath = appConfiguration.GetValue<string>(appStringConstants.WithPickAndSaveNodeFileRelativePathConfigRootKey, appStringConstants.WithPickAndSaveNodeFileRelativePathDefault);
          var filePathsPickAndSave = new string[1] { temporaryDirectoryBase + WithPickAndSaveNodeFileRelativePath };
          mesg.Append(uiLocalizer["Running PartitionInfoEx Extension Function ConvertFileSystemToObjectGraph, on rootString {0} with an asyncFileReadBlockSize of {1} with hashing enabled: {2} ; progress enabled: {3} ; persistence enabled: {5} ; pickAndSave enabled: {4}", rootString, asyncFileReadBlockSize, enableHash, enableProgress, enablePersistence, enablePickAndSave]);
          if (enablePersistence) {
            mesg.Append(Environment.NewLine);
            mesg.Append(uiLocalizer["  persistence filePaths: {0}", string.Join(",", filePathsPersistence)]);
          }
          if (enablePickAndSave) {
            mesg.Append(Environment.NewLine);
            mesg.Append(uiLocalizer["  pickAndSave filePaths {0}", string.Join(",", filePathsPickAndSave)]);
          }
          if (enableProgress) {
            mesg.Append(Environment.NewLine);
            mesg.Append(uiLocalizer["  progressReporting TBD{0}", "ProgressReportingDataStructureDetails"]);
          }

          #region Write the mesg to stdout
          using (Task task = await WriteMessageSafelyAsync().ConfigureAwait(false)) {
            if (!task.IsCompletedSuccessfully) {
              if (task.IsCanceled) {
                // Ignore if user cancelled the operation during output to stdout (internal cancellation)
                // re-throw if the cancellation request came from outside the stdInLineMonitorAction
                /// ToDo: evaluate the linked, inner, and external tokens
                throw new OperationCanceledException();
              }
              else if (task.IsFaulted) {
                //ToDo: Go through the inner exception
                //foreach (var e in t.Exception) {
                //  https://docs.microsoft.com/en-us/dotnet/standard/io/handling-io-errors
                // ToDo figure out what to do if the output stream is closed
                throw new Exception("ToDo: WriteMessageSafelyAsync returned an AggregateException");
                //}
              }
            }
            mesg.Clear();
          }
          #endregion
          #region ProgressReporting setup
          ConvertFileSystemToGraphProgress? convertFileSystemToGraphProgress;
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
          // ToDo: create a function that will create subdirectories if needed to fulfill path, and use that function when creating the temp files
          //ToDo: add exception handling if the setup function fails
          ISetupViaFileResults setupResultsPersistence;
          try {
            setupResultsPersistence = PersistenceStaticExtensions.SetupViaFileFuncBuilder()(new SetupViaFileData(filePathsPersistence));
          }
          catch (System.IO.IOException ex) {
            // prepare message for UI interface
            // ToDo: custom exception,  and include its message here
            mesg.Append(uiLocalizer["IOException trying to setup PersistenceViaFiles"]);

            #region Write the mesg to stdout
            using (Task task = await WriteMessageSafelyAsync().ConfigureAwait(false)) {
              if (!task.IsCompletedSuccessfully) {
                if (task.IsCanceled) {
                  // Ignore if user cancelled the operation during output to stdout (internal cancellation)
                  // re-throw if the cancellation request came from outside the stdInLineMonitorAction
                  /// ToDo: evaluate the linked, inner, and external tokens
                  throw new OperationCanceledException();
                }
                else if (task.IsFaulted) {
                  //ToDo: Go through the inner exception
                  //foreach (var e in t.Exception) {
                  //  https://docs.microsoft.com/en-us/dotnet/standard/io/handling-io-errors
                  // ToDo figure out what to do if the output stream is closed
                  throw new Exception("ToDo: WriteMessageSafelyAsync returned an AggregateException");
                  //}
                }
              }
              mesg.Clear();
            }
            #endregion
            // Throw exception, Cancel the entire service (internal CTS), or swallow and Continue (possibly offering hints as to resolution), client's choice
            throw ex;
            // internalCancellationTokenSource.Signal ????
            // or just continue and let the user make another selection or go fix the problem
            //break;
          }
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
          // Ensure the Archived files are empty and can be written to
          // Call the SetupViaFileFuncBuilder here, execute the Func that comes back, with filePathsPickAndSave as the argument
          // ToDo: create a function that will create subdirectories if needed to fulfill path, and use that function when creating the temp files
          ISetupViaFileResults setupResultsPickAndSave;
          try {
            setupResultsPickAndSave = PersistenceStaticExtensions.SetupViaFileFuncBuilder()(new SetupViaFileData(filePathsPickAndSave));
          }
          catch (System.IO.IOException ex) {
            // prepare message for UI interface
            // ToDo: custom exception,  and include its message here
            mesg.Append(uiLocalizer["IOException trying to setup PickAndSaveViaFiles"]);
            #region Write the mesg to stdout
            using (Task task = await WriteMessageSafelyAsync().ConfigureAwait(false)) {
              if (!task.IsCompletedSuccessfully) {
                if (task.IsCanceled) {
                  // Ignore if user cancelled the operation during output to stdout (internal cancellation)
                  // re-throw if the cancellation request came from outside the stdInLineMonitorAction
                  /// ToDo: evaluate the linked, inner, and external tokens
                  throw new OperationCanceledException();
                }
                else if (task.IsFaulted) {
                  //ToDo: Go through the inner exception
                  //foreach (var e in t.Exception) {
                  //  https://docs.microsoft.com/en-us/dotnet/standard/io/handling-io-errors
                  // ToDo figure out what to do if the output stream is closed
                  throw new Exception("ToDo: WriteMessageSafelyAsync returned an AggregateException");
                  //}
                }
              }
              mesg.Clear();
            }
            #endregion
            // Throw exception, Cancel the entire service (internal CTS), or swallow and Continue (possibly offering hints as to resolution), client's choice
            throw ex;
            // internalCancellationTokenSource.Signal ????
            // or just continue and let the user make another selection or go fix the problem
            //break;
          }
          // Create a pickFunc (AKA Predicate)
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
                try {
                  setupResultsPickAndSave.StreamWriters[i].WriteLine(str);
                }
                catch (System.IO.IOException ex) {

                  throw;
                }
              }
            }
            return new InsertViaFileResults(true);
          });
          PickAndSave<IInsertResultsAbstract> pickAndSave = new PickAndSave<IInsertResultsAbstract>(pickFuncPickAndSave, insertFuncPickAndSave);
          #endregion

          ConvertFileSystemToGraphResult convertFileSystemToGraphResult;
          #region Method timing setup
          Stopwatch stopWatch = new Stopwatch(); // ToDo: utilize a much more powerfull and ubiquitous timing and profiling tool than a stopwatch
          stopWatch.Start();
          #endregion
          try {
            Func<Task<ConvertFileSystemToGraphResult>> run = () => ComputerInventoryHardwareStaticExtensions.ConvertFileSystemToGraphAsyncTask(rootString, asyncFileReadBlockSize, enableHash, convertFileSystemToGraphProgress, persistence, pickAndSave, linkedCancellationToken);
            convertFileSystemToGraphResult = await run.Invoke().ConfigureAwait(false);
            stopWatch.Stop(); // ToDo: utilize a much more powerfull and ubiquitous timing and profiling tool than a stopwatch
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
        //    case "2":
        //      #region define the Func<string,Task> to be executed when the ConsoleSourceHostedService.ConsoleReadLineAsyncAsObservable produces a sequence element
        //      // This Action closes over the current local variables' values
        //      Func<string, Task> SimpleEchoToConsoleOutFunc = new Func<string, Task>(async (inputLineString) => {
        //        #region Write the mesg to stdout
        //        using (Task task = await WriteMessageSafelyAsync(inputLineString, consoleSinkHostedService, linkedCancellationToken).ConfigureAwait(false)) {
        //          if (!task.IsCompletedSuccessfully) {
        //            if (task.IsCanceled) {
        //              // Ignore if user cancelled the operation during output to stdout (internal cancellation)
        //              // re-throw if the cancellation request came from outside the stdInLineMonitorAction
        //              /// ToDo: evaluate the linked, inner, and external tokens
        //              throw new OperationCanceledException();
        //            }
        //            else if (task.IsFaulted) {
        //              //ToDo: Go through the inner exception
        //              //foreach (var e in t.Exception) {
        //              //  https://docs.microsoft.com/en-us/dotnet/standard/io/handling-io-errors
        //              // ToDo figure out what to do if the output stream is closed
        //              throw new Exception("ToDo: WriteMessageSafelyAsync returned an AggregateException");
        //              //}
        //            }
        //          }
        //        }
        //        #endregion

        //      });
        //      #endregion
        //      break;
        //    case "10":
        //      #region setup a local block for handling this choice
        //      try {
        //        var enableHash = configurationRoot.GetValue<bool>(ConsoleMonitorStringConstants.EnableHashBoolConfigRootKey, bool.Parse(ConsoleMonitorStringConstants.EnableHashBoolConfigRootKeyDefault));  // ToDo: should validate in case the ConsoleMonitorStringConstants assembly is messed up?
        //        var enableProgress = configurationRoot.GetValue<bool>(ConsoleMonitorStringConstants.EnableProgressBoolConfigRootKey, bool.Parse(ConsoleMonitorStringConstants.EnableProgressBoolDefault));// ToDo: should validate in case the ConsoleMonitorStringConstants assembly is messed up?
        //        var enablePersistence = configurationRoot.GetValue<bool>(ConsoleMonitorStringConstants.EnablePersistenceBoolConfigRootKey, bool.Parse(ConsoleMonitorStringConstants.EnablePersistenceBoolDefault));// ToDo: should validate in case the ConsoleMonitorStringConstants assembly is messed up?
        //        var enablePickAndSave = configurationRoot.GetValue<bool>(ConsoleMonitorStringConstants.EnablePickAndSaveBoolConfigRootKey, bool.Parse(ConsoleMonitorStringConstants.EnablePickAndSaveBoolDefault));// ToDo: should validate in case the ConsoleMonitorStringConstants assembly is messed up?
        //        var dBConnectionString = configurationRoot.GetValue<string>(ConsoleMonitorStringConstants.DBConnectionStringConfigRootKey, ConsoleMonitorStringConstants.DBConnectionStringDefault);// ToDo: should validate in case the ConsoleMonitorStringConstants assembly is messed up?
        //                                                                                                                                                                                            // ToDo: This should be a string representation of a known enumeration of ORMLite DB providers that this service can support
        //        var dBProvider = configurationRoot.GetValue<string>(ConsoleMonitorStringConstants.DBConnectionStringConfigRootKey, ConsoleMonitorStringConstants.DBConnectionStringDefault);// ToDo: should validate in case the ConsoleMonitorStringConstants assembly is messed up?
        //        dBProvider = SqlServerOrmLiteDialectProvider.Instance;
        //        #region ProgressReporting setup
        //        ConvertFileSystemToGraphProgress? convertFileSystemToGraphProgress;
        //        if (enableProgress) {
        //          convertFileSystemToGraphProgress = new ConvertFileSystemToGraphProgress();
        //        }
        //        else {
        //          convertFileSystemToGraphProgress = null;
        //        }
        //        #endregion
        //        #region PersistenceViaIORMSetup
        //        // Call the SetupViaIORMFuncBuilder here, execute the Func that comes back, with dBConnectionString as the argument
        //        // Ensure the NNode and Edge Tables for this PartitionInfo are empty and can be written to
        //        // ToDo: create a function that will create Node and Edge tables if they don't yet exist, and use that function when creating the temp fiiles
        //        // ToDo: add exception handling if the setup function fails
        //        var setupResultsPersistence = PersistenceStaticExtensions.SetupViaORMFuncBuilder()(new SetupViaORMData(dBConnectionString, dBProvider, linkedCancellationToken));

        //        // Create an insertFunc that references the local variable setupResults, closing over it
        //        var insertFunc = new Func<IEnumerable<IEnumerable<object>>, IInsertViaORMResults>((insertData) => {
        //          int numberOfDatas = insertData.ToArray().Length;
        //          int numberOfStreamWriters = setupResultsPersistence.StreamWriters.Length;
        //          for (var i = 0; i < numberOfDatas; i++) {
        //            foreach (string str in insertData.ToArray()[i]) {
        //              //ToDo: add async versions await setupResults.StreamWriters[i].WriteLineAsync(str);
        //              //ToDo: exception handling
        //              setupResultsPersistence.Tables[i].SQLCmd(str);
        //            }
        //          }
        //          return new InsertViaORMResults(true);
        //        });
        //        Persistence<IInsertResultsAbstract> persistence = new Persistence<IInsertResultsAbstract>(insertFunc);
        //        #endregion
        //        #region PickAndSaveViaIORM setup
        //        // Ensure the Node and Edge files are empty and can be written to

        //        // Call the SetupViaIORMFuncBuilder here, execute the Func that comes back, with filePaths as the argument
        //        // ToDo: create a function that will create subdirectories if needed to fulfill path, and use that function when creating the temp files
        //        var setupResultsPickAndSave = PersistenceStaticExtensions.SetupViaORMFuncBuilder()(new SetupViaORMData(dBConnectionString, dBProvider, linkedCancellationToken));
        //        // Create a pickFunc
        //        var pickFuncPickAndSave = new Func<object, bool>((objToTest) => {
        //          return FileIOExtensions.IsArchiveFile(objToTest.ToString()) || FileIOExtensions.IsMailFile(objToTest.ToString());
        //        });
        //        // Create an insert Func
        //        var insertFuncPickAndSave = new Func<IEnumerable<IEnumerable<object>>, IInsertViaORMResults>((insertData) => {
        //          //int numberOfStreamWriters = setupResultsPickAndSave.StreamWriters.Length;
        //          //for (var i = 0; i < numberOfStreamWriters; i++) {
        //          //  foreach (string str in insertData.ToArray()[i]) {
        //          //    //ToDo: add async versions await setupResults.StreamWriters[i].WriteLineAsync(str);
        //          //    //ToDo: exception handling
        //          //    // ToDo: Make formatting a parameter
        //          //    setupResultsPickAndSave.StreamWriters[i].WriteLine(str);
        //          //  }
        //          //}
        //          return new InsertViaORMResults(true);
        //        });
        //        PickAndSave<IInsertResultsAbstract> pickAndSave = new PickAndSave<IInsertResultsAbstract>(pickFuncPickAndSave, insertFuncPickAndSave);
        //        #endregion
        //      }
        //      // To Catch specific exceptions that might occur
        //      catch {
        //      }
        //      // ToDo: dispose
        //      finally { }
        //      #endregion
        //      break;
        case "99":
          #region Quit the program
          //internalcancellationtoken.
          #endregion
          break;

        default:
          mesg.Clear();
          mesg.Append(uiLocalizer["InvalidInputDoesNotMatchAvailableChoices {0}", inputLine]);
          break;
      }

      #region Write the mesg to stdout
      using (Task task = await WriteMessageSafelyAsync().ConfigureAwait(false)) {
        if (!task.IsCompletedSuccessfully) {
          if (task.IsCanceled) {
            // Ignore if user cancelled the operation during output to stdout (internal cancellation)
            // re-throw if the cancellation request came from outside the stdInLineMonitorAction
            /// ToDo: evaluate the linked, inner, and external tokens
            throw new OperationCanceledException();
          }
          else if (task.IsFaulted) {
            //ToDo: Go through the inner exception
            //foreach (var e in t.Exception) {
            //  https://docs.microsoft.com/en-us/dotnet/standard/io/handling-io-errors
            // ToDo figure out what to do if the output stream is closed
            throw new Exception("ToDo: WriteMessageSafelyAsync returned an AggregateException");
            //}
          }
        }
      }
      #endregion

      #endregion
      #region Buildmenu
      await BuildMenu();
      #endregion
      #region Write the mesg to stdout
      using (Task task = await WriteMessageSafelyAsync().ConfigureAwait(false)) {
        if (!task.IsCompletedSuccessfully) {
          if (task.IsCanceled) {
            // Ignore if user cancelled the operation during output to stdout (internal cancellation)
            // re-throw if the cancellation request came from outside the stdInLineMonitorAction
            /// ToDo: evaluate the linked, inner, and external tokens
            throw new OperationCanceledException();
          }
          else if (task.IsFaulted) {
            //ToDo: Go through the inner exception
            //foreach (var e in t.Exception) {
            //  https://docs.microsoft.com/en-us/dotnet/standard/io/handling-io-errors
            // ToDo figure out what to do if the output stream is closed
            throw new Exception("ToDo: WriteMessageSafelyAsync returned an AggregateException");
            //}
          }
        }
        mesg.Clear();
      }
      #endregion
    }

    #region ExecuteAsync, called by the GenericHost StartAsync method, when IHostLifetime is ConsoleLifetime  // ToDo:, see if this is called by service and serviced
    /// <summary>
    /// Called to start the service. This is the main body of the code to execute for this background service
    /// </summary>
    /// <param name="externalCancellationToken"></param> Used to signal FROM the GenericHost TO this BackgroundService a request for cancelllation
    /// <returns></returns>
    protected override async Task ExecuteAsync(CancellationToken externalCancellationToken) {

      #region create linkedCancellationSource and token
      // Combine the cancellation tokens,so that either can stop this HostedService
      linkedCancellationTokenSource = CancellationTokenSource.CreateLinkedTokenSource(internalCancellationToken, externalCancellationToken);
      linkedCancellationToken = linkedCancellationTokenSource.Token;
      #endregion
      #region Register actions with the CancellationToken (s)
      externalCancellationToken.Register(() => logger.LogDebug(debugLocalizer["{0} {1} externalCancellationToken has signalled stopping."], "Console01BackgroundService", "externalCancellationToken"));
      internalCancellationToken.Register(() => logger.LogDebug(debugLocalizer["{0} {1} internalCancellationToken has signalled stopping."], "Console01BackgroundService", "internalCancellationToken"));
      linkedCancellationToken.Register(() => logger.LogDebug(debugLocalizer["{0} {1} linkedCancellationToken has signalled stopping."], "Console01BackgroundService", "linkedCancellationToken"));
      #endregion

      // Create a list of choices
      // ToDo: Get the list from the StringConstants, and localize them
      choices = new List<string>() { "1. Run ConvertFileSystemToGraphAsyncTask", "2. Subscribe ConsoleOut to ConsoleIn", "3. Unsubscribe ConsoleOut from ConsoleIn", "99: Quit" };

      #region Buildmenu
      await BuildMenu();
      #endregion
      #region Write the mesg to stdout
      using (Task task = await WriteMessageSafelyAsync().ConfigureAwait(false)) {
        if (!task.IsCompletedSuccessfully) {
          if (task.IsCanceled) {
            // Ignore if user cancelled the operation during output to stdout (internal cancellation)
            // re-throw if the cancellation request came from outside the stdInLineMonitorAction
            /// ToDo: evaluate the linked, inner, and external tokens
            throw new OperationCanceledException();
          }
          else if (task.IsFaulted) {
            //ToDo: Go through the inner exception
            //foreach (var e in t.Exception) {
            //  https://docs.microsoft.com/en-us/dotnet/standard/io/handling-io-errors
            // ToDo figure out what to do if the output stream is closed
            throw new Exception("ToDo: WriteMessageSafelyAsync returned an AggregateException");
            //}
          }
        }
        mesg.Clear();
      }
      #endregion

      // Subscribe to consoleSourceHostedService. Run the DoLoopAsync every time ConsoleReadLineAsyncAsObservable() produces a sequence element
      SubscriptionToConsoleReadLineAsyncAsObservableDisposeHandle = consoleSourceHostedService.ConsoleReadLineAsyncAsObservable()
          .Subscribe(
            // OnNext function:
            inputline => {
              try {
                DoLoopAsync(inputline);
              }
              catch (Exception ex) {

                throw ex;
              }            },
            // OnError
            ex => { logger.LogDebug("got an exception"); },
            // OnCompleted
            () => { logger.LogDebug("stdIn completed"); SubscriptionToConsoleReadLineAsyncAsObservableDisposeHandle.Dispose(); }
            );

    }

    Func<string, Task> stdInLineMonitorAction = new Func<string, Task>(async (inputLineString) => {
      /*


      logger.LogDebug(DebugLocalizer["{0} {1} Console01BackgroundService is stopping due to "], "Console01BackgroundService", "ExecuteAsync"); // add third parameter for internal or external
      SubscriptionToConsoleReadLineAsyncAsObservableDisposeHandle.Dispose();

    }
    #endregion
          */
    });
    #endregion
  }
}
