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
using System.IO;
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
using GenericHostExtensions = ATAP.Utilities.Extensions.GenericHost.Extensions;
using ConfigurationExtensions = ATAP.Utilities.Extensions.Configuration.Extensions;

using hostedServiceStringConstants = FileSystemToObjectGraphService.StringConstants;

using ServiceStack;
using ATAP.Utilities.HostedServices.StdInHandlerService;

namespace FileSystemToObjectGraphService {
  public interface IFileSystemToObjectGraphService {

    Task<ConvertFileSystemToGraphResult> ConvertFileSystemToObjectGraphAsync(string rootString, int asyncFileReadBlockSize, bool enableHash, ConvertFileSystemToGraphProgress convertFileSystemToGraphProgress, Persistence<IInsertResultsAbstract> persistence, PickAndSave<IInsertResultsAbstract> pickAndSave, CancellationToken cancellationToken);

    Task EnableListeningToStdInAsync();

  }

#if TRACE
  [ETWLogAttribute]
#endif
  public partial class FileSystemToObjectGraphService : IHostedService, IDisposable, IFileSystemToObjectGraphService {
    #region Common Constructor-injected Auto-Implemented Properties and Localizers
    // These properties can only be set in the class constructor.
    // Class constructor for a Hosted Service is called from the GenericHost which injects the DI services referenced in the Constructor Signature
    ILoggerFactory loggerFactory { get; }
    ILogger<FileSystemToObjectGraphService> logger { get; }
    IStringLocalizerFactory stringLocalizerFactory { get; }
    IHostEnvironment hostEnvironment { get; }
    IConfiguration hostConfiguration { get; }
    IHostLifetime hostLifetime { get; }
    IConfiguration hostedServiceConfiguration { get; }
    IHostApplicationLifetime hostApplicationLifetime { get; }
    IStringLocalizer debugLocalizer { get; }
    IStringLocalizer exceptionLocalizer { get; }
    IStringLocalizer uiLocalizer { get; }

    #endregion
    #region Internal and Linked CancellationTokenSource and Tokens
    CancellationTokenSource internalCancellationTokenSource { get; } = new CancellationTokenSource();
    CancellationToken internalCancellationToken { get; }
    // Set in the ExecuteAsync method
    CancellationTokenSource linkedCancellationTokenSource { get; set; }
    // Set in the ExecuteAsync method
    CancellationToken linkedCancellationToken { get; set; }
    #endregion
    #region Constructor-injected fields unique to this service. These represent other DI services used by this service that are expected to be present in the app's DI container, and are constructor-injected
    IStdInHandlerService StdInHandlerService { get; }
    IConsoleSinkHostedService consoleSinkHostedService { get; }
    IConsoleSourceHostedService consoleSourceHostedService { get; }
    #endregion
    #region Data for Service
    FileSystemToObjectGraphServiceData serviceData { get; }
    #endregion
    #region Performance Monitoring data
    Stopwatch Stopwatch { get; } // ToDo: utilize a much more powerfull and ubiquitious timing and profiling tool than a stopwatch
    #endregion
    #region Constructor
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
    public FileSystemToObjectGraphService(IStdInHandlerService stdInHandlerService, IConsoleSinkHostedService consoleSinkHostedService, IConsoleSourceHostedService consoleSourceHostedService, ILoggerFactory loggerFactory, IStringLocalizerFactory stringLocalizerFactory, IHostEnvironment hostEnvironment, IConfiguration hostConfiguration, IHostLifetime hostLifetime, IConfiguration hostedServiceConfiguration, IHostApplicationLifetime hostApplicationLifetime) {
      this.stringLocalizerFactory = stringLocalizerFactory ?? throw new ArgumentNullException(nameof(stringLocalizerFactory));
      exceptionLocalizer = stringLocalizerFactory.Create(nameof(AService01.Resources), "AService01");
      debugLocalizer = stringLocalizerFactory.Create(nameof(AService01.Resources), "AService01");
      uiLocalizer = stringLocalizerFactory.Create(nameof(AService01.Resources), "AService01");
      this.loggerFactory = loggerFactory ?? throw new ArgumentNullException(nameof(loggerFactory));
      this.logger = loggerFactory.CreateLogger<FileSystemToObjectGraphService>();
      // this.logger = (Logger<FileSystemToObjectGraphService>) ATAP.Utilities.Logging.LogProvider.GetLogger("FileSystemToObjectGraphService");
      logger.LogDebug("FileSystemToObjectGraphService", ".ctor");  // ToDo Fody for tracing constructors, via an optional switch
      this.hostEnvironment = hostEnvironment ?? throw new ArgumentNullException(nameof(hostEnvironment));
      this.hostConfiguration = hostConfiguration ?? throw new ArgumentNullException(nameof(hostConfiguration));
      this.hostLifetime = hostLifetime ?? throw new ArgumentNullException(nameof(hostLifetime));
      this.hostedServiceConfiguration = hostedServiceConfiguration ?? throw new ArgumentNullException(nameof(hostedServiceConfiguration));
      this.hostApplicationLifetime = hostApplicationLifetime ?? throw new ArgumentNullException(nameof(hostApplicationLifetime));
      this.StdInHandlerService = stdInHandlerService ?? throw new ArgumentNullException(nameof(stdInHandlerService));
      this.consoleSinkHostedService = consoleSinkHostedService ?? throw new ArgumentNullException(nameof(consoleSinkHostedService));
      this.consoleSourceHostedService = consoleSourceHostedService ?? throw new ArgumentNullException(nameof(consoleSourceHostedService));
      internalCancellationToken = internalCancellationTokenSource.Token;
      Stopwatch = new Stopwatch();
      #region Create the serviceData and initialize it from the StringConstants or this service's ConfigRoot
      this.serviceData = new FileSystemToObjectGraphServiceData(
        // ToDo: Get the list from the StringConstants, and localize them 
        choices: new List<string>() { "1. Run FileSystemToObjectGrapAsyncTask", "2. Changeable", "99: Quit this service" },
        stdInHandlerState: new StringBuilder(),
        mesg:  new StringBuilder()) {
        AsyncFileReadBlockSize = hostedServiceConfiguration.GetValue<int>(hostedServiceStringConstants.AsyncFileReadBlockSizeConfigRootKey, int.Parse(hostedServiceStringConstants.AsyncFileReadBlockSizeDefault)),  // ToDo: should validate in case the hostedServiceStringConstants assembly is messed up?
        EnableHash = hostedServiceConfiguration.GetValue<bool>(hostedServiceStringConstants.EnableHashBoolConfigRootKey, bool.Parse(hostedServiceStringConstants.EnableHashBoolDefault)), // ToDo: should validate in case the hostedServiceStringConstants assembly is messed up?
        EnablePersistence = hostedServiceConfiguration.GetValue<bool>(hostedServiceStringConstants.EnablePersistenceBoolConfigRootKey, bool.Parse(hostedServiceStringConstants.EnablePersistenceBoolDefault)), // ToDo: should validate in case the hostedServiceStringConstants assembly is messed up?
        EnablePickAndSave = hostedServiceConfiguration.GetValue<bool>(hostedServiceStringConstants.EnablePickAndSaveBoolConfigRootKey, bool.Parse(hostedServiceStringConstants.EnablePickAndSaveBoolDefault)), // ToDo: should validate in case the hostedServiceStringConstants assembly is messed up?
        EnableProgress = hostedServiceConfiguration.GetValue<bool>(hostedServiceStringConstants.EnableProgressBoolConfigRootKey, bool.Parse(hostedServiceStringConstants.EnableProgressBoolDefault)), // ToDo: should validate in case the hostedServiceStringConstants assembly is messed up?
        TemporaryDirectoryBase = hostedServiceConfiguration.GetValue<string>(hostedServiceStringConstants.TemporaryDirectoryBaseConfigRootKey, hostedServiceStringConstants.TemporaryDirectoryBaseDefault),
        PersistenceNodeFileRelativePath = hostedServiceConfiguration.GetValue<string>(hostedServiceStringConstants.PersistenceNodeFileRelativePathConfigRootKey, hostedServiceStringConstants.PersistenceNodeFileRelativePathDefault),
        PersistenceEdgeFileRelativePath = hostedServiceConfiguration.GetValue<string>(hostedServiceStringConstants.PersistenceEdgeFileRelativePathConfigRootKey, hostedServiceStringConstants.PersistenceEdgeFileRelativePathDefault),
        PickAndSaveNodeFileRelativePath = hostedServiceConfiguration.GetValue<string>(hostedServiceStringConstants.PickAndSaveNodeFileRelativePathConfigRootKey, hostedServiceStringConstants.PickAndSaveNodeFileRelativePathDefault),
        DBConnectionString = "",
        OrmLiteDialectProviderStringDefault = "",
      };
      this.serviceData.PersistenceFilePaths = new string[2] { serviceData.TemporaryDirectoryBase + serviceData.PersistenceNodeFileRelativePath, serviceData.TemporaryDirectoryBase + serviceData.PersistenceEdgeFileRelativePath };
      this.serviceData.PickAndSaveFilePaths = new string[2] { serviceData.TemporaryDirectoryBase + serviceData.PickAndSaveNodeFileRelativePath, serviceData.TemporaryDirectoryBase + serviceData.PickAndSaveEdgeFileRelativePath };
      //ToDo: setup Progress here?
      #endregion
    }
    #endregion

    public async Task<ConvertFileSystemToGraphResult> ConvertFileSystemToObjectGraphAsync(string rootString, int asyncFileReadBlockSize, bool enableHash, ConvertFileSystemToGraphProgress convertFileSystemToGraphProgress, Persistence<IInsertResultsAbstract> persistence, PickAndSave<IInsertResultsAbstract> pickAndSave, CancellationToken cancellationToken) {
await Task.Delay(10000);
      return new ConvertFileSystemToGraphResult();
    }


    #region Helper methods to reduce code clutter
    #region CheckAndHandleCancellationToken
    void CheckAndHandleCancellationToken(int checkpointNumber, CancellationTokenSource cancellationTokenSource) {
      // check CancellationToken to see if this task is canceled
      if (cancellationTokenSource.IsCancellationRequested) {
        logger.LogDebug(debugLocalizer["{0}: Cancellation requested, checkpoint number {1}", "FileSystemToObjectGraphService", checkpointNumber.ToString(CultureInfo.CurrentCulture)]);
        cancellationTokenSource.Token.ThrowIfCancellationRequested();
      }
    }
    void CheckAndHandleCancellationToken(string locationMessage, CancellationTokenSource cancellationTokenSource) {
      // check CancellationTokenSource to see if this task is canceled
      if (linkedCancellationTokenSource.IsCancellationRequested) {
        logger.LogDebug(debugLocalizer["{0}: Cancellation requested, checkpoint number {1}", "FileSystemToObjectGraphService", locationMessage]);
        cancellationTokenSource.Token.ThrowIfCancellationRequested();
      }
    }
    #endregion
    #region WriteMessageSafelyAsync
    // Output a message, wrapped with exception handling
    async Task<Task> WriteMessageSafelyAsync(StringBuilder mesg, IStringLocalizer exceptionLocalizer, CancellationTokenSource cancellationTokenSource) {
      // check CancellationToken to see if this task is canceled
      CheckAndHandleCancellationToken("WriteMessageSafelyAsync", cancellationTokenSource);
      var task = await consoleSinkHostedService.WriteMessageAsync(mesg).ConfigureAwait(false);
      if (!task.IsCompletedSuccessfully) {
        if (task.IsCanceled) {
          // Ignore if user canceled the operation during a large file output (internal cancellation)
          // re-throw if the cancellation request came from outside the ConsoleMonitor
          /// ToDo: evaluate the linked, inner, and external tokens
          throw new OperationCanceledException();
        }
        else if (task.IsFaulted) {
          //ToDo: Go through the inner exception
          //foreach (var e in t.Exception) {
          //  https://docs.microsoft.com/en-us/dotnet/standard/io/handling-io-errors
          // ToDo figure out what to do if the output stream is closed
          throw new Exception("ToDo: in WriteMessageSafelyAsync");
          //}
        }
      }
      return Task.CompletedTask;
    }
    async Task<Task> WriteMessageSafelyAsync() {
      return await WriteMessageSafelyAsync(serviceData.Mesg, exceptionLocalizer, linkedCancellationTokenSource);
    }
    #endregion
    #region Build Menu
    /// <summary>
    /// Build a multi-line menu from the choices, and send to stdout
    /// </summary>
    /// <param name="mesg"></param>
    /// <param name="choices"></param>
    /// <param name="uILocalizer"></param>
    /// <param name="exceptionLocalizer"></param>
    /// <param name="cancellationToken"></param>
    /// <returns></returns>
    void BuildMenu(StringBuilder mesg, IEnumerable<string> choices, IStringLocalizer uILocalizer, CancellationTokenSource cancellationTokenSource) {
      // check CancellationToken to see if this task is cancelled
      CheckAndHandleCancellationToken("BuildMenu", cancellationTokenSource);
      mesg.Clear();

      foreach (var choice in choices) {
        mesg.Append(uILocalizer[choice]);
        mesg.Append(Environment.NewLine);
      }
      mesg.Append(uiLocalizer["Enter a number for a choice, Ctrl-C to Exit"]);
    }
    void BuildMenu() {
      BuildMenu(serviceData.Mesg, serviceData.Choices, uiLocalizer, linkedCancellationTokenSource);
    }
    #endregion
    #region Build and Display Menu
    async Task BuildAndDisplayMenu(StringBuilder mesg, IEnumerable<string> choices, IStringLocalizer uILocalizer, IStringLocalizer exceptionLocalizer, CancellationTokenSource cancellationTokenSource) {
      BuildMenu(mesg, choices, uILocalizer, cancellationTokenSource);
      await WriteMessageSafelyAsync(mesg, exceptionLocalizer, cancellationTokenSource);
    }
    async Task BuildAndDisplayMenu() {
      await BuildAndDisplayMenu(serviceData.Mesg, serviceData.Choices, uiLocalizer, exceptionLocalizer, linkedCancellationTokenSource);

    }
    #region prepare ConvertFileSystemToGraphResult for UI Display
    
    // Format an instance of ConvertFileSystemToGraphResults for UI presentation
    // // Uses the CurrentCulture, converts File Sizes to UnitsNet.Information types, and DateTimes to ITenso Times
    void PrepareFileSystemToGraphResultForUIStdOut(StringBuilder mesg, ConvertFileSystemToGraphResult convertFileSystemToGraphResult, Stopwatch? stopwatch) {
      mesg.Clear();
      if (stopwatch != null) {
        mesg.Append(uiLocalizer["Running the function took {0} milliseconds", stopwatch.ElapsedMilliseconds.ToString(CultureInfo.CurrentCulture)]);
        mesg.Append(Environment.NewLine);
      }
      serviceData.Mesg.Append(uiLocalizer["DeepestDirectoryTree: {0}", convertFileSystemToGraphResult.DeepestDirectoryTree]);
      serviceData.Mesg.Append(Environment.NewLine);
      serviceData.Mesg.Append(uiLocalizer["LargestFile: {0}", new UnitsNet.Information(convertFileSystemToGraphResult.LargestFile, UnitsNet.Units.InformationUnit.Byte).ToString(CultureInfo.CurrentCulture)]);
      serviceData.Mesg.Append(Environment.NewLine);
      serviceData.Mesg.Append(uiLocalizer["EarliestDirectoryCreationTime: {0}", convertFileSystemToGraphResult.EarliestDirectoryCreationTime.ToString(CultureInfo.CurrentCulture)]);
      serviceData.Mesg.Append(Environment.NewLine);
      serviceData.Mesg.Append(uiLocalizer["LatestDirectoryCreationTime: {0}", convertFileSystemToGraphResult.LatestDirectoryCreationTime.ToString(CultureInfo.CurrentCulture)]);
      serviceData.Mesg.Append(Environment.NewLine);
      serviceData.Mesg.Append(uiLocalizer["EarliestFileCreationTime: {0}", convertFileSystemToGraphResult.EarliestFileCreationTime]);
      serviceData.Mesg.Append(Environment.NewLine);
      serviceData.Mesg.Append(uiLocalizer["LatestFileCreationTime: {0}", convertFileSystemToGraphResult.LatestFileCreationTime]);
      serviceData.Mesg.Append(Environment.NewLine);
      serviceData.Mesg.Append(uiLocalizer["EarliestFileModificationTime: {0}", convertFileSystemToGraphResult.EarliestFileModificationTime]);
      serviceData.Mesg.Append(Environment.NewLine);
      serviceData.Mesg.Append(uiLocalizer["LatestFileModificationTime: {0}", convertFileSystemToGraphResult.LatestFileModificationTime]);
      serviceData.Mesg.Append(Environment.NewLine);
      serviceData.Mesg.Append(uiLocalizer["Number of AcceptableExceptions: {0}", convertFileSystemToGraphResult.AcceptableExceptions.Count]);
      serviceData.Mesg.Append(Environment.NewLine);
      // List the acceptable Exceptions that occurred
      //ToDo: break out AcceptableExceptions by type
    }
    #endregion
    #endregion
    #endregion

    public async Task InputLineLoopAsync(string inputLine) {

      int checkpointnumber = 0;
      // check CancellationToken to see if this task is canceled
      CheckAndHandleCancellationToken(checkpointnumber++, linkedCancellationTokenSource);

      logger.LogDebug(uiLocalizer["{0} {1} inputLineString = {2}", "FileSystemToObjectGraphService", "InputLineLoopAsync", inputLine]);

      // Echo to stdOut the line that came in on stdIn
      serviceData.Mesg.Append(uiLocalizer["You selected: {0}", inputLine]);
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
        serviceData.Mesg.Clear();
      }
      #endregion
      #region Switch on user's selection
      switch (inputLine) {
        case "1":
          // ToDo: Get these from the hostedServiceConfiguration
          serviceData.RootString = hostedServiceConfiguration.GetValue<string>(hostedServiceStringConstants.RootStringConfigRootKey, hostedServiceStringConstants.RootStringDefault);
          serviceData.AsyncFileReadBlockSize = hostedServiceConfiguration.GetValue<int>(hostedServiceStringConstants.AsyncFileReadBlockSizeConfigRootKey, int.Parse(hostedServiceStringConstants.AsyncFileReadBlockSizeDefault));  // ToDo: should validate in case the hostedServiceStringConstants assembly is messed up?
          serviceData.EnableHash = hostedServiceConfiguration.GetValue<bool>(hostedServiceStringConstants.EnableHashBoolConfigRootKey, bool.Parse(hostedServiceStringConstants.EnableHashBoolDefault));  // ToDo: should validate in case the hostedServiceStringConstants assembly is messed up?
          serviceData.EnableProgress = hostedServiceConfiguration.GetValue<bool>(hostedServiceStringConstants.EnableProgressBoolConfigRootKey, bool.Parse(hostedServiceStringConstants.EnableProgressBoolDefault));// ToDo: should validate in case the hostedServiceStringConstants assembly is messed up?
          serviceData.EnablePersistence = hostedServiceConfiguration.GetValue<bool>(hostedServiceStringConstants.EnablePersistenceBoolConfigRootKey, bool.Parse(hostedServiceStringConstants.EnablePersistenceBoolDefault));// ToDo: should validate in case the hostedServiceStringConstants assembly is messed up?
          serviceData.EnablePickAndSave = hostedServiceConfiguration.GetValue<bool>(hostedServiceStringConstants.EnablePickAndSaveBoolConfigRootKey, bool.Parse(hostedServiceStringConstants.EnablePickAndSaveBoolDefault));// ToDo: should validate in case the hostedServiceStringConstants assembly is messed up?
          serviceData.TemporaryDirectoryBase = hostedServiceConfiguration.GetValue<string>(hostedServiceStringConstants.TemporaryDirectoryBaseConfigRootKey, hostedServiceStringConstants.TemporaryDirectoryBaseDefault);
          serviceData.PersistenceNodeFileRelativePath = hostedServiceConfiguration.GetValue<string>(hostedServiceStringConstants.PersistenceNodeFileRelativePathConfigRootKey, hostedServiceStringConstants.PersistenceNodeFileRelativePathDefault);
          serviceData.PersistenceEdgeFileRelativePath = hostedServiceConfiguration.GetValue<string>(hostedServiceStringConstants.PersistenceEdgeFileRelativePathConfigRootKey, hostedServiceStringConstants.PersistenceEdgeFileRelativePathDefault);
          serviceData.PersistenceFilePaths = new string[2] { serviceData.TemporaryDirectoryBase + serviceData.PersistenceNodeFileRelativePath, serviceData.TemporaryDirectoryBase + serviceData.PersistenceEdgeFileRelativePath };
          serviceData.PickAndSaveNodeFileRelativePath = hostedServiceConfiguration.GetValue<string>(hostedServiceStringConstants.PickAndSaveNodeFileRelativePathConfigRootKey, hostedServiceStringConstants.PickAndSaveNodeFileRelativePathDefault);
          serviceData.PickAndSaveFilePaths = new string[1] { serviceData.TemporaryDirectoryBase + serviceData.PickAndSaveNodeFileRelativePath };
          serviceData.Mesg.Append(uiLocalizer["Running PartitionInfoEx Extension Function ConvertFileSystemToObjectGraph, on rootString {0} with an asyncFileReadBlockSize of {1} with hashihg enabled: {2} ; progress enabled: {3} ; persistence enabled: {5} ; pickAndSave enabled: {4}", serviceData.RootString, serviceData.AsyncFileReadBlockSize, serviceData.EnableHash, serviceData.EnableProgress, serviceData.EnablePersistence, serviceData.EnablePickAndSave]);
          if (serviceData.EnablePersistence) {
            serviceData.Mesg.Append(Environment.NewLine);
            serviceData.Mesg.Append(uiLocalizer["  persistence filePaths: {0}", string.Join(",", serviceData.PersistenceFilePaths)]);
          }
          if (serviceData.EnablePickAndSave) {
            serviceData.Mesg.Append(Environment.NewLine);
            serviceData.Mesg.Append(uiLocalizer["  pickAndSave filePaths {0}", string.Join(",", serviceData.PickAndSaveFilePaths)]);
          }
          if (serviceData.EnableProgress) {
            serviceData.Mesg.Append(Environment.NewLine);
            serviceData.Mesg.Append(uiLocalizer["  progressReporting TBD{0}", "ProgressReportingDataStructureDetails"]);
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
            serviceData.Mesg.Clear();
          }
          #endregion
          #region ProgressReporting setup
          ConvertFileSystemToGraphProgress? convertFileSystemToGraphProgress; ;
          if (serviceData.EnableProgress) {
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
          ISetupViaFileResults setupResultsPersistence;
          try {
            setupResultsPersistence = PersistenceStaticExtensions.SetupViaFileFuncBuilder()(new SetupViaFileData(serviceData.PersistenceFilePaths));
          }
          catch (System.IO.IOException ex) {
            // prepare message for UI interface
            // ToDo: custome exception,  and include its message here
            serviceData.Mesg.Append(uiLocalizer["IOException trying to setup PersistenceViaFiles"]);

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
              serviceData.Mesg.Clear();
            }
            #endregion
            // Throw exception, Cancel the entire service (internal CTS), or swallow and Continue (possiblky offering hints as to resolution), client's choice
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
          // ToDo: create a function that will create subdirectories if needed to fulfill path, and use that function when creating the temp fiiles
          ISetupViaFileResults setupResultsPickAndSave;
          try {
            setupResultsPickAndSave = PersistenceStaticExtensions.SetupViaFileFuncBuilder()(new SetupViaFileData(serviceData.PickAndSaveFilePaths));
          }
          catch (System.IO.IOException ex) {
            // prepare message for UI interface
            // ToDo: custome exception,  and include its message here
            serviceData.Mesg.Append(uiLocalizer["IOException trying to setup PickAndSaveViaFiles"]);
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
              serviceData.Mesg.Clear();
            }
            #endregion
            // Throw exception, Cancel the entire service (internal CTS), or swallow and Continue (possiblky offering hints as to resolution), client's choice
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
          Stopwatch stopWatch = new Stopwatch(); // ToDo: utilize a much more powerfull and ubiquitious timing and profiling tool than a stopwatch
          stopWatch.Start();
          #endregion
          try {
            Func<Task<ConvertFileSystemToGraphResult>> run = () => ComputerInventoryHardwareStaticExtensions.ConvertFileSystemToGraphAsyncTask(serviceData.RootString, serviceData.AsyncFileReadBlockSize, serviceData.EnableHash, convertFileSystemToGraphProgress, persistence, pickAndSave, linkedCancellationToken);
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
          PrepareFileSystemToGraphResultForUIStdOut(serviceData.Mesg, convertFileSystemToGraphResult, stopWatch);
          #endregion

          break;
        //    case "2":
        //      #region define the Func<string,Task> to be executed when the ConsoleSourceHostedService.ConsoleReadLineAsyncAsObservable produces a sequence element
        //      // This Action closes over the current local variables' values
        //      Func<string, Task> SimpleEchoToConsoleOutFunc = new Func<string, Task>(async (inputLineString) => {
        //        #region Write the mesg to stdout
        //        using (Task task = await WriteMessageSafelyAsync(inputLineString, consoleSinkHostedService, GenericHostsCancellationToken).ConfigureAwait(false)) {
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
        //        #region PersistenceViaIORMsetup
        //        // Call the SetupViaIORMFuncBuilder here, execute the Func that comes back, with dBConnectionString as the argument
        //        // Ensure the NNode and Edge Tables for this PartitionInfo are empty and can be written to
        //        // ToDo: create a function that will create Node and Edge tables if they don't yet exist, and use that function when creating the temp fiiles
        //        // ToDo: add exception handling if the setup function fails
        //        var setupResultsPersistence = PersistenceStaticExtensions.SetupViaORMFuncBuilder()(new SetupViaORMData(dBConnectionString, dBProvider, GenericHostsCancellationToken));

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
        //        // ToDo: create a function that will create subdirectories if needed to fulfill path, and use that function when creating the temp fiiles
        //        var setupResultsPickAndSave = PersistenceStaticExtensions.SetupViaORMFuncBuilder()(new SetupViaORMData(dBConnectionString, dBProvider, GenericHostsCancellationToken));
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
          #region Quit this service
          // Go Back to the StdInHandlerService 
          StdInHandlerService.EnableListeningToStdInAsync();
          serviceData.SubscriptionToConsoleReadLineAsyncAsObservableDisposeHandle.Dispose();
          #endregion
          break;

        default:
          serviceData.Mesg.Clear();
          serviceData.Mesg.Append(uiLocalizer["Invalid Input Does Not Match Available Choices: {0}", inputLine]);
          break;
      }
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
        serviceData.Mesg.Clear();
      }
      #endregion
      #region Build and Display menu
      await BuildAndDisplayMenu();
      #endregion
    }

    #region StartAsync and StopAsync methods as promised by IHostedService when IHostLifetime is ConsoleLifetime  // ToDo:, see if this is called by service and serviced
    /// <summary>
    /// Called to start the service. 
    /// </summary>
    /// <param name="externalCancellationToken"></param> Used to signal FROM the GenericHost TO this BackgroundService a request for cancelllation
    /// <returns></returns>
    public async Task StartAsync(CancellationToken externalCancellationToken) {

      #region create linkedCancellationSource and token
      // Combine the cancellation tokens,so that either can stop this HostedService
      linkedCancellationTokenSource = CancellationTokenSource.CreateLinkedTokenSource(internalCancellationToken, externalCancellationToken);
      linkedCancellationToken = linkedCancellationTokenSource.Token;
      #endregion
      #region Register actions with the CancellationToken (s)
      externalCancellationToken.Register(() => logger.LogDebug(debugLocalizer["{0} {1} externalCancellationToken has signalled stopping."], "FileSystemToObjectGraphService", "externalCancellationToken"));
      internalCancellationToken.Register(() => logger.LogDebug(debugLocalizer["{0} {1} internalCancellationToken has signalled stopping."], "FileSystemToObjectGraphService", "internalCancellationToken"));
      linkedCancellationToken.Register(() => logger.LogDebug(debugLocalizer["{0} {1} GenericHostsCancellationToken has signalled stopping."], "FileSystemToObjectGraphService", "GenericHostsCancellationToken"));
      #endregion
      #region register local event handlers with the IHostApplicationLifetime's events
      // Register the methods defined in this class with the three CancellationToken properties found on the IHostApplicationLifetime instance passed to this class in it's .ctor
      hostApplicationLifetime.ApplicationStarted.Register(OnStarted);
      hostApplicationLifetime.ApplicationStopping.Register(OnStopping);
      hostApplicationLifetime.ApplicationStopped.Register(OnStopped);
      #endregion
      // Wait to be connected to the stdIn observable
      //return Task.CompletedTask;
    }

    // StopAsync issued in both IHostedService and IHostLifetime interfaces
    // This IS called when the user closes the ConsoleWindow with the windows top right pane "x (close)" icon
    // This IS called when the user hits ctrl-C in the console window
    //  After Ctrl-C and after this method exits, the debugger
    //    shows an unhandled exception: System.OperationCanceledException: 'The operation was canceled.'
    // See also discussion of Stop async in the following attributions.
    // Attribution to  https://stackoverflow.com/questions/51044781/graceful-shutdown-with-generic-host-in-net-core-2-1
    // Attribution to https://stackoverflow.com/questions/52915015/how-to-apply-hostoptions-shutdowntimeout-when-configuring-net-core-generic-host for OperationCanceledException notes

    public async Task StopAsync(CancellationToken cancellationToken) {
      logger.LogDebug(debugLocalizer["{0} {1}  StopAsync ."], "FileSystemToObjectGraphService", "StopAsync");
      //InternalCancellationTokenSource.Cancel();
      // Defer completion promise, until our application has reported it is done.
      // return TaskCompletionSource.Task;
      //Stop(); // would call the servicebase stop if this was a generic hosted service ??
      //return Task.CompletedTask;
    }
    #endregion

    #region Event Handlers registered with the HostApplicationLifetime events
    // Registered as a handler with the HostApplicationLifetime.ApplicationStarted event
    private void OnStarted() {
      // Post-startup code goes here  
    }

    // Registered as a handler with the HostApplicationLifetime.Application event
    // This is NOT called if the ConsoleWindows ends when the connected browser (browser opened by LaunchSettings when starting with debugger) is closed (not applicable to ConsoleLifetime generic hosts
    // This IS called if the user hits ctrl-C in the ConsoleWindow
    private void OnStopping() {
      // On-stopping code goes here  
    }

    // Registered as a handler with the HostApplicationLifetime.ApplicationStarted event
    private void OnStopped() {
      // Post-stopped code goes here  
    }

    // Called by base.Stop. This may be called multiple times by service Stop, ApplicationStopping, and StopAsync.
    // That's OK because StopApplication uses a CancellationTokenSource and prevents any recursion.
    // This IS called when user hits ctrl-C in ConsoleWindow
    //  This IS NOT called when user closes the startup auto browser
    // ToDo:investigate BrowserLink, and multiple browsers effect on this call
    //protected override void OnStop() {
    //  HostApplicationLifetime.StopApplication();
    //  base.OnStop();
    //}
    #endregion

    #region 'standard" method for EnableListeningToStdIn
    public async Task EnableListeningToStdInAsync() {
      #region Build and Display Menu
      await BuildAndDisplayMenu();
      #endregion

      // Subscribe to consoleSourceHostedService. Run the DoLoopAsync every time ConsoleReadLineAsyncAsObservable() produces a sequence element
      serviceData.SubscriptionToConsoleReadLineAsyncAsObservableDisposeHandle = consoleSourceHostedService.ConsoleReadLineAsyncAsObservable()
            .Subscribe(async
              // OnNext function:
              inputline => {
                try {
                  await InputLineLoopAsync(inputline);
                }
                catch (Exception ex) {

                  throw ex;
                }
              },
              // OnError
              ex => { logger.LogDebug("got an exception"); },
              // OnCompleted
              () => { logger.LogDebug("stdIn completed"); serviceData.SubscriptionToConsoleReadLineAsyncAsObservableDisposeHandle.Dispose(); }
              );
      //return Task.CompletedTask;
    }
    #endregion

    #region IDisposable Support
    private bool disposedValue = false; // To detect redundant calls

    protected virtual void Dispose(bool disposing) {
      if (!disposedValue) {
        if (disposing) {
          // dispose of the SubscriptionToConsoleReadLineAsyncAsObservableDisposeHandle
          serviceData.Dispose();
        }
        disposedValue = true;
      }
    }

    // This code added to correctly implement the disposable pattern.
    public void Dispose() {
      // Do not change this code. Put cleanup code in Dispose(bool disposing) above.
      Dispose(true);
    }
    #endregion

  }
}
